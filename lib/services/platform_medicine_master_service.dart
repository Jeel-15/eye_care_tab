import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/platform_medicine_master_models.dart';
import 'platform_auth_service.dart';

class PlatformMedicineMasterService with PlatformAuthenticatedService {
  PlatformMedicineMasterService._();
  static final instance = PlatformMedicineMasterService._();

  String get _base => '${AppConfig.platformApiUrl}/medicine-master';

  Future<MedicineFormData?> getFormData() async {
    try {
      final h = await headers;
      final r = await http.get(Uri.parse('$_base/form-data'), headers: h);
      final body = jsonDecode(r.body);
      if (body['success'] != true) return null;
      final d = body['data'];
      return MedicineFormData(
        types:   (d['types']   as List).map((e) => MasterMedicineType.fromJson(e)).toList(),
        dosages: (d['dosages'] as List).map((e) => MasterDosage.fromJson(e)).toList(),
      );
    } catch (_) { return null; }
  }

  Future<({List<T> items, int total, int lastPage})?> _list<T>(
    String path,
    T Function(Map<String, dynamic>) fromJson, {
    Map<String, String> query = const {},
  }) async {
    try {
      final h = await headers;
      final uri = Uri.parse('$_base/$path').replace(queryParameters: query);
      final r = await http.get(uri, headers: h);
      final body = jsonDecode(r.body);
      if (body['success'] != true) return null;
      final d = body['data'];
      return (
        items:    (d['items'] as List).map((e) => fromJson(e as Map<String, dynamic>)).toList(),
        total:    (d['total'] as num).toInt(),
        lastPage: (d['last_page'] as num).toInt(),
      );
    } catch (_) { return null; }
  }

  Future<({bool success, String message})> _post(String path, Map<String, dynamic> data) async {
    try {
      final h = await headers;
      final r = await http.post(Uri.parse('$_base/$path'), headers: h, body: jsonEncode(data));
      final body = jsonDecode(r.body);
      return (success: body['success'] == true, message: (body['message'] ?? 'Error') as String);
    } catch (e) { return (success: false, message: e.toString()); }
  }

  Future<({bool success, String message})> _put(String path, Map<String, dynamic> data) async {
    try {
      final h = await headers;
      final r = await http.put(Uri.parse('$_base/$path'), headers: h, body: jsonEncode(data));
      final body = jsonDecode(r.body);
      return (success: body['success'] == true, message: (body['message'] ?? 'Error') as String);
    } catch (e) { return (success: false, message: e.toString()); }
  }

  Future<({bool success, String message})> _delete(String path) async {
    try {
      final h = await headers;
      final r = await http.delete(Uri.parse('$_base/$path'), headers: h);
      final body = jsonDecode(r.body);
      return (success: body['success'] == true, message: (body['message'] ?? 'Error') as String);
    } catch (e) { return (success: false, message: e.toString()); }
  }

  Future<bool> _toggle(String path) async {
    try {
      final h = await headers;
      final r = await http.patch(Uri.parse('$_base/$path'), headers: h);
      final body = jsonDecode(r.body);
      return body['is_active'] == true || body['is_active'] == 1;
    } catch (_) { return false; }
  }

  // ── Dosages ───────────────────────────────────────────────────────────────

  Future<({List<MasterDosage> items, int total, int lastPage})?> getDosages({String? search, int page = 1}) =>
      _list('dosages', MasterDosage.fromJson, query: {if (search != null) 'search': search, 'page': '$page'});

  Future<({bool success, String message})> storeDosage(String dosage) => _post('dosages', {'dosage': dosage});
  Future<({bool success, String message})> updateDosage(int id, String dosage) => _put('dosages/$id', {'dosage': dosage});
  Future<({bool success, String message})> deleteDosage(int id) => _delete('dosages/$id');
  Future<bool> toggleDosage(int id) => _toggle('dosages/$id/toggle');

  // ── Types ─────────────────────────────────────────────────────────────────

  Future<({List<MasterMedicineType> items, int total, int lastPage})?> getTypes({String? search, int page = 1}) =>
      _list('types', MasterMedicineType.fromJson, query: {if (search != null) 'search': search, 'page': '$page'});

  Future<({bool success, String message})> storeType(String name) => _post('types', {'name': name});
  Future<({bool success, String message})> updateType(int id, String name) => _put('types/$id', {'name': name});
  Future<({bool success, String message})> deleteType(int id) => _delete('types/$id');
  Future<bool> toggleType(int id) => _toggle('types/$id/toggle');

  // ── Categories ────────────────────────────────────────────────────────────

  Future<({List<MasterMedicineCategory> items, int total, int lastPage})?> getCategories({String? search, int page = 1}) =>
      _list('categories', MasterMedicineCategory.fromJson, query: {if (search != null) 'search': search, 'page': '$page'});

  Future<({bool success, String message})> storeCategory(String name) => _post('categories', {'name': name});
  Future<({bool success, String message})> updateCategory(int id, String name) => _put('categories/$id', {'name': name});
  Future<({bool success, String message})> deleteCategory(int id) => _delete('categories/$id');
  Future<bool> toggleCategory(int id) => _toggle('categories/$id/toggle');

  // ── Routes ────────────────────────────────────────────────────────────────

  Future<({List<MasterMedicineRoute> items, int total, int lastPage})?> getRoutes({String? search, int page = 1}) =>
      _list('routes', MasterMedicineRoute.fromJson, query: {if (search != null) 'search': search, 'page': '$page'});

  Future<({bool success, String message})> storeRoute(String name) => _post('routes', {'name': name});
  Future<({bool success, String message})> updateRoute(int id, String name) => _put('routes/$id', {'name': name});
  Future<({bool success, String message})> deleteRoute(int id) => _delete('routes/$id');
  Future<bool> toggleRoute(int id) => _toggle('routes/$id/toggle');

  // ── Medicines ─────────────────────────────────────────────────────────────

  Future<({List<MasterMedicine> items, int total, int lastPage})?> getMedicines({String? search, int? typeId, int page = 1}) =>
      _list('medicines', MasterMedicine.fromJson, query: {if (search != null) 'search': search, if (typeId != null) 'type_id': '$typeId', 'page': '$page'});

  Future<({bool success, String message})> storeMedicine(Map<String, dynamic> data) => _post('medicines', data);
  Future<({bool success, String message})> updateMedicine(int id, Map<String, dynamic> data) => _put('medicines/$id', data);
  Future<({bool success, String message})> deleteMedicine(int id) => _delete('medicines/$id');
  Future<bool> toggleMedicine(int id) => _toggle('medicines/$id/toggle');
}
