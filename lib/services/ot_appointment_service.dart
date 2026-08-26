import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/ot_appointment_models.dart';
import '../models/ot_booking_models.dart';
import 'base_service.dart';

/// Round 3 Phase 2 — `OtAppointmentApiController`.
class OtAppointmentService with AuthenticatedService {
  OtAppointmentService._();
  static final OtAppointmentService instance = OtAppointmentService._();

  String get _base => AppConfig.hospitalApiUrl;

  Map<String, dynamic> _parse(http.Response res) => parseApiResponse(res);

  Future<({List<OtAppointmentItem> items, OtPaginationMeta meta})> list({
    String status = 'all',
    String? date,
    String? search,
    int page = 1,
    int perPage = 25,
  }) async {
    final qp = {
      'status': status,
      'page': '$page',
      'per_page': '$perPage',
      if (date != null && date.isNotEmpty) 'date': date,
      if (search != null && search.isNotEmpty) 'search': search,
    };
    final uri = Uri.parse('$_base/ot/appointments').replace(queryParameters: qp);
    final res = await http.get(uri, headers: await headers).timeout(AppConfig.requestTimeout);
    final body = _parse(res);
    final data = body['data'] as Map<String, dynamic>;
    final items = (data['data'] as List? ?? []).map((e) => OtAppointmentItem.fromJson(e as Map<String, dynamic>)).toList();
    return (items: items, meta: OtPaginationMeta.fromJson(data));
  }

  Future<OtAppointmentFormData> fetchFormData() async {
    final res = await http.get(Uri.parse('$_base/ot/appointments/form-data'), headers: await headers).timeout(AppConfig.requestTimeout);
    final body = _parse(res);
    return OtAppointmentFormData.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<OtAppointmentItem> create(Map<String, dynamic> body) async {
    final res = await http
        .post(Uri.parse('$_base/ot/appointments'), headers: await headers, body: jsonEncode(body))
        .timeout(AppConfig.requestTimeout);
    final parsed = _parse(res);
    return OtAppointmentItem.fromJson(parsed['data'] as Map<String, dynamic>);
  }

  Future<OtAppointmentItem> update(int id, Map<String, dynamic> body) async {
    final res = await http
        .put(Uri.parse('$_base/ot/appointments/$id'), headers: await headers, body: jsonEncode(body))
        .timeout(AppConfig.requestTimeout);
    final parsed = _parse(res);
    return OtAppointmentItem.fromJson(parsed['data'] as Map<String, dynamic>);
  }

  Future<String> confirm(int id) async {
    final res = await http.post(Uri.parse('$_base/ot/appointments/$id/confirm'), headers: await headers).timeout(AppConfig.requestTimeout);
    final body = _parse(res);
    return (body['data'] as Map<String, dynamic>)['status'] as String? ?? '';
  }

  Future<String> cancel(int id) async {
    final res = await http.post(Uri.parse('$_base/ot/appointments/$id/cancel'), headers: await headers).timeout(AppConfig.requestTimeout);
    final body = _parse(res);
    return (body['data'] as Map<String, dynamic>)['status'] as String? ?? '';
  }

  Future<OtAppointmentSearchResult> search(String q) async {
    final uri = Uri.parse('$_base/ot/appointments/search').replace(queryParameters: {'q': q});
    final res = await http.get(uri, headers: await headers).timeout(AppConfig.requestTimeout);
    final body = _parse(res);
    return OtAppointmentSearchResult.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<List<OtSlotAppointmentConflict>> slotAppointments({required String date, required String time, int? excludeId}) async {
    final qp = {'date': date, 'time': time, if (excludeId != null) 'exclude_id': '$excludeId'};
    final uri = Uri.parse('$_base/ot/appointments/slot-appointments').replace(queryParameters: qp);
    final res = await http.get(uri, headers: await headers).timeout(AppConfig.requestTimeout);
    final body = _parse(res);
    final data = body['data'] as Map<String, dynamic>;
    return (data['appointments'] as List? ?? []).map((e) => OtSlotAppointmentConflict.fromJson(e as Map<String, dynamic>)).toList();
  }
}
