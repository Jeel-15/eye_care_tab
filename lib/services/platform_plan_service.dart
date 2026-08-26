import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/platform_plan_models.dart';
import 'platform_auth_service.dart';

class PlatformPlanService with PlatformAuthenticatedService {
  PlatformPlanService._();
  static final PlatformPlanService instance = PlatformPlanService._();

  final String _base = '${AppConfig.platformApiUrl}/plans';

  Future<PlatformPlanData?> getPlans() async {
    try {
      final response = await http
          .get(Uri.parse(_base), headers: await headers)
          .timeout(AppConfig.requestTimeout);

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        if (body['success'] == true) {
          return PlatformPlanData.fromJson(body['data'] as Map<String, dynamic>);
        }
      }
    } catch (e) {
      debugPrint('[PlatformPlan] getPlans ERROR: $e');
    }
    return null;
  }

  Future<({bool success, String message})> updatePlans(Map<String, dynamic> data) async {
    try {
      final response = await http
          .put(Uri.parse(_base), headers: await headers, body: jsonEncode(data))
          .timeout(AppConfig.requestTimeout);

      final parsed = jsonDecode(response.body) as Map<String, dynamic>;
      return (success: parsed['success'] as bool? ?? false, message: parsed['message'] as String? ?? '');
    } catch (e) {
      debugPrint('[PlatformPlan] updatePlans ERROR: $e');
      return (success: false, message: 'Network error.');
    }
  }
}
