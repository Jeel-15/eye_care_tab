import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../utils/json_parse.dart';
import 'base_service.dart';

class DurationItem {
  final int id;
  final String duration;

  const DurationItem({required this.id, required this.duration});

  factory DurationItem.fromJson(Map<String, dynamic> j) => DurationItem(
        id: jsonInt(j['id']),
        duration: j['duration'] as String? ?? '',
      );
}

class DurationService with AuthenticatedService {
  DurationService._();
  static final DurationService instance = DurationService._();

  String get _base => AppConfig.hospitalApiUrl;

  Map<String, dynamic> _parse(http.Response res) => parseApiResponse(res);

  Future<List<DurationItem>> fetchAll() async {
    final res = await http
        .get(Uri.parse('$_base/masters/durations-crud'), headers: await headers)
        .timeout(AppConfig.requestTimeout);
    final body = _parse(res);
    return (body['data'] as List? ?? [])
        .map((e) => DurationItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<DurationItem> create(String duration) async {
    final res = await http
        .post(
          Uri.parse('$_base/masters/durations-crud'),
          headers: await headers,
          body: jsonEncode({'duration': duration}),
        )
        .timeout(AppConfig.requestTimeout);
    final body = _parse(res);
    return DurationItem.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<DurationItem> update(int id, String duration) async {
    final res = await http
        .put(
          Uri.parse('$_base/masters/durations-crud/$id'),
          headers: await headers,
          body: jsonEncode({'duration': duration}),
        )
        .timeout(AppConfig.requestTimeout);
    final body = _parse(res);
    return DurationItem.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<void> delete(int id) async {
    final res = await http
        .delete(Uri.parse('$_base/masters/durations-crud/$id'), headers: await headers)
        .timeout(AppConfig.requestTimeout);
    _parse(res);
  }
}
