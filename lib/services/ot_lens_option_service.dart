import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/ot_inventory_models.dart';
import 'base_service.dart';

/// Round 3.5 correction — `ot_lens_options` master via its own correctly
/// permissioned route. Web add/edit includes `is_active` (Active checkbox).
class OtLensOptionService with AuthenticatedService {
  OtLensOptionService._();
  static final OtLensOptionService instance = OtLensOptionService._();

  String get _base => AppConfig.hospitalApiUrl;

  Map<String, dynamic> _parse(http.Response res) => parseApiResponse(res);

  Future<List<OtLensOptionItem>> fetchAll() async {
    final res = await http
        .get(Uri.parse('$_base/masters/ot-lens-options'), headers: await headers)
        .timeout(AppConfig.requestTimeout);
    final body = _parse(res);
    return (body['data'] as List? ?? [])
        .map((e) => OtLensOptionItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<OtLensOptionItem> create(String name, {bool isActive = true}) async {
    final res = await http
        .post(
          Uri.parse('$_base/masters/ot-lens-options'),
          headers: await headers,
          body: jsonEncode({'name': name, 'is_active': isActive}),
        )
        .timeout(AppConfig.requestTimeout);
    final body = _parse(res);
    return OtLensOptionItem.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<OtLensOptionItem> update(int id, String name, {required bool isActive}) async {
    final res = await http
        .put(
          Uri.parse('$_base/masters/ot-lens-options/$id'),
          headers: await headers,
          body: jsonEncode({'name': name, 'is_active': isActive}),
        )
        .timeout(AppConfig.requestTimeout);
    final body = _parse(res);
    return OtLensOptionItem.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<void> delete(int id) async {
    final res = await http
        .delete(Uri.parse('$_base/masters/ot-lens-options/$id'), headers: await headers)
        .timeout(AppConfig.requestTimeout);
    _parse(res);
  }
}
