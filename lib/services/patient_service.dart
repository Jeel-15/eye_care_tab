import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/patient_models.dart';
import 'base_service.dart';
import 'cache_service.dart';

class PatientService with AuthenticatedService {
  PatientService._();
  static final PatientService instance = PatientService._();


  // ── Patients List ────────────────────────────────────────────────────────

  static String _cacheKey(bool showAll) =>
      showAll ? 'cache_patients_all_v1' : 'cache_patients_today_v1';

  Future<({List<Patient> patients, PatientMeta meta, PatientStats stats})?>
      getCachedPatients({bool showAll = false}) async {
    try {
      final json = await CacheService.instance.getJson(_cacheKey(showAll));
      if (json == null) return null;
      final body = json as Map<String, dynamic>;
      final data = body['data'] as Map<String, dynamic>;
      final patients = (data['data'] as List)
          .map((e) => Patient.fromJson(e as Map<String, dynamic>))
          .toList();
      final meta = PatientMeta.fromJson(data['meta'] as Map<String, dynamic>);
      final stats = PatientStats.fromJson(data['stats'] as Map<String, dynamic>);
      return (patients: patients, meta: meta, stats: stats);
    } catch (_) {
      return null;
    }
  }

  Future<({List<Patient> patients, PatientMeta meta, PatientStats stats})>
      fetchPatients({
    bool showAll = false,
    String search = '',
    int page = 1,
  }) async {
    final params = {
      'all': showAll ? '1' : '0',
      if (search.isNotEmpty) 'search': search,
      'page': page.toString(),
      'per_page': '20',
    };
    final uri = Uri.parse('${AppConfig.hospitalApiUrl}/patients')
        .replace(queryParameters: params);

    final resp = await http
        .get(uri, headers: await headers)
        .timeout(AppConfig.requestTimeout);

    if (resp.statusCode != 200) {
      throw Exception('Failed to load patients: ${resp.statusCode}');
    }

    final body = jsonDecode(resp.body) as Map<String, dynamic>;

    // Cache page-1 no-search result for instant next open
    if (page == 1 && search.isEmpty) {
      await CacheService.instance.setJson(_cacheKey(showAll), body);
    }
    final data = body['data'] as Map<String, dynamic>;

    final patients = (data['data'] as List)
        .map((e) => Patient.fromJson(e as Map<String, dynamic>))
        .toList();

    final meta = PatientMeta.fromJson(data['meta'] as Map<String, dynamic>);
    final stats =
        PatientStats.fromJson(data['stats'] as Map<String, dynamic>);

    return (patients: patients, meta: meta, stats: stats);
  }

  // ── Next MRD ─────────────────────────────────────────────────────────────
  Future<String> fetchNextMrd() async {
    final uri = Uri.parse('${AppConfig.hospitalApiUrl}/patients/next-mrd');
    final resp = await http
        .get(uri, headers: await headers)
        .timeout(AppConfig.requestTimeout);

    if (resp.statusCode != 200) {
      throw Exception('Failed to fetch MRD: ${resp.statusCode}');
    }

    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    return body['mrd'] as String? ?? '';
  }

  // ── Search by contact ────────────────────────────────────────────────────
  Future<List<ContactSuggestion>> searchByContact(String contact) async {
    final uri = Uri.parse('${AppConfig.hospitalApiUrl}/patients/search-by-contact')
        .replace(queryParameters: {'contact': contact});

    final resp = await http
        .get(uri, headers: await headers)
        .timeout(AppConfig.requestTimeout);

    if (resp.statusCode != 200) return [];

    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final list = body['patients'] as List? ?? [];

    return list
        .map((e) => ContactSuggestion.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Register Walk-in ─────────────────────────────────────────────────────
  Future<Patient> registerWalkIn(Map<String, dynamic> data) async {
    final uri = Uri.parse('${AppConfig.hospitalApiUrl}/patients');
    final resp = await http
        .post(uri,
            headers: await headers,
            body: jsonEncode(data))
        .timeout(AppConfig.requestTimeout);

    if (resp.statusCode != 201) {
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      throw Exception(body['message'] ?? 'Failed to register patient.');
    }

    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    return Patient.fromJson(body['data'] as Map<String, dynamic>);
  }

  // ── Register Phone Appointment ───────────────────────────────────────────
  Future<Patient> registerPhone(Map<String, dynamic> data) async {
    final uri = Uri.parse('${AppConfig.hospitalApiUrl}/patients/phone');
    final resp = await http
        .post(uri,
            headers: await headers,
            body: jsonEncode(data))
        .timeout(AppConfig.requestTimeout);

    if (resp.statusCode != 201) {
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      throw Exception(body['message'] ?? 'Failed to register phone appointment.');
    }

    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    return Patient.fromJson(body['data'] as Map<String, dynamic>);
  }

  // ── Update Patient ───────────────────────────────────────────────────────
  Future<Patient> updatePatient(int id, Map<String, dynamic> data) async {
    final uri = Uri.parse('${AppConfig.hospitalApiUrl}/patients/$id');
    final resp = await http
        .put(uri,
            headers: await headers,
            body: jsonEncode(data))
        .timeout(AppConfig.requestTimeout);

    if (resp.statusCode != 200) {
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      throw Exception(body['message'] ?? 'Failed to update patient.');
    }

    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    return Patient.fromJson(body['data'] as Map<String, dynamic>);
  }

  // ── Delete Patient ───────────────────────────────────────────────────────
  Future<void> deletePatient(int id) async {
    final uri = Uri.parse('${AppConfig.hospitalApiUrl}/patients/$id');
    final resp = await http
        .delete(uri, headers: await headers)
        .timeout(AppConfig.requestTimeout);

    if (resp.statusCode != 200) {
      throw Exception('Failed to delete patient.');
    }
  }

  // ── Check-in ─────────────────────────────────────────────────────────────
  Future<Patient> checkIn(
      int patientId, Map<String, dynamic> data) async {
    final uri =
        Uri.parse('${AppConfig.hospitalApiUrl}/patients/$patientId/checkin');
    final resp = await http
        .post(uri,
            headers: await headers,
            body: jsonEncode(data))
        .timeout(AppConfig.requestTimeout);

    if (resp.statusCode != 200) {
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      throw Exception(body['message'] ?? 'Check-in failed.');
    }

    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    return Patient.fromJson(body['data'] as Map<String, dynamic>);
  }
}
