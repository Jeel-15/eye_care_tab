import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../config/client_theme.dart';
import '../constants/app_colors.dart';
import '../models/auth_models.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  static const _tokenKey = 'auth_token';
  static const _userKey = 'cached_user';
  static const _hospitalKey = 'hospital_info';
  static const _slugKey = 'hospital_slug';

  // In-memory token cache — eliminates SharedPreferences I/O on every request.
  String? _tokenCache;

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
      debugPrint('[AuthService] findHospital Body: ${response.body}');

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
      debugPrint('[AuthService] Body: ${response.body}');

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
        await _saveUser(user);
        return user;
      }
    }

    if (response.statusCode == 401) {
      await _clearAll();
      return null;
    }

    throw Exception('Session refresh failed (HTTP ${response.statusCode})');
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
    final prefs = await SharedPreferences.getInstance();
    _tokenCache = prefs.getString(_tokenKey);
    return _tokenCache;
  }

  Future<UserInfo?> getStoredUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_userKey);
    if (raw == null) return null;
    return UserInfo.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<HospitalInfo?> getStoredHospital() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_hospitalKey);
    if (raw == null) return null;
    return HospitalInfo.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<bool> get hasSession async => (await getStoredToken()) != null;

  // ── Private storage ────────────────────────────────────────────────

  Future<void> _saveToken(String token) async {
    _tokenCache = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<void> _saveUser(UserInfo user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(user.toJson()));
  }

  Future<void> _saveHospital(HospitalInfo hospital) async {
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

  Future<void> _clearAll() async {
    _tokenCache = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
    await prefs.remove(_hospitalKey);
    // Intentionally keep _slugKey so user doesn't need find-hospital again on re-login
  }
}
