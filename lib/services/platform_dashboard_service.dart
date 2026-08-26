import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/platform_dashboard_models.dart';
import 'platform_auth_service.dart';

class PlatformDashboardService with PlatformAuthenticatedService {
  PlatformDashboardService._();
  static final PlatformDashboardService instance = PlatformDashboardService._();

  Future<PlatformDashboardData?> getDashboard() async {
    try {
      final response = await http
          .get(Uri.parse('${AppConfig.platformApiUrl}/dashboard'), headers: await headers)
          .timeout(AppConfig.requestTimeout);

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        if (body['success'] == true) {
          return PlatformDashboardData.fromJson(body['data'] as Map<String, dynamic>);
        }
      }
    } catch (e) {
      debugPrint('[PlatformDashboard] ERROR: $e');
    }
    return null;
  }
}
