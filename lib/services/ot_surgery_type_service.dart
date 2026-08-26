import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'base_service.dart';

class OtTypeOption {
  final int id;
  final String name;

  const OtTypeOption({required this.id, required this.name});

  factory OtTypeOption.fromJson(Map<String, dynamic> j) => OtTypeOption(
        id: j['id'] as int,
        name: j['name'] as String? ?? '',
      );
}

class OtSurgeryTypeItem {
  final int id;
  final int otTypeId;
  final String otTypeName;
  final String surgeryName;

  const OtSurgeryTypeItem({
    required this.id,
    required this.otTypeId,
    required this.otTypeName,
    required this.surgeryName,
  });

  factory OtSurgeryTypeItem.fromJson(Map<String, dynamic> j) =>
      OtSurgeryTypeItem(
        id: j['id'] as int,
        otTypeId: j['ot_type_id'] as int,
        otTypeName: j['ot_type_name'] as String? ?? '',
        surgeryName: j['surgery_name'] as String? ?? '',
      );
}

class OtSurgeryTypeService with AuthenticatedService {
  OtSurgeryTypeService._();
  static final OtSurgeryTypeService instance = OtSurgeryTypeService._();

  String get _base => AppConfig.hospitalApiUrl;

  Map<String, dynamic> _parse(http.Response res) => parseApiResponse(res);

  Future<List<OtSurgeryTypeItem>> fetchAll() async {
    final res = await http
        .get(Uri.parse('$_base/masters/ot-surgery-types'),
            headers: await headers)
        .timeout(AppConfig.requestTimeout);
    final body = _parse(res);
    return (body['data'] as List? ?? [])
        .map((e) => OtSurgeryTypeItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<OtTypeOption>> fetchOtTypes() async {
    final res = await http
        .get(Uri.parse('$_base/masters/ot-types-list'),
            headers: await headers)
        .timeout(AppConfig.requestTimeout);
    final body = _parse(res);
    return (body['data'] as List? ?? [])
        .map((e) => OtTypeOption.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<OtSurgeryTypeItem> create(int otTypeId, String surgeryName) async {
    final res = await http
        .post(
          Uri.parse('$_base/masters/ot-surgery-types'),
          headers: await headers,
          body: jsonEncode({
            'ot_type_id': otTypeId,
            'surgery_name': surgeryName,
          }),
        )
        .timeout(AppConfig.requestTimeout);
    final body = _parse(res);
    return OtSurgeryTypeItem.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<OtSurgeryTypeItem> update(
      int id, int otTypeId, String surgeryName) async {
    final res = await http
        .put(
          Uri.parse('$_base/masters/ot-surgery-types/$id'),
          headers: await headers,
          body: jsonEncode({
            'ot_type_id': otTypeId,
            'surgery_name': surgeryName,
          }),
        )
        .timeout(AppConfig.requestTimeout);
    final body = _parse(res);
    return OtSurgeryTypeItem.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<void> delete(int id) async {
    final res = await http
        .delete(Uri.parse('$_base/masters/ot-surgery-types/$id'),
            headers: await headers)
        .timeout(AppConfig.requestTimeout);
    _parse(res);
  }
}
