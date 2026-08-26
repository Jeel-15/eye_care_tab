import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'base_service.dart';

class ReferrerItem {
  final int id;
  final String name;
  final String? contact;

  const ReferrerItem({required this.id, required this.name, this.contact});

  factory ReferrerItem.fromJson(Map<String, dynamic> j) => ReferrerItem(
        id: j['id'] as int,
        name: j['name'] as String? ?? '',
        contact: j['contact'] as String?,
      );
}

class ReferrerService with AuthenticatedService {
  ReferrerService._();
  static final ReferrerService instance = ReferrerService._();

  String get _base => AppConfig.hospitalApiUrl;

  Map<String, dynamic> _parse(http.Response res) => parseApiResponse(res);

  Future<List<ReferrerItem>> fetchAll() async {
    final res = await http
        .get(Uri.parse('$_base/masters/referrers-crud'), headers: await headers)
        .timeout(AppConfig.requestTimeout);
    final body = _parse(res);
    return (body['data'] as List? ?? [])
        .map((e) => ReferrerItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ReferrerItem> create(String name, String? contact) async {
    final res = await http
        .post(
          Uri.parse('$_base/masters/referrers-crud'),
          headers: await headers,
          body: jsonEncode({
            'name': name,
            if (contact != null && contact.isNotEmpty) 'contact': contact,
          }),
        )
        .timeout(AppConfig.requestTimeout);
    final body = _parse(res);
    return ReferrerItem.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<ReferrerItem> update(int id, String name, String? contact) async {
    final res = await http
        .put(
          Uri.parse('$_base/masters/referrers-crud/$id'),
          headers: await headers,
          body: jsonEncode({
            'name': name,
            'contact': (contact != null && contact.isNotEmpty) ? contact : null,
          }),
        )
        .timeout(AppConfig.requestTimeout);
    final body = _parse(res);
    return ReferrerItem.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<void> delete(int id) async {
    final res = await http
        .delete(
            Uri.parse('$_base/masters/referrers-crud/$id'),
            headers: await headers)
        .timeout(AppConfig.requestTimeout);
    _parse(res);
  }
}
