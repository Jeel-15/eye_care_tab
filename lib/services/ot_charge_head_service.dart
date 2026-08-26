import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'base_service.dart';

class OtChargeHeadItem {
  final int id;
  final String chargeName;
  final double percentage;
  final bool isActive;

  const OtChargeHeadItem({
    required this.id,
    required this.chargeName,
    required this.percentage,
    required this.isActive,
  });

  factory OtChargeHeadItem.fromJson(Map<String, dynamic> j) =>
      OtChargeHeadItem(
        id: j['id'] as int,
        chargeName: j['charge_name'] as String? ?? '',
        percentage: (j['percentage'] as num?)?.toDouble() ?? 0.0,
        isActive: (j['is_active'] as bool?) ?? true,
      );
}

class OtChargeHeadService with AuthenticatedService {
  OtChargeHeadService._();
  static final OtChargeHeadService instance = OtChargeHeadService._();

  String get _base => AppConfig.hospitalApiUrl;

  Map<String, dynamic> _parse(http.Response res) => parseApiResponse(res);

  Future<List<OtChargeHeadItem>> fetchAll() async {
    final res = await http
        .get(Uri.parse('$_base/masters/ot-charge-heads'), headers: await headers)
        .timeout(AppConfig.requestTimeout);
    final body = _parse(res);
    return (body['data'] as List? ?? [])
        .map((e) => OtChargeHeadItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<OtChargeHeadItem> create(
      String chargeName, double percentage, bool isActive) async {
    final res = await http
        .post(
          Uri.parse('$_base/masters/ot-charge-heads'),
          headers: await headers,
          body: jsonEncode({
            'charge_name': chargeName,
            'percentage': percentage,
            'is_active': isActive,
          }),
        )
        .timeout(AppConfig.requestTimeout);
    final body = _parse(res);
    return OtChargeHeadItem.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<OtChargeHeadItem> update(
      int id, String chargeName, double percentage, bool isActive) async {
    final res = await http
        .put(
          Uri.parse('$_base/masters/ot-charge-heads/$id'),
          headers: await headers,
          body: jsonEncode({
            'charge_name': chargeName,
            'percentage': percentage,
            'is_active': isActive,
          }),
        )
        .timeout(AppConfig.requestTimeout);
    final body = _parse(res);
    return OtChargeHeadItem.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<void> delete(int id) async {
    final res = await http
        .delete(
            Uri.parse('$_base/masters/ot-charge-heads/$id'),
            headers: await headers)
        .timeout(AppConfig.requestTimeout);
    _parse(res);
  }
}
