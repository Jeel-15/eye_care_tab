import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/platform_notification_models.dart';
import 'platform_auth_service.dart';

class PlatformNotificationService with PlatformAuthenticatedService {
  PlatformNotificationService._();
  static final PlatformNotificationService instance = PlatformNotificationService._();

  final String _base = '${AppConfig.platformApiUrl}/notifications';

  Future<PlatformNotificationData?> getNotifications() async {
    try {
      final response = await http
          .get(Uri.parse(_base), headers: await headers)
          .timeout(AppConfig.requestTimeout);

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        if (body['success'] == true) {
          final data = body['data'] as Map<String, dynamic>;
          return PlatformNotificationData(
            history: (data['history'] as List)
                .map((e) => PlatformNotificationItem.fromJson(e as Map<String, dynamic>))
                .toList(),
            tenants: (data['tenants'] as List)
                .map((e) => NotificationTenantOption.fromJson(e as Map<String, dynamic>))
                .toList(),
          );
        }
      }
    } catch (e) {
      debugPrint('[PlatformNotification] getNotifications ERROR: $e');
    }
    return null;
  }

  Future<({bool success, String message})> send({
    required String subject,
    required String message,
    required String recipient, // 'all' | 'specific'
    List<int>? tenantIds,
  }) async {
    try {
      final body = <String, dynamic>{
        'subject':   subject,
        'message':   message,
        'recipient': recipient,
        if (recipient == 'specific' && tenantIds != null) 'tenant_ids': tenantIds,
      };

      final response = await http
          .post(Uri.parse('$_base/send'), headers: await headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 60));

      final parsed = jsonDecode(response.body) as Map<String, dynamic>;
      return (success: parsed['success'] as bool? ?? false, message: parsed['message'] as String? ?? '');
    } catch (e) {
      debugPrint('[PlatformNotification] send ERROR: $e');
      return (success: false, message: 'Network error.');
    }
  }
}
