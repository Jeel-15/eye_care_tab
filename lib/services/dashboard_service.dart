import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/dashboard_models.dart';
import 'auth_service.dart';
import 'cache_service.dart';

class DashboardService {
  DashboardService._();
  static final instance = DashboardService._();

  static const _cacheKey = 'cache_dashboard_v1';

  Future<DashboardData?> getCached() async {
    try {
      final json = await CacheService.instance.getJson(_cacheKey);
      if (json == null) return null;
      return DashboardData.fromJson(json as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<DashboardData> fetchDashboard() async {
    final token = await AuthService.instance.getStoredToken();
    if (token == null) throw Exception('Not authenticated');

    final uri = Uri.parse('${AppConfig.hospitalApiUrl}/admin/dashboard');
    final response = await http
        .get(uri, headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        })
        .timeout(AppConfig.requestTimeout);

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      await CacheService.instance.setJson(_cacheKey, json);
      return DashboardData.fromJson(json);
    }

    throw Exception('Dashboard fetch failed (${response.statusCode})');
  }

  Future<TodayPatientsData> fetchTodayPatients({String searchContact = ''}) async {
    final token = await AuthService.instance.getStoredToken();
    if (token == null) throw Exception('Not authenticated');

    final uri = Uri.parse('${AppConfig.hospitalApiUrl}/dashboard/today-patients').replace(
      queryParameters: searchContact.isNotEmpty ? {'search_contact': searchContact} : null,
    );
    final response = await http
        .get(uri, headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        })
        .timeout(AppConfig.requestTimeout);

    if (response.statusCode == 200) {
      return TodayPatientsData.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }

    throw Exception('Today patients fetch failed (${response.statusCode})');
  }
}
