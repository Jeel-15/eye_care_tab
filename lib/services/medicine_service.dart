import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/medicine_models.dart';
import 'base_service.dart';

class MedicineService with AuthenticatedService {
  MedicineService._();
  static final MedicineService instance = MedicineService._();

  String get _base => AppConfig.hospitalApiUrl;

  // ── Helpers ─────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _get(String path, {Map<String, String>? params}) async {
    final uri = Uri.parse('$_base/$path').replace(queryParameters: params);
    final res = await http.get(uri, headers: await headers);
    return _parse(res);
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    final res = await http.post(
      Uri.parse('$_base/$path'),
      headers: await headers,
      body: jsonEncode(body),
    );
    return _parse(res);
  }

  Future<Map<String, dynamic>> _put(String path, Map<String, dynamic> body) async {
    final res = await http.put(
      Uri.parse('$_base/$path'),
      headers: await headers,
      body: jsonEncode(body),
    );
    return _parse(res);
  }

  Future<void> _delete(String path) async {
    final res = await http.delete(Uri.parse('$_base/$path'), headers: await headers);
    _parse(res);
  }

  Map<String, dynamic> _parse(http.Response res) {
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400) {
      throw Exception(body['message'] ?? 'Request failed (${res.statusCode})');
    }
    return body;
  }

  // ── Dosages ──────────────────────────────────────────────────────────────────

  Future<List<MedMasterItem>> fetchDosages() async {
    final j = await _get('medicine-dosages');
    return (j['data'] as List? ?? [])
        .map((e) => MedMasterItem.fromJson(e as Map<String, dynamic>, field: 'dosage'))
        .toList();
  }

  Future<void> createDosage(String value) => _post('medicine-dosages', {'dosage': value});
  Future<void> updateDosage(int id, String value) => _put('medicine-dosages/$id', {'dosage': value});
  Future<void> deleteDosage(int id) => _delete('medicine-dosages/$id');

  // ── Medicine Types ────────────────────────────────────────────────────────────

  Future<List<MedMasterItem>> fetchTypes() async {
    final j = await _get('medicine-types');
    return (j['data'] as List? ?? [])
        .map((e) => MedMasterItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> createType(String value) => _post('medicine-types', {'name': value});
  Future<void> updateType(int id, String value) => _put('medicine-types/$id', {'name': value});
  Future<void> deleteType(int id) => _delete('medicine-types/$id');

  // ── Medicine Categories ───────────────────────────────────────────────────────

  Future<List<MedMasterItem>> fetchCategories() async {
    final j = await _get('medicine-categories');
    return (j['data'] as List? ?? [])
        .map((e) => MedMasterItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> createCategory(String value) => _post('medicine-categories', {'name': value});
  Future<void> updateCategory(int id, String value) => _put('medicine-categories/$id', {'name': value});
  Future<void> deleteCategory(int id) => _delete('medicine-categories/$id');

  // ── Routes of Administration ──────────────────────────────────────────────────

  Future<List<MedMasterItem>> fetchRoutes() async {
    final j = await _get('medicine-routes');
    return (j['data'] as List? ?? [])
        .map((e) => MedMasterItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> createRoute(String value) => _post('medicine-routes', {'name': value});
  Future<void> updateRoute(int id, String value) => _put('medicine-routes/$id', {'name': value});
  Future<void> deleteRoute(int id) => _delete('medicine-routes/$id');

  // ── Medicines ─────────────────────────────────────────────────────────────────

  Future<MedListResult> fetchMedicines({String search = '', int page = 1}) async {
    final params = <String, String>{'page': '$page'};
    if (search.isNotEmpty) params['search'] = search;
    final j = await _get('medicines', params: params);
    return MedListResult.fromJson(j);
  }

  Future<void> createMedicine(Map<String, dynamic> data) => _post('medicines', data);
  Future<void> updateMedicine(int id, Map<String, dynamic> data) => _put('medicines/$id', data);
  Future<void> deleteMedicine(int id) => _delete('medicines/$id');

  // ── Medicine Groups ───────────────────────────────────────────────────────────

  Future<MedGroupListResult> fetchGroups({int page = 1}) async {
    final j = await _get('medicine-groups', params: {'page': '$page'});
    return MedGroupListResult.fromJson(j);
  }

  /// Round 3 Phase 4 — `GET /ot/medicine-groups?scope=ot`, same controller
  /// method as [fetchGroups] with an additive `scope` filter (not a
  /// duplicate endpoint). Used by the OT Surgery Record form's
  /// medicine-group picker.
  Future<MedGroupListResult> fetchOtMedicineGroups({int page = 1}) async {
    final j = await _get('ot/medicine-groups', params: {'page': '$page', 'scope': 'ot'});
    return MedGroupListResult.fromJson(j);
  }

  Future<MedGroupFormData> fetchGroupFormData() async {
    final j = await _get('medicine-groups/form-data');
    return MedGroupFormData.fromJson(j['data'] as Map<String, dynamic>);
  }

  Future<MedGroup> fetchGroup(int id) async {
    final j = await _get('medicine-groups/$id');
    return MedGroup.fromJson(j['data'] as Map<String, dynamic>);
  }

  Future<void> createGroup(Map<String, dynamic> data) => _post('medicine-groups', data);
  Future<void> updateGroup(int id, Map<String, dynamic> data) => _put('medicine-groups/$id', data);
  Future<void> deleteGroup(int id) => _delete('medicine-groups/$id');
}
