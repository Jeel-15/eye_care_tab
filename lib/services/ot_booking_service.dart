import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/ot_booking_models.dart';
import 'base_service.dart';

/// Round 3.5's `OtBookingApiController` — the doctor's "Recommend Surgery"
/// handoff that creates/updates the `OtBooking` row, plus the OT receptionist
/// dashboard stats. See OT_WORKFLOW_MOBILE_TABLET_BUILD_PRD.md §13.1.
class OtBookingService with AuthenticatedService {
  OtBookingService._();
  static final OtBookingService instance = OtBookingService._();

  String get _base => AppConfig.hospitalApiUrl;

  Map<String, dynamic> _parse(http.Response res) => parseApiResponse(res);

  /// `POST /ot/recommend-surgery/{patientId}`.
  /// Calling this again while the patient's booking is still
  /// `surgery_recommended`/`booked` updates the existing booking rather
  /// than creating a duplicate — matches web behavior, nothing extra to
  /// handle client-side for that case.
  ///
  /// `surgery_date`/`slot_id` are deliberately NOT sent — web pull
  /// 2026-08-07 dropped both from this endpoint entirely (always null at
  /// recommend time now; assigned later by the counsellor/ward flow). See
  /// WEB_PULL_2026_08_07_APP_PARITY_AUDIT.md §1.
  Future<OtRecommendSurgeryResult> recommendSurgery({
    required int patientId,
    required String eye, // RE | LE | Both
    required int otSurgeryTypeId,
    String? diagnosisHint,
  }) async {
    final res = await http
        .post(
          Uri.parse('$_base/ot/recommend-surgery/$patientId'),
          headers: await headers,
          body: jsonEncode({
            'eye': eye,
            'ot_surgery_type_id': otSurgeryTypeId,
            if (diagnosisHint != null && diagnosisHint.trim().isNotEmpty) 'diagnosis_hint': diagnosisHint.trim(),
          }),
        )
        .timeout(AppConfig.requestTimeout);
    final body = _parse(res);
    return OtRecommendSurgeryResult.fromJson(body['data'] as Map<String, dynamic>);
  }

  /// `GET /dashboard/ot-receptionist` — today's OT count, pending
  /// counselling, ready-for-surgery. Powers the OT Home Dashboard's 3 KPI
  /// cards (OT_WEB_PARITY_FIX_PRD.md §8).
  Future<OtReceptionistDashboardStats> fetchReceptionistDashboard() async {
    final res = await http
        .get(Uri.parse('$_base/dashboard/ot-receptionist'), headers: await headers)
        .timeout(AppConfig.requestTimeout);
    final body = _parse(res);
    return OtReceptionistDashboardStats.fromJson(body['data'] as Map<String, dynamic>? ?? {});
  }
}
