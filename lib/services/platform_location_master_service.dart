import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/platform_location_master_models.dart';
import 'platform_auth_service.dart';

class PlatformLocationMasterService with PlatformAuthenticatedService {
  PlatformLocationMasterService._();
  static final instance = PlatformLocationMasterService._();

  String get _base => '${AppConfig.platformApiUrl}/location-master';

  Future<LocationDropdownData?> getDropdownData() async {
    try {
      final h = await headers;
      final r = await http.get(Uri.parse('$_base/dropdown-data'), headers: h);
      final body = jsonDecode(r.body);
      if (body['success'] != true) return null;
      final d = body['data'];
      return LocationDropdownData(
        countries: (d['countries'] as List).map((e) => MasterCountry.fromJson(e)).toList(),
        states:    (d['states']    as List).map((e) => MasterState.fromJson(e)).toList(),
        districts: (d['districts'] as List).map((e) => MasterDistrict.fromJson(e)).toList(),
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

  // ── Countries ─────────────────────────────────────────────────────────────

  Future<({List<MasterCountry> items, int total, int lastPage})?> getCountries({String? search, int page = 1}) =>
      _list('countries', MasterCountry.fromJson, query: {if (search != null) 'search': search, 'page': '$page'});

  Future<({bool success, String message})> storeCountry(String name, String timezone) =>
      _post('countries', {'name': name, 'default_timezone': timezone});

  Future<({bool success, String message})> updateCountry(int id, String name, String timezone) =>
      _put('countries/$id', {'name': name, 'default_timezone': timezone});

  Future<({bool success, String message})> deleteCountry(int id) => _delete('countries/$id');
  Future<bool> toggleCountry(int id) => _toggle('countries/$id/toggle');

  // ── States ────────────────────────────────────────────────────────────────

  Future<({List<MasterState> items, int total, int lastPage})?> getStates({int? countryId, String? search, int page = 1}) =>
      _list('states', MasterState.fromJson, query: {if (countryId != null) 'country_id': '$countryId', if (search != null) 'search': search, 'page': '$page'});

  Future<({bool success, String message})> storeState(int countryId, String name) =>
      _post('states', {'country_id': countryId, 'name': name});

  Future<({bool success, String message})> updateState(int id, int countryId, String name) =>
      _put('states/$id', {'country_id': countryId, 'name': name});

  Future<({bool success, String message})> deleteState(int id) => _delete('states/$id');
  Future<bool> toggleState(int id) => _toggle('states/$id/toggle');

  // ── Districts ─────────────────────────────────────────────────────────────

  Future<({List<MasterDistrict> items, int total, int lastPage})?> getDistricts({int? stateId, String? search, int page = 1}) =>
      _list('districts', MasterDistrict.fromJson, query: {if (stateId != null) 'state_id': '$stateId', if (search != null) 'search': search, 'page': '$page'});

  Future<({bool success, String message})> storeDistrict(int stateId, String name) =>
      _post('districts', {'state_id': stateId, 'name': name});

  Future<({bool success, String message})> updateDistrict(int id, int stateId, String name) =>
      _put('districts/$id', {'state_id': stateId, 'name': name});

  Future<({bool success, String message})> deleteDistrict(int id) => _delete('districts/$id');
  Future<bool> toggleDistrict(int id) => _toggle('districts/$id/toggle');

  // ── Cities ────────────────────────────────────────────────────────────────

  Future<({List<MasterCity> items, int total, int lastPage})?> getCities({int? stateId, int? districtId, String? search, int page = 1}) =>
      _list('cities', MasterCity.fromJson, query: {if (stateId != null) 'state_id': '$stateId', if (districtId != null) 'district_id': '$districtId', if (search != null) 'search': search, 'page': '$page'});

  Future<({bool success, String message})> storeCity({required int stateId, int? districtId, required String name}) =>
      _post('cities', {'state_id': stateId, if (districtId != null) 'district_id': districtId, 'name': name});

  Future<({bool success, String message})> updateCity(int id, {required int stateId, int? districtId, required String name}) =>
      _put('cities/$id', {'state_id': stateId, if (districtId != null) 'district_id': districtId, 'name': name});

  Future<({bool success, String message})> deleteCity(int id) => _delete('cities/$id');
  Future<bool> toggleCity(int id) => _toggle('cities/$id/toggle');
}
