import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'base_service.dart';

// ── Model ─────────────────────────────────────────────────────────────────────

class SimpleMasterItem {
  final int id;
  final String value;
  final bool isFavourite;
  final bool isSeeded;

  const SimpleMasterItem({
    required this.id,
    required this.value,
    this.isFavourite = false,
    this.isSeeded = false,
  });

  factory SimpleMasterItem.fromJson(Map<String, dynamic> j) => SimpleMasterItem(
        id: j['id'] as int,
        value: j['value'] as String? ?? '',
        isFavourite: j['is_favourite'] as bool? ?? false,
        isSeeded: j['is_seeded'] as bool? ?? false,
      );

  SimpleMasterItem copyWith({String? value, bool? isFavourite}) => SimpleMasterItem(
        id: id,
        value: value ?? this.value,
        isFavourite: isFavourite ?? this.isFavourite,
        isSeeded: isSeeded,
      );
}

// ── Service ───────────────────────────────────────────────────────────────────

class SimpleMasterService with AuthenticatedService {
  SimpleMasterService._();
  static final SimpleMasterService instance = SimpleMasterService._();

  String get _base => AppConfig.hospitalApiUrl;


  Map<String, dynamic> _parse(http.Response res) => parseApiResponse(res);

  // ── CRUD ──────────────────────────────────────────────────────────────────

  /// [apiPath] — e.g. 'masters/detail/complaints'
  Future<List<SimpleMasterItem>> fetchAll(String apiPath) async {
    final res = await http
        .get(Uri.parse('$_base/$apiPath'), headers: await headers)
        .timeout(AppConfig.requestTimeout);
    final body = _parse(res);
    return (body['data'] as List? ?? [])
        .map((e) => SimpleMasterItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<SimpleMasterItem> create(
    String apiPath,
    String value, {
    bool isFavourite = false,
  }) async {
    final res = await http
        .post(
          Uri.parse('$_base/$apiPath'),
          headers: await headers,
          body: jsonEncode({'value': value, 'is_favourite': isFavourite}),
        )
        .timeout(AppConfig.requestTimeout);
    final body = _parse(res);
    return SimpleMasterItem.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<SimpleMasterItem> update(
    String apiPath,
    int id,
    String value, {
    bool isFavourite = false,
  }) async {
    final res = await http
        .put(
          Uri.parse('$_base/$apiPath/$id'),
          headers: await headers,
          body: jsonEncode({'value': value, 'is_favourite': isFavourite}),
        )
        .timeout(AppConfig.requestTimeout);
    final body = _parse(res);
    return SimpleMasterItem.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<void> delete(String apiPath, int id) async {
    final res = await http
        .delete(Uri.parse('$_base/$apiPath/$id'), headers: await headers)
        .timeout(AppConfig.requestTimeout);
    _parse(res);
  }

  Future<bool> toggleFavourite(String apiPath, int id) async {
    final res = await http
        .post(
          Uri.parse('$_base/$apiPath/$id/toggle-favourite'),
          headers: await headers,
        )
        .timeout(AppConfig.requestTimeout);
    final body = _parse(res);
    return (body['data'] as Map<String, dynamic>?)?['is_favourite'] as bool? ?? false;
  }
}
