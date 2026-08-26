import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/ot_inventory_models.dart';
import 'base_service.dart';

/// Round 3.5 correction — `ot_types` CRUD via `/masters/ot-type`
/// (`master.ot_types`). `OtSurgeryTypeService.fetchOtTypes()` already reads
/// this same table read-only (`masters/ot-types-list`) for the Surgery
/// Types picker; this is the actual management screen for it.
class OtTypeMasterService with AuthenticatedService {
  OtTypeMasterService._();
  static final OtTypeMasterService instance = OtTypeMasterService._();

  String get _base => AppConfig.hospitalApiUrl;

  Map<String, dynamic> _parse(http.Response res) => parseApiResponse(res);

  Future<List<OtTypeMasterItem>> fetchAll() async {
    final res = await http.get(Uri.parse('$_base/masters/ot-type'), headers: await headers).timeout(AppConfig.requestTimeout);
    final body = _parse(res);
    return (body['data'] as List? ?? []).map((e) => OtTypeMasterItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<OtTypeMasterItem> create(String name) async {
    final res = await http
        .post(Uri.parse('$_base/masters/ot-type'), headers: await headers, body: jsonEncode({'name': name}))
        .timeout(AppConfig.requestTimeout);
    final body = _parse(res);
    return OtTypeMasterItem.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<OtTypeMasterItem> update(int id, String name) async {
    final res = await http
        .put(Uri.parse('$_base/masters/ot-type/$id'), headers: await headers, body: jsonEncode({'name': name}))
        .timeout(AppConfig.requestTimeout);
    final body = _parse(res);
    return OtTypeMasterItem.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<void> delete(int id) async {
    final res = await http.delete(Uri.parse('$_base/masters/ot-type/$id'), headers: await headers).timeout(AppConfig.requestTimeout);
    _parse(res);
  }
}
