import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/ot_booking_models.dart';
import 'base_service.dart';

/// `DashboardDrillDownApiController::doctorOtIndex()`/`doctorOtAssignAssistant()`/
/// `doctorOtRefuseSurgery()` — a doctor's own OT patient drill-down, net new
/// (web pull 2026-08-07). See WEB_PULL_2026_08_07_APP_PARITY_AUDIT.md §5.
class DoctorOtListService with AuthenticatedService {
  DoctorOtListService._();
  static final DoctorOtListService instance = DoctorOtListService._();

  String get _base => AppConfig.hospitalApiUrl;

  Map<String, dynamic> _parse(http.Response res) => parseApiResponse(res);

  Future<({List<OtBookingSummary> items, OtPaginationMeta meta, List<OtNamedRef> otAssistants})> fetchBookings({
    String? startDate,
    String? endDate,
    int? doctorId,
    int page = 1,
    int perPage = 25,
  }) async {
    final params = <String, String>{'page': '$page', 'per_page': '$perPage'};
    if (startDate != null) params['start_date'] = startDate;
    if (endDate != null) params['end_date'] = endDate;
    if (doctorId != null) params['doctor_id'] = '$doctorId';
    final uri = Uri.parse('$_base/dashboard/doctor-ot').replace(queryParameters: params);
    final res = await http.get(uri, headers: await headers).timeout(AppConfig.requestTimeout);
    final body = _parse(res);
    final data = body['data'] as Map<String, dynamic>;
    final items = (data['data'] as List? ?? []).map((e) => OtBookingSummary.fromJson(e as Map<String, dynamic>)).toList();
    final meta = body['meta'] as Map<String, dynamic>? ?? {};
    final otAssistants = (meta['ot_assistants'] as List? ?? []).map((e) => OtNamedRef.fromJson(e as Map<String, dynamic>)).toList();
    return (items: items, meta: OtPaginationMeta.fromJson(data), otAssistants: otAssistants);
  }

  /// "Doctor agrees OT after consult" — assigns an OT Assistant and marks
  /// the booking Ready for OT in one call (same server-side effect as
  /// Ward's mark-ready + assistant assignment, just from the doctor side).
  Future<String> assignAssistant(int bookingId, {required int otAssistantId}) async {
    final res = await http
        .post(
          Uri.parse('$_base/dashboard/doctor-ot/$bookingId/assign-assistant'),
          headers: await headers,
          body: jsonEncode({'ot_assistant_id': otAssistantId}),
        )
        .timeout(AppConfig.requestTimeout);
    final body = _parse(res);
    return (body['data'] as Map<String, dynamic>)['ot_status'] as String? ?? '';
  }

  /// Patient refuses surgery → sent to Accounts for a full refund.
  Future<String> refuseSurgery(int bookingId) async {
    final res = await http.post(Uri.parse('$_base/dashboard/doctor-ot/$bookingId/refuse'), headers: await headers).timeout(AppConfig.requestTimeout);
    final body = _parse(res);
    return (body['data'] as Map<String, dynamic>)['ot_status'] as String? ?? '';
  }
}
