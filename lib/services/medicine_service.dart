import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
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

  /// Bulk-import medicines from a CSV/XLS/XLSX file. See
  /// CSV_MEDICINE_IMPORT_PARITY_PLAN.md — mirrors web's HospitalMedicineImport.
  Future<MedicineImportResult> importMedicines(File file) async {
    final request = http.MultipartRequest('POST', Uri.parse('$_base/medicines/import'));
    request.headers.addAll(await headers);
    request.files.add(await http.MultipartFile.fromPath('file', file.path));

    final streamed = await request.send().timeout(const Duration(seconds: 60));
    final res = await http.Response.fromStream(streamed);
    return MedicineImportResult.fromJson(_parse(res));
  }

  /// Downloads the sample import file and opens it with the system viewer —
  /// same download+open pattern already used in ot_report_service.dart.
  Future<void> downloadSampleFile() async {
    final uri = Uri.parse('$_base/medicines/import/sample');
    final req = http.Request('GET', uri);
    (await headers).forEach((k, v) => req.headers[k] = v);
    final client = http.Client();
    try {
      final streamedRes = await client.send(req).timeout(const Duration(seconds: 30));
      if (streamedRes.statusCode != 200) {
        throw Exception('Download failed (${streamedRes.statusCode})');
      }
      final bytes = await streamedRes.stream.toBytes();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final dir = Platform.isAndroid
          ? ((await getExternalStorageDirectory()) ?? await getApplicationDocumentsDirectory())
          : await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/medicine-sample_$ts.xlsx');
      await file.writeAsBytes(bytes);
      await OpenFilex.open(file.path);
    } finally {
      client.close();
    }
  }

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
