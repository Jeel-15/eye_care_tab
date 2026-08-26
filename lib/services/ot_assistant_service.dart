import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/ot_assistant_models.dart';
import '../models/ot_booking_models.dart';
import 'base_service.dart';

/// Round 3 Phase 4 — `OtAssistantApiController`. `fetchBookings()` returns
/// only the ready-for-surgery queue — the web's lens workflow UI is hidden
/// by design (lens data is captured during counselling), there is no
/// separate ready-for-lens queue. Web's lens-record route also has no UI
/// entry point of its own, so this app doesn't build one either (removed
/// 2026-08-07 — see OT_SURGERY_RECORD_WEB_PARITY_FIX_PLAN.md).
class OtAssistantService with AuthenticatedService {
  OtAssistantService._();
  static final OtAssistantService instance = OtAssistantService._();

  String get _base => AppConfig.hospitalApiUrl;

  Map<String, dynamic> _parse(http.Response res) => parseApiResponse(res);

  Future<({List<OtBookingSummary> items, OtPaginationMeta meta})> fetchBookings({int page = 1, int perPage = 25}) async {
    final uri = Uri.parse('$_base/ot/assistant/bookings').replace(queryParameters: {'page': '$page', 'per_page': '$perPage'});
    final res = await http.get(uri, headers: await headers).timeout(AppConfig.requestTimeout);
    final body = _parse(res);
    final data = body['data'] as Map<String, dynamic>;
    final items = (data['data'] as List? ?? []).map((e) => OtBookingSummary.fromJson(e as Map<String, dynamic>)).toList();
    return (items: items, meta: OtPaginationMeta.fromJson(data));
  }

  Future<OtSurgeryFormData> fetchSurgeryFormData(int bookingId) async {
    final res = await http.get(Uri.parse('$_base/ot/bookings/$bookingId/surgery-form-data'), headers: await headers).timeout(AppConfig.requestTimeout);
    final body = _parse(res);
    return OtSurgeryFormData.fromJson(body['data'] as Map<String, dynamic>);
  }

  /// Web parity (2026-08-07): the pre-surgery verification checklist is no
  /// longer collected client-side — the backend auto-verifies all 4 items
  /// atomically with the surgery record, matching web exactly. See
  /// OT_SURGERY_RECORD_WEB_PARITY_FIX_PLAN.md TASK 1.1/2.1.
  Future<void> storeSurgery(int bookingId, {
    required String surgeryDate,
    required String surgeryName,
    String? otRoom,
    required String eyeOperated,
    String? startTime,
    String? endTime,
    required String complicationStatus,
    String? complicationNotes,
    String? bloodLoss,
    int? medicineGroupId,
    List<OtSurgeryMedicineLine> otMedicines = const [],
    String? lensCategory,
    String? lensCompany,
    String? lensModel,
    String? lensType,
    double? estimatedPower,
    double? lensCost,
  }) async {
    final res = await http
        .post(
          Uri.parse('$_base/ot/bookings/$bookingId/surgery'),
          headers: await headers,
          body: jsonEncode({
            'surgery_date': surgeryDate,
            'surgery_name': surgeryName,
            'ot_room': otRoom,
            'eye_operated': eyeOperated,
            'start_time': startTime,
            'end_time': endTime,
            'complication_status': complicationStatus,
            'complication_notes': complicationNotes,
            'blood_loss': bloodLoss,
            'medicine_group_id': medicineGroupId,
            'ot_medicines': otMedicines.map((m) => m.toJson()).toList(),
            'lens_category': lensCategory,
            'lens_company': lensCompany,
            'lens_model': lensModel,
            'lens_type': lensType,
            'estimated_power': estimatedPower,
            'lens_cost': lensCost,
          }),
        )
        .timeout(AppConfig.requestTimeout);
    _parse(res);
  }
}
