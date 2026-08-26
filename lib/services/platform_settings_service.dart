import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/platform_settings_models.dart';
import 'platform_auth_service.dart';

class PlatformSettingsService with PlatformAuthenticatedService {
  PlatformSettingsService._();
  static final PlatformSettingsService instance = PlatformSettingsService._();

  final String _base = '${AppConfig.platformApiUrl}/settings';

  Future<PlatformSettingsData?> getSettings() async {
    try {
      final response = await http
          .get(Uri.parse(_base), headers: await headers)
          .timeout(AppConfig.requestTimeout);

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        if (body['success'] == true) {
          return PlatformSettingsData.fromJson(body['data'] as Map<String, dynamic>);
        }
      }
    } catch (e) {
      debugPrint('[PlatformSettings] getSettings ERROR: $e');
    }
    return null;
  }

  Future<({bool success, String message})> updateSettings(Map<String, dynamic> data) async {
    try {
      final response = await http
          .put(Uri.parse(_base), headers: await headers, body: jsonEncode(data))
          .timeout(AppConfig.requestTimeout);

      final parsed = jsonDecode(response.body) as Map<String, dynamic>;
      return (success: parsed['success'] as bool? ?? false, message: parsed['message'] as String? ?? '');
    } catch (e) {
      debugPrint('[PlatformSettings] updateSettings ERROR: $e');
      return (success: false, message: 'Network error.');
    }
  }
}
