import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/medicine_models.dart';
import 'base_service.dart';
import 'exam_masters_service.dart';

class ExamService with AuthenticatedService {
  ExamService._();
  static final ExamService instance = ExamService._();


  Map<String, dynamic> _parseBody(http.Response res) {
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400) {
      throw Exception(body['message'] ?? 'Request failed (${res.statusCode})');
    }
    return body;
  }

  // ── Primary Exam ─────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> loadPrimaryExam(int patientId) async {
    final uri = Uri.parse(
        '${AppConfig.hospitalApiUrl}/exams/primary/$patientId');
    final resp = await http
        .get(uri, headers: await headers)
        .timeout(AppConfig.requestTimeout);
    final body = _parseBody(resp);
    final data = body['data'];
    if (data == null) return null;
    return data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> savePrimaryExam(
      int patientId, Map<String, dynamic> payload) async {
    final uri = Uri.parse(
        '${AppConfig.hospitalApiUrl}/exams/primary/$patientId');
    final resp = await http
        .post(uri, headers: await headers, body: jsonEncode(payload))
        .timeout(AppConfig.requestTimeout);
    final body = _parseBody(resp);
    return body['data'] as Map<String, dynamic>;
  }

  // ── Secondary Exam ────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> loadSecondaryExam(int patientId) async {
    final uri = Uri.parse(
        '${AppConfig.hospitalApiUrl}/exams/secondary/$patientId');
    final resp = await http
        .get(uri, headers: await headers)
        .timeout(AppConfig.requestTimeout);
    final body = _parseBody(resp);
    final data = body['data'];
    if (data == null) return null;
    return data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> saveSecondaryExam(
      int patientId, Map<String, dynamic> payload) async {
    final uri = Uri.parse(
        '${AppConfig.hospitalApiUrl}/exams/secondary/$patientId');
    final resp = await http
        .post(uri, headers: await headers, body: jsonEncode(payload))
        .timeout(AppConfig.requestTimeout);
    final body = _parseBody(resp);
    return body['data'] as Map<String, dynamic>;
  }

  // ── Exam Form Data (dosages, routes, medicine groups + all exam masters) ─────

  Future<ExamFormData> loadFormData() async {
    final results = await Future.wait([
      _fetchList('medicine-dosages'),
      _fetchList('medicine-routes'),
      ExamMastersService.instance.fetchAll(),
      fetchMedGroups(),
    ]);

    return ExamFormData(
      dosages: (results[0] as List)
          .map((e) => MedMasterItem.fromJson(e as Map<String, dynamic>, field: 'dosage'))
          .toList(),
      routes: (results[1] as List)
          .map((e) => MedMasterItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      masters: results[2] as ExamMastersData,
      medGroups: results[3] as List<MedGroup>,
    );
  }

  Future<List<MedGroup>> fetchMedGroups() async {
    try {
      final uri = Uri.parse('${AppConfig.hospitalApiUrl}/medicine-groups')
          .replace(queryParameters: {'per_page': '200'});
      final resp = await http.get(uri, headers: await headers).timeout(AppConfig.requestTimeout);
      final body = _parseBody(resp);
      final list = body['data'] as List? ?? [];
      return list.map((e) => MedGroup.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<dynamic>> _fetchList(String path) async {
    final uri = Uri.parse('${AppConfig.hospitalApiUrl}/$path');
    final resp = await http
        .get(uri, headers: await headers)
        .timeout(AppConfig.requestTimeout);
    final body = _parseBody(resp);
    return body['data'] as List? ?? [];
  }

  // ── Medicine search ───────────────────────────────────────────────────────────

  Future<List<MedItem>> searchMedicines(String query) async {
    if (query.isEmpty) return [];
    final uri = Uri.parse('${AppConfig.hospitalApiUrl}/medicines')
        .replace(queryParameters: {'search': query, 'per_page': '20'});
    final resp = await http
        .get(uri, headers: await headers)
        .timeout(AppConfig.requestTimeout);
    final body = _parseBody(resp);
    final list = body['data'] as List? ?? [];
    return list
        .map((e) => MedItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

class ExamFormData {
  final List<MedMasterItem> dosages;
  final List<MedMasterItem> routes;
  final ExamMastersData masters;
  final List<MedGroup> medGroups;

  const ExamFormData({
    required this.dosages,
    required this.routes,
    required this.masters,
    this.medGroups = const [],
  });
}
