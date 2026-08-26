import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../constants/app_colors.dart';
import '../models/platform_admin_models.dart';

// ── Mixin used by all platform services ──────────────────────────────────────
// Parallel to AuthenticatedService in base_service.dart but reads platform token.
mixin PlatformAuthenticatedService {
  Future<Map<String, String>> get headers async {
    final token = await PlatformAuthService.instance.getStoredToken();
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }
}

// ── Service ───────────────────────────────────────────────────────────────────
class PlatformAuthService {
  PlatformAuthService._();
  static final PlatformAuthService instance = PlatformAuthService._();

  static const _tokenKey = 'platform_admin_token';
  static const _adminKey = 'cached_platform_admin';

  String? _tokenCache;

  Map<String, String> get _baseHeaders => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };

  Map<String, String> _authHeaders(String token) => {
        ..._baseHeaders,
        'Authorization': 'Bearer $token',
      };

  // ── Login ──────────────────────────────────────────────────────────────────

  Future<PlatformLoginResult> login(String email, String password) async {
    try {
      final uri = Uri.parse('${AppConfig.platformApiUrl}/auth/login');
      debugPrint('[PlatformAuth] POST $uri');

      final response = await http
          .post(
            uri,
            headers: _baseHeaders,
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(AppConfig.requestTimeout);

      debugPrint('[PlatformAuth] Status: ${response.statusCode}');

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && body['success'] == true) {
        final data  = body['data'] as Map<String, dynamic>;
        final token = data['token'] as String;
        final admin = PlatformAdmin.fromJson(data['admin'] as Map<String, dynamic>);

        await _saveToken(token);
        await _saveAdmin(admin);
        AppColors.resetToDefault();

        return PlatformLoginResult(
          success: true,
          message: (body['message'] as String?) ?? 'Login successful.',
          token: token,
          admin: admin,
        );
      }

      return PlatformLoginResult(
        success: false,
        message: (body['message'] as String?) ?? 'Invalid credentials.',
      );
    } on TimeoutException {
      return const PlatformLoginResult(success: false, message: 'Request timed out.');
    } on SocketException {
      return const PlatformLoginResult(success: false, message: 'No internet connection.');
    } catch (e) {
      debugPrint('[PlatformAuth] ERROR: $e');
      return const PlatformLoginResult(success: false, message: 'Something went wrong.');
    }
  }

  // ── Refresh session ────────────────────────────────────────────────────────

  Future<PlatformAdmin?> refreshSession() async {
    final token = await getStoredToken();
    if (token == null) return null;

    try {
      final uri = Uri.parse('${AppConfig.platformApiUrl}/auth/me');
      final response = await http
          .get(uri, headers: _authHeaders(token))
          .timeout(AppConfig.requestTimeout);

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        if (body['success'] == true) {
          final admin = PlatformAdmin.fromJson(body['data'] as Map<String, dynamic>);
          await _saveAdmin(admin);
          AppColors.resetToDefault();
          return admin;
        }
      }
      if (response.statusCode == 401) {
        await _clearAll();
        return null;
      }
    } catch (_) {}

    // Network error — return cached admin so the user stays logged in offline
    return getStoredAdmin();
  }

  // ── Logout ─────────────────────────────────────────────────────────────────

  Future<void> logout() async {
    try {
      final token = await getStoredToken();
      if (token != null) {
        final uri = Uri.parse('${AppConfig.platformApiUrl}/auth/logout');
        await http
            .post(uri, headers: _authHeaders(token))
            .timeout(const Duration(seconds: 10));
      }
    } catch (_) {}
    await _clearAll();
    AppColors.resetToDefault();
  }

  // ── Storage helpers ────────────────────────────────────────────────────────

  Future<String?> getStoredToken() async {
    if (_tokenCache != null) return _tokenCache;
    final prefs = await SharedPreferences.getInstance();
    _tokenCache = prefs.getString(_tokenKey);
    return _tokenCache;
  }

  Future<PlatformAdmin?> getStoredAdmin() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_adminKey);
    if (raw == null) return null;
    return PlatformAdmin.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<bool> get hasSession async => (await getStoredToken()) != null;

  Future<void> _saveToken(String token) async {
    _tokenCache = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<void> _saveAdmin(PlatformAdmin admin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_adminKey, jsonEncode(admin.toJson()));
  }

  Future<void> _clearAll() async {
    _tokenCache = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_adminKey);
    // Never touch auth_token / cached_user / hospital_slug — those are hospital sessions
  }
}
