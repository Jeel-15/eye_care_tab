import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
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

  /// Web/API: AdminCollectionController — the dashboard's "Total Collection"
  /// card drill-down. Defaults to today when no range is passed, matching
  /// the controller's own `resolvedDates()` fallback.
  Future<CollectionSummary> fetchCollectionSummary({required String startDate, required String endDate}) async {
    final token = await AuthService.instance.getStoredToken();
    if (token == null) throw Exception('Not authenticated');

    final uri = Uri.parse('${AppConfig.hospitalApiUrl}/dashboard/collection').replace(
      queryParameters: {'start_date': startDate, 'end_date': endDate},
    );
    final response = await http
        .get(uri, headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'})
        .timeout(AppConfig.requestTimeout);

    if (response.statusCode == 200) {
      return CollectionSummary.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw Exception('Collection summary fetch failed (${response.statusCode})');
  }

  Future<CollectionDetail> fetchCollectionDetail(int receptionId, {required String startDate, required String endDate}) async {
    final token = await AuthService.instance.getStoredToken();
    if (token == null) throw Exception('Not authenticated');

    final uri = Uri.parse('${AppConfig.hospitalApiUrl}/dashboard/collection/$receptionId').replace(
      queryParameters: {'start_date': startDate, 'end_date': endDate},
    );
    final response = await http
        .get(uri, headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'})
        .timeout(AppConfig.requestTimeout);

    if (response.statusCode == 200) {
      return CollectionDetail.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw Exception('Collection detail fetch failed (${response.statusCode})');
  }

  /// Web pull 2026-09-30 — the "Export" button on the collection detail
  /// page (`AdminCollectionController::export`), missing from this app
  /// entirely. Same download-bytes-then-open pattern as
  /// `ReportService.downloadAndOpenExport`.
  Future<void> downloadCollectionExport(int receptionId, {required String startDate, required String endDate}) async {
    final token = await AuthService.instance.getStoredToken();
    if (token == null) throw Exception('Not authenticated');

    final uri = Uri.parse('${AppConfig.hospitalApiUrl}/dashboard/collection/$receptionId/export').replace(
      queryParameters: {'start_date': startDate, 'end_date': endDate},
    );
    final req = http.Request('GET', uri);
    req.headers['Authorization'] = 'Bearer $token';
    req.headers['Accept'] = 'application/json';

    final client = http.Client();
    try {
      final streamedRes = await client.send(req).timeout(const Duration(seconds: 120));
      if (streamedRes.statusCode != 200) {
        throw Exception('Export failed (${streamedRes.statusCode})');
      }
      final bytes = await streamedRes.stream.toBytes();
      final ts = DateTime.now().millisecondsSinceEpoch;

      Directory dir;
      if (Platform.isAndroid) {
        dir = (await getExternalStorageDirectory()) ?? await getApplicationDocumentsDirectory();
      } else {
        dir = await getApplicationDocumentsDirectory();
      }

      final file = File('${dir.path}/Collection_${receptionId}_$ts.xlsx');
      await file.writeAsBytes(bytes);
      await OpenFilex.open(file.path);
    } finally {
      client.close();
    }
  }
}
