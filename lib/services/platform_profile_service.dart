import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/platform_admin_models.dart';
import 'platform_auth_service.dart';

class PlatformProfileService with PlatformAuthenticatedService {
  PlatformProfileService._();
  static final PlatformProfileService instance = PlatformProfileService._();

  final String _base = '${AppConfig.platformApiUrl}/profile';

  Future<PlatformAdmin?> getProfile() async {
    try {
      final response = await http
          .get(Uri.parse(_base), headers: await headers)
          .timeout(AppConfig.requestTimeout);

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        if (body['success'] == true) {
          return PlatformAdmin.fromJson(body['data'] as Map<String, dynamic>);
        }
      }
    } catch (e) {
      debugPrint('[PlatformProfile] getProfile ERROR: $e');
    }
    return null;
  }

  Future<({bool success, String message, PlatformAdmin? admin})> updateProfile(String name, String email) async {
    try {
      final response = await http
          .put(Uri.parse(_base), headers: await headers, body: jsonEncode({'name': name, 'email': email}))
          .timeout(AppConfig.requestTimeout);

      final parsed = jsonDecode(response.body) as Map<String, dynamic>;
      final success = parsed['success'] as bool? ?? false;
      return (
        success: success,
        message: parsed['message'] as String? ?? '',
        admin:   success ? PlatformAdmin.fromJson(parsed['data'] as Map<String, dynamic>) : null,
      );
    } catch (e) {
      debugPrint('[PlatformProfile] updateProfile ERROR: $e');
      return (success: false, message: 'Network error.', admin: null);
    }
  }

  Future<({bool success, String message})> changePassword({
    required String currentPassword,
    required String password,
    required String passwordConfirmation,
  }) async {
    try {
      final response = await http
          .put(
            Uri.parse('$_base/password'),
            headers: await headers,
            body: jsonEncode({
              'current_password':      currentPassword,
              'password':              password,
              'password_confirmation': passwordConfirmation,
            }),
          )
          .timeout(AppConfig.requestTimeout);

      final parsed = jsonDecode(response.body) as Map<String, dynamic>;
      return (success: parsed['success'] as bool? ?? false, message: parsed['message'] as String? ?? '');
    } catch (e) {
      debugPrint('[PlatformProfile] changePassword ERROR: $e');
      return (success: false, message: 'Network error.');
    }
  }
}
