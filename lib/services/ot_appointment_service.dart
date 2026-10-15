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

  // Web pull 2026-10-07 — the 16-stage status filter was fully replaced by a
  // simple Booked/Completed tab system (new `ot_appointment` role's own
  // desk). `tab` is now the server-side filter itself (`canWalkIn()` vs
  // `converted_patient_id` truthy), not a client-side status match.
  Future<({List<OtAppointmentItem> items, OtPaginationMeta meta, String activeTab, int bookedCount, int completedCount, String fromDate, String toDate})> list({
    String tab = 'booked',
    String? fromDate,
    String? toDate,
    String? search,
    int page = 1,
    int perPage = 25,
  }) async {
    final qp = {
      'tab': tab,
      'page': '$page',
      'per_page': '$perPage',
      if (fromDate != null && fromDate.isNotEmpty) 'from_date': fromDate,
      if (toDate != null && toDate.isNotEmpty) 'to_date': toDate,
      if (search != null && search.isNotEmpty) 'search': search,
    };
    final uri = Uri.parse('$_base/ot/appointments').replace(queryParameters: qp);
    final res = await http.get(uri, headers: await headers).timeout(AppConfig.requestTimeout);
    final body = _parse(res);
    final data = body['data'] as Map<String, dynamic>;
    final items = (data['data'] as List? ?? []).map((e) => OtAppointmentItem.fromJson(e as Map<String, dynamic>)).toList();
    final meta = body['meta'] as Map<String, dynamic>? ?? const {};
    return (
      items: items,
      meta: OtPaginationMeta.fromJson(data),
      activeTab: meta['active_tab'] as String? ?? tab,
      bookedCount: (meta['booked_count'] as num?)?.toInt() ?? 0,
      completedCount: (meta['completed_count'] as num?)?.toInt() ?? 0,
      fromDate: meta['from_date'] as String? ?? '',
      toDate: meta['to_date'] as String? ?? '',
    );
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

  Future<OtAppointmentSearchResult> search(String q) async {
    final uri = Uri.parse('$_base/ot/appointments/search').replace(queryParameters: {'q': q});
    final res = await http.get(uri, headers: await headers).timeout(AppConfig.requestTimeout);
    final body = _parse(res);
    return OtAppointmentSearchResult.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<void> destroy(int id) async {
    final res = await http
        .delete(Uri.parse('$_base/ot/appointments/$id'), headers: await headers)
        .timeout(AppConfig.requestTimeout);
    _parse(res);
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
