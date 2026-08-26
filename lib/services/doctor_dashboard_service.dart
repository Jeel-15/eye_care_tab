import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/doctor_dashboard_models.dart';
import 'auth_service.dart';

class DoctorDashboardService {
  DoctorDashboardService._();
  static final DoctorDashboardService instance = DoctorDashboardService._();

  Future<DoctorDashboardData> fetchDashboard({int? viewDoctorId}) async {
    final token = await AuthService.instance.getStoredToken();

    var urlStr = '${AppConfig.hospitalApiUrl}/dashboard/doctor';
    if (viewDoctorId != null) urlStr += '?view_doctor_id=$viewDoctorId';

    final uri = Uri.parse(urlStr);
    debugPrint('[DoctorDashboardService] GET $uri');

    final response = await http.get(
      uri,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    ).timeout(AppConfig.requestTimeout);

    debugPrint('[DoctorDashboardService] Status: ${response.statusCode}');

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (body['success'] == true) {
        return DoctorDashboardData.fromJson(body['data'] as Map<String, dynamic>);
      }
      throw Exception((body['message'] as String?) ?? 'Doctor dashboard load failed.');
    }

    throw Exception('Doctor dashboard HTTP ${response.statusCode}');
  }
}
