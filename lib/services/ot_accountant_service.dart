import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/ot_accountant_models.dart';
import '../models/ot_booking_models.dart';
import 'base_service.dart';

/// Round 3 Phase 5 — `OtAccountantApiController`. `storePayment` is the
/// single call that both records payment AND (when it completes the
/// package amount) advances the booking to Ward — there is no separate
/// "verify payment" call, don't build one client-side.
class OtAccountantService with AuthenticatedService {
  OtAccountantService._();
  static final OtAccountantService instance = OtAccountantService._();

  String get _base => AppConfig.hospitalApiUrl;

  Map<String, dynamic> _parse(http.Response res) => parseApiResponse(res);

  /// `filter`: `today` (pending-payment queue), `completed` (payment done
  /// onward), or `refunds` (surgery_refused, awaiting/done full refund —
  /// web pull 2026-08-07, WEB_PULL_2026_08_07_APP_PARITY_AUDIT.md §4).
  Future<({List<OtBookingSummary> items, OtPaginationMeta meta, OtMoneySummary? moneySummary})> fetchBookings({String filter = 'today', int page = 1, int perPage = 25}) async {
    final uri = Uri.parse('$_base/ot/accountant/bookings').replace(queryParameters: {'filter': filter, 'page': '$page', 'per_page': '$perPage'});
    final res = await http.get(uri, headers: await headers).timeout(AppConfig.requestTimeout);
    final body = _parse(res);
    final data = body['data'] as Map<String, dynamic>;
    final items = (data['data'] as List? ?? []).map((e) => OtBookingSummary.fromJson(e as Map<String, dynamic>)).toList();
    final metaJson = body['meta'] as Map<String, dynamic>?;
    final moneySummaryJson = metaJson?['money_summary'] as Map<String, dynamic>?;
    return (
      items: items,
      meta: OtPaginationMeta.fromJson(data),
      moneySummary: moneySummaryJson != null ? OtMoneySummary.fromJson(moneySummaryJson) : null,
    );
  }

  Future<OtRefundFormData> fetchRefundFormData(int bookingId) async {
    final res = await http.get(Uri.parse('$_base/ot/bookings/$bookingId/refund-form-data'), headers: await headers).timeout(AppConfig.requestTimeout);
    final body = _parse(res);
    return OtRefundFormData.fromJson(body['data'] as Map<String, dynamic>);
  }

  /// Amount is deliberately not a parameter — the server always forces the
  /// full refundable balance, matching web exactly (no partial-refund UI
  /// exists). See WEB_PULL_2026_08_07_APP_PARITY_AUDIT.md §4.
  Future<OtRefundResult> storeRefund(int bookingId, {required String paymentMode, String? receiptNumber, String? reason}) async {
    final res = await http
        .post(
          Uri.parse('$_base/ot/bookings/$bookingId/refunds'),
          headers: await headers,
          body: jsonEncode({
            'payment_mode': paymentMode,
            if (receiptNumber != null && receiptNumber.isNotEmpty) 'receipt_number': receiptNumber,
            if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
          }),
        )
        .timeout(AppConfig.requestTimeout);
    final body = _parse(res);
    return OtRefundResult.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<OtPaymentStatus> fetchPaymentStatus(int bookingId) async {
    final res = await http.get(Uri.parse('$_base/ot/bookings/$bookingId/payment-status'), headers: await headers).timeout(AppConfig.requestTimeout);
    final body = _parse(res);
    return OtPaymentStatus.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<OtPaymentFormData> fetchPaymentFormData(int bookingId) async {
    final res = await http.get(Uri.parse('$_base/ot/bookings/$bookingId/payment-form-data'), headers: await headers).timeout(AppConfig.requestTimeout);
    final body = _parse(res);
    return OtPaymentFormData.fromJson(body['data'] as Map<String, dynamic>);
  }

  /// `package_amount` is deliberately NOT sent — web pull 2026-08-07 removed
  /// partial payments entirely; the server always forces the full remaining
  /// balance regardless of what's sent. See
  /// WEB_PULL_2026_08_07_APP_PARITY_AUDIT.md §2.
  Future<OtPaymentResult> storePayment(int bookingId, {String? receiptNumber, required String paymentMode}) async {
    final res = await http
        .post(
          Uri.parse('$_base/ot/bookings/$bookingId/payments'),
          headers: await headers,
          body: jsonEncode({
            if (receiptNumber != null && receiptNumber.isNotEmpty) 'receipt_number': receiptNumber,
            'payment_mode': paymentMode,
          }),
        )
        .timeout(AppConfig.requestTimeout);
    final body = _parse(res);
    return OtPaymentResult.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<OtPaymentReceipt> fetchReceipt(int paymentId) async {
    final res = await http.get(Uri.parse('$_base/ot/payments/$paymentId/receipt'), headers: await headers).timeout(AppConfig.requestTimeout);
    final body = _parse(res);
    return OtPaymentReceipt.fromJson(body['data'] as Map<String, dynamic>);
  }
}
