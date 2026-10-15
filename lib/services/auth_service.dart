import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../config/client_theme.dart';
import '../constants/app_colors.dart';
import '../models/auth_models.dart';
import 'access_guard.dart';
import 'base_service.dart' show PlanAccessBlockedException;
import 'cache_service.dart';
import 'exam_masters_service.dart';
import 'masters_service.dart';
import 'permission_refresh_coordinator.dart';
import 'permission_service.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  static const _tokenKey = 'auth_token';
  static const _userKey = 'cached_user';
  static const _hospitalKey = 'hospital_info';
  static const _slugKey = 'hospital_slug';
  static const _lastValidatedKey = 'auth_last_validated_at';
  static const _permVersionKey = 'permissions_version';
  static const _permModulesKey = 'permission_modules';
  static const _permScopeKey = 'permission_scope';
  static const offlineGrace = Duration(hours: 24);

  // Permission-sync contract from login / auth/me (null on older API builds).
  String? _permissionsVersion;
  List<String>? _modules;
  Map<String, dynamic>? _scope;
  String? get permissionsVersion => _permissionsVersion;
  List<String>? get modules => _modules;
  Map<String, dynamic>? get permissionScope => _scope;

  late final PermissionRefreshCoordinator _permissionRefresher =
      PermissionRefreshCoordinator(refresh: _refreshMeNow);

  // The bearer token is the one credential that grants API access, so it
  // lives in the platform keystore/keychain — not plaintext SharedPreferences
  // like the rest of this cache. See ROLES_PERMISSIONS session-security plan.
  static const _secureStorage = FlutterSecureStorage();

  // In-memory token cache — eliminates SharedPreferences I/O on every request.
  String? _tokenCache;
  UserInfo? _userCache;
  UserInfo? get activeUser => _userCache;

  // In-memory hospital cache — same pattern as _tokenCache. Lets deeply
  // nested screens (that don't receive HospitalInfo via constructor, e.g.
  // OT module screens pushed several levels deep) read the current
  // hospital's currency synchronously without threading a new param through
  // every intermediate screen. Populated on login and on the first
  // getStoredHospital() read after app restart. See
  // LOCATION_CURRENCY_PARITY_PRD.md Phase 4.
  HospitalInfo? _hospitalCache;
  HospitalInfo? get cachedHospital => _hospitalCache;

  Map<String, String> get _baseHeaders => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };

  Map<String, String> _authHeaders(String token) => {
        ..._baseHeaders,
        'Authorization': 'Bearer $token',
      };

  // ── Find Hospital ──────────────────────────────────────────────────
  // Step 1: Given email/phone, discover which hospital slug to use.
  // GET /api/v1/find-hospital?email=...

  Future<String?> _findHospitalSlug(String login) async {
    try {
      final uri = Uri.parse('${AppConfig.apiBaseUrl}/find-hospital')
          .replace(queryParameters: {'email': login});
      debugPrint('[AuthService] GET $uri');

      final response = await http
          .get(uri, headers: _baseHeaders)
          .timeout(AppConfig.requestTimeout);

      debugPrint('[AuthService] findHospital Status: ${response.statusCode}');
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && body['success'] == true) {
        final data = body['data'] as Map<String, dynamic>;
        final slug = data['slug'] as String;
        final hospitalName = data['hospital_name'] as String?;
        if (hospitalName != null) AppConfig.hospitalName = hospitalName;
        return slug;
      }
      return null;
    } catch (e) {
      debugPrint('[AuthService] findHospital ERROR: $e');
      return null;
    }
  }

  // ── Login ──────────────────────────────────────────────────────────
  // Step 1: find-hospital to discover slug
  // Step 2: POST /{slug}/auth/login with credentials

  Future<LoginResult> login(String login, String password) async {
    try {
      // Step 1 — discover tenant slug from email/phone
      final slug = await _findHospitalSlug(login);
      if (slug == null) {
        return const LoginResult(
          success: false,
          message: 'No hospital account found for this email or phone number.',
        );
      }
      AppConfig.slug = slug;

      // Step 2 — actual login
      final uri = Uri.parse('${AppConfig.hospitalApiUrl}/auth/login');
      debugPrint('[AuthService] POST $uri');

      final response = await http
          .post(
            uri,
            headers: _baseHeaders,
            body: jsonEncode({'login': login, 'password': password}),
          )
          .timeout(AppConfig.requestTimeout);

      debugPrint('[AuthService] Status: ${response.statusCode}');
      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        final data = body['data'] as Map<String, dynamic>;
        final token = data['token'] as String;
        final user = UserInfo.fromJson(data['user'] as Map<String, dynamic>);
        final hospital =
            HospitalInfo.fromJson(data['hospital'] as Map<String, dynamic>);

        await _saveToken(token);
        await _saveUser(user);
        await _saveHospital(hospital);
        await _saveSlug(hospital.slug);
        await _savePermissionContract(data);
        await _markValidatedNow();
        _permissionRefresher.reset();
        AccessGuard.instance.reset();

        AppConfig.hospitalName = hospital.name;
        AppConfig.slug = hospital.slug;
        _applyHospitalTheme(hospital);

        return LoginResult(
          success: true,
          message: (body['message'] as String?) ?? 'Login successful.',
          token: token,
          user: user,
          hospital: hospital,
        );
      }

      return LoginResult(
        success: false,
        message: (body['message'] as String?) ?? 'Invalid credentials.',
      );
    } on TimeoutException {
      debugPrint('[AuthService] Timeout');
      return const LoginResult(
        success: false,
        message: 'Request timed out. Please check your connection.',
      );
    } on SocketException catch (e) {
      debugPrint('[AuthService] SocketException: $e');
      return const LoginResult(
        success: false,
        message: 'No internet connection. Please try again.',
      );
    } catch (e, st) {
      debugPrint('[AuthService] ERROR: $e\n$st');
      return const LoginResult(
        success: false,
        message: 'Something went wrong. Please try again.',
      );
    }
  }

  // ── Refresh session ────────────────────────────────────────────────
  // Validates the stored token against the server and returns fresh user
  // data (including updated permissions).
  //
  // Returns null on 401 (token invalid/revoked) — caller should go to login.
  // Throws on network error — caller should use cached data (offline grace).

  Future<UserInfo?> refreshSession() async {
    final token = await getStoredToken();
    if (token == null) return null;

    final uri = Uri.parse('${AppConfig.hospitalApiUrl}/auth/me');
    debugPrint('[AuthService] GET $uri (refreshSession)');

    final response = await http
        .get(uri, headers: _authHeaders(token))
        .timeout(AppConfig.requestTimeout);

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (body['success'] == true) {
        final data = body['data'] as Map<String, dynamic>;
        final user = UserInfo.fromJson(data['user'] as Map<String, dynamic>);
        if (user.status != 'active') {
          await clearSession();
          AccessGuard.instance.showSessionExpired(
            message: 'Your account is inactive. Contact an administrator.',
          );
          return null;
        }
        await _saveUser(user);
        await _savePermissionContract(data);
        await _markValidatedNow();
        // /auth/me also returns the tenant's current hospital info (name,
        // currency, timezone) — previously dropped here, so an existing
        // logged-in session (resumed via refreshSession(), not a fresh
        // /login) never picked up currency changes made after the user's
        // last real login. See LOCATION_CURRENCY_PARITY_PRD.md.
        final hospitalJson = data['hospital'] as Map<String, dynamic>?;
        if (hospitalJson != null) {
          await _saveHospital(HospitalInfo.fromJson(hospitalJson));
        }
        return user;
      }
    }

    if (response.statusCode == 401) {
      await clearSession();
      AccessGuard.instance.showSessionExpired();
      return null;
    }

    // A blocked-tenant 403 must NOT be treated like a transient network
    // failure — splash's caller falls back to cached user data on any other
    // exception here, which would silently let a plan-expired user straight
    // into the dashboard. See ACCESS_CONTROL_AND_DATA_SYNC_PLAN.md Phase 2.
    if (response.statusCode == 403) {
      Map<String, dynamic>? body;
      try {
        body = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {}
      final blockedMessage = body?['error'] as String?;
      if (blockedMessage != null) {
        AccessGuard.instance.showAccessBlocked(blockedMessage);
        throw PlanAccessBlockedException(blockedMessage);
      }
    }

    throw Exception('Session refresh failed (HTTP ${response.statusCode})');
  }

  // ── Live permission refresh ────────────────────────────────────────
  // Fire-and-forget: triggered by a changed X-Permissions-Version header, a
  // permission-denied 403, or app resume. Single-flight + debounced (and
  // throttled for resume) by PermissionRefreshCoordinator; never throws.

  Future<void> refreshMe({bool fromResume = false}) =>
      _permissionRefresher.trigger(fromResume: fromResume);

  Future<void> _refreshMeNow() async {
    // Logged out while the trigger was queued — nothing to refresh, and
    // showing "session expired" would fight the logout navigation.
    if (await getStoredToken() == null) return;
    // refreshSession() itself routes 401 / inactive users to login.
    final user = await refreshSession();
    if (user != null) applyPermissions(user);
  }

  /// Loads [user]'s role together with the stored permission-sync contract
  /// into PermissionService, which notifies every listening screen.
  void applyPermissions(UserInfo user) {
    PermissionService.instance.load(
      user.role,
      modules: _modules,
      version: _permissionsVersion,
    );
  }

  // ── Logout ─────────────────────────────────────────────────────────

  Future<void> logout() async {
    try {
      final token = await getStoredToken();
      if (token != null) {
        final uri = Uri.parse('${AppConfig.hospitalApiUrl}/auth/logout');
        await http
            .post(uri, headers: _authHeaders(token))
            .timeout(const Duration(seconds: 10));
      }
    } catch (_) {}
    await _clearAll();
  }

  // ── Restore session on app start ───────────────────────────────────
  // Call this in main() or SplashScreen to reload saved slug.

  Future<void> restoreSession() async {
    _restorePermissionContract(await SharedPreferences.getInstance());
    final slug = await _getStoredSlug();
    if (slug != null && slug.isNotEmpty) {
      AppConfig.slug = slug;
    }
    final hospital = await getStoredHospital();
    if (hospital != null) {
      AppConfig.hospitalName = hospital.name;
      _applyHospitalTheme(hospital);
    }
  }

  void _applyHospitalTheme(HospitalInfo hospital) {
    if (hospital.primaryColor == null) return;
    AppColors.applyTheme(ClientTheme(
      primary:      Color(hospital.primaryColor!),
      primaryLight: Color(hospital.primaryLightColor ?? 0xFF2471A3),
      secondary:    Color(hospital.secondaryColor    ?? 0xFF2E86C1),
      background:   Color(hospital.backgroundColor   ?? 0xFFEBF5FB),
    ));
  }

  // ── Token / Session Helpers ────────────────────────────────────────

  Future<String?> getStoredToken() async {
    if (_tokenCache != null) return _tokenCache;
    _tokenCache = await _secureStorage.read(key: _tokenKey);
    if (_tokenCache != null) return _tokenCache;

    // One-time migration — earlier builds stored the token in plaintext
    // SharedPreferences. Move it into secure storage instead of forcing
    // every already-logged-in user to log back in after this update.
    final prefs = await SharedPreferences.getInstance();
    final legacy = prefs.getString(_tokenKey);
    if (legacy != null) {
      await _secureStorage.write(key: _tokenKey, value: legacy);
      await prefs.remove(_tokenKey);
      _tokenCache = legacy;
    }
    return _tokenCache;
  }

  Future<UserInfo?> getStoredUser() async {
    if (_userCache != null) return _userCache;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_userKey);
    if (raw == null) return null;
    _userCache = UserInfo.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    _restorePermissionContract(prefs);
    return _userCache;
  }

  Future<HospitalInfo?> getStoredHospital() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_hospitalKey);
    if (raw == null) return null;
    final hospital = HospitalInfo.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    _hospitalCache = hospital;
    return hospital;
  }

  Future<bool> get hasSession async => (await getStoredToken()) != null;

  // ── Private storage ────────────────────────────────────────────────

  Future<void> _saveToken(String token) async {
    _tokenCache = token;
    await _secureStorage.write(key: _tokenKey, value: token);
  }

  Future<void> _saveUser(UserInfo user) async {
    _userCache = user;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(user.toJson()));
  }

  Future<void> _saveHospital(HospitalInfo hospital) async {
    _hospitalCache = hospital;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_hospitalKey, jsonEncode(hospital.toJson()));
  }

  Future<void> _saveSlug(String slug) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_slugKey, slug);
  }

  Future<String?> _getStoredSlug() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_slugKey);
  }

  /// Keeps the previous value for any field the response omits, so an older
  /// API build never wipes a version/module list stored by a newer one.
  Future<void> _savePermissionContract(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();

    final version = data['permissions_version'];
    if (version is String && version.isNotEmpty) {
      _permissionsVersion = version;
      await prefs.setString(_permVersionKey, version);
    }

    final modules = parseModuleKeys(data['modules']);
    if (modules != null) {
      _modules = modules;
      await prefs.setString(_permModulesKey, jsonEncode(modules));
    }

    final scope = data['scope'];
    if (scope is Map<String, dynamic>) {
      _scope = scope;
      await prefs.setString(_permScopeKey, jsonEncode(scope));
    }
  }

  void _restorePermissionContract(SharedPreferences prefs) {
    _permissionsVersion = prefs.getString(_permVersionKey);
    try {
      final modulesRaw = prefs.getString(_permModulesKey);
      _modules = modulesRaw == null ? null : parseModuleKeys(jsonDecode(modulesRaw));
      final scopeRaw = prefs.getString(_permScopeKey);
      _scope = scopeRaw == null ? null : jsonDecode(scopeRaw) as Map<String, dynamic>;
    } catch (_) {
      _modules = null;
      _scope = null;
    }
  }

  /// Accepts the API's `[{key, label}]` shape as well as a plain key list.
  static List<String>? parseModuleKeys(Object? raw) {
    if (raw is! List) return null;
    return [
      for (final m in raw)
        if (m is Map && m['key'] is String)
          m['key'] as String
        else if (m is String)
          m,
    ];
  }

  Future<void> _markValidatedNow() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _lastValidatedKey,
      DateTime.now().toUtc().millisecondsSinceEpoch,
    );
  }

  Future<bool> isOfflineGraceValid({DateTime? now}) async {
    final prefs = await SharedPreferences.getInstance();
    final millis = prefs.getInt(_lastValidatedKey);
    if (millis == null) return false;
    final validated = DateTime.fromMillisecondsSinceEpoch(
      millis,
      isUtc: true,
    );
    return isWithinOfflineGrace(
      validatedAt: validated,
      now: now ?? DateTime.now().toUtc(),
    );
  }

  static bool isWithinOfflineGrace({
    required DateTime validatedAt,
    required DateTime now,
    Duration grace = offlineGrace,
  }) {
    final age = now.toUtc().difference(validatedAt.toUtc());
    return !age.isNegative && age <= grace;
  }

  Future<void> clearSession() async {
    _tokenCache = null;
    _userCache = null;
    _hospitalCache = null;
    _permissionsVersion = null;
    _modules = null;
    _scope = null;
    _permissionRefresher.reset();
    PermissionService.instance.clear();
    MastersService.instance.clearCache();
    ExamMastersService.instance.clearCache();
    await CacheService.instance.clearAll();
    await _secureStorage.delete(key: _tokenKey);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey); // clears any un-migrated legacy copy too
    await prefs.remove(_userKey);
    await prefs.remove(_hospitalKey);
    await prefs.remove(_lastValidatedKey);
    await prefs.remove(_permVersionKey);
    await prefs.remove(_permModulesKey);
    await prefs.remove(_permScopeKey);
    // Intentionally keep _slugKey so user doesn't need find-hospital again on re-login
  }

  Future<void> _clearAll() => clearSession();
}
