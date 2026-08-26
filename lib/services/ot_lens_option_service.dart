import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/ot_inventory_models.dart';
import 'base_service.dart';

/// Round 3.5 correction — `ot_lens_options` master via its own correctly
/// permissioned route (`master.ot_inventory`). Before this, the app's
/// generic masters route (`masters/detail/lens-options`) reached the same
/// data under the wrong permission (`master.eye_exam`).
class OtLensOptionService with AuthenticatedService {
  OtLensOptionService._();
  static final OtLensOptionService instance = OtLensOptionService._();

  String get _base => AppConfig.hospitalApiUrl;

  Map<String, dynamic> _parse(http.Response res) => parseApiResponse(res);

  Future<List<OtLensOptionItem>> fetchAll() async {
    final res = await http.get(Uri.parse('$_base/masters/ot-lens-options'), headers: await headers).timeout(AppConfig.requestTimeout);
    final body = _parse(res);
    return (body['data'] as List? ?? []).map((e) => OtLensOptionItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<OtLensOptionItem> create(String name) async {
    final res = await http
        .post(Uri.parse('$_base/masters/ot-lens-options'), headers: await headers, body: jsonEncode({'name': name}))
        .timeout(AppConfig.requestTimeout);
    final body = _parse(res);
    return OtLensOptionItem.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<OtLensOptionItem> update(int id, String name) async {
    final res = await http
        .put(Uri.parse('$_base/masters/ot-lens-options/$id'), headers: await headers, body: jsonEncode({'name': name}))
        .timeout(AppConfig.requestTimeout);
    final body = _parse(res);
    return OtLensOptionItem.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<void> delete(int id) async {
    final res = await http.delete(Uri.parse('$_base/masters/ot-lens-options/$id'), headers: await headers).timeout(AppConfig.requestTimeout);
    _parse(res);
  }
}
