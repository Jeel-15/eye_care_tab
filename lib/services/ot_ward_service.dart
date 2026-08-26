import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/ot_booking_models.dart';
import '../models/ot_ward_models.dart';
import 'base_service.dart';

/// Round 3 Phase 3 — `OtWardApiController`. Read (`ot.ward.entry`) and
/// write (`ot.preop.entry` for vitals, `ot.dilation.track` for eye-drops)
/// are gated by different permissions — see build PRD §7 gotcha, screens
/// must gate actions individually, not the whole screen.
class OtWardService with AuthenticatedService {
  OtWardService._();
  static final OtWardService instance = OtWardService._();

  String get _base => AppConfig.hospitalApiUrl;

  Map<String, dynamic> _parse(http.Response res) => parseApiResponse(res);

  Future<OtVitalsItem?> fetchVitals(int bookingId) async {
    final res = await http.get(Uri.parse('$_base/ot/bookings/$bookingId/vitals'), headers: await headers).timeout(AppConfig.requestTimeout);
    final body = _parse(res);
    final latest = (body['data'] as Map<String, dynamic>)['latest'];
    return latest != null ? OtVitalsItem.fromJson(latest as Map<String, dynamic>) : null;
  }

  /// Returns the booking's new `ot_status` (auto-advances
  /// `payment_verified` → `in_ward` on first save).
  Future<String> storeVitals(int bookingId, Map<String, dynamic> body) async {
    final res = await http
        .post(Uri.parse('$_base/ot/bookings/$bookingId/vitals'), headers: await headers, body: jsonEncode(body))
        .timeout(AppConfig.requestTimeout);
    final parsed = _parse(res);
    return (parsed['data'] as Map<String, dynamic>)['ot_status'] as String? ?? '';
  }

  Future<List<OtEyeDropEntry>> fetchEyeDrops(int bookingId) async {
    final res = await http.get(Uri.parse('$_base/ot/bookings/$bookingId/eye-drops'), headers: await headers).timeout(AppConfig.requestTimeout);
    final body = _parse(res);
    final list = (body['data'] as Map<String, dynamic>)['eye_drops'] as List? ?? [];
    return list.map((e) => OtEyeDropEntry.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<OtEyeDropEntry> addEyeDrop(int bookingId, {required String medicineName, required String eye, required int doseNumber, String? administeredAt, String? remarks}) async {
    final res = await http
        .post(
          Uri.parse('$_base/ot/bookings/$bookingId/eye-drops'),
          headers: await headers,
          body: jsonEncode({
            'medicine_name': medicineName,
            'eye': eye,
            'dose_number': doseNumber,
            if (administeredAt != null) 'administered_at': administeredAt,
            'remarks': remarks,
          }),
        )
        .timeout(AppConfig.requestTimeout);
    final body = _parse(res);
    return OtEyeDropEntry.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<OtVerificationHeader> fetchVerificationHeader(int bookingId) async {
    final res = await http.get(Uri.parse('$_base/ot/bookings/$bookingId/verification-header'), headers: await headers).timeout(AppConfig.requestTimeout);
    final body = _parse(res);
    return OtVerificationHeader.fromJson(body['data'] as Map<String, dynamic>);
  }

  /// `GET ot/ward/bookings` — the Ward Entry Queue: bookings with
  /// `ot_status` in payment_verified/in_ward/ready. See
  /// OT_WEB_PARITY_FIX_PRD.md §4 (previously no queue endpoint existed).
  Future<({List<OtBookingSummary> items, OtPaginationMeta meta})> fetchBookings({int page = 1, int perPage = 25}) async {
    final uri = Uri.parse('$_base/ot/ward/bookings').replace(queryParameters: {'page': '$page', 'per_page': '$perPage'});
    final res = await http.get(uri, headers: await headers).timeout(AppConfig.requestTimeout);
    final body = _parse(res);
    final data = body['data'] as Map<String, dynamic>;
    final items = (data['data'] as List? ?? []).map((e) => OtBookingSummary.fromJson(e as Map<String, dynamic>)).toList();
    return (items: items, meta: OtPaginationMeta.fromJson(data));
  }

  /// `POST ot/bookings/{id}/mark-ready` — the queue row's/Card 4's "Send to
  /// OT Assistant" action. Returns the booking's new `ot_status` (`ready`).
  /// Throws (via `parseApiResponse`) with the backend's exact validation
  /// message on failure — not payment-verified/in-ward, pre-op not ready,
  /// or no OT Assistant assigned yet.
  Future<String> markReady(int bookingId) async {
    final res = await http.post(Uri.parse('$_base/ot/bookings/$bookingId/mark-ready'), headers: await headers).timeout(AppConfig.requestTimeout);
    final body = _parse(res);
    return (body['data'] as Map<String, dynamic>)['ot_status'] as String? ?? '';
  }
}
