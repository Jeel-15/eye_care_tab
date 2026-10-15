import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
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

  /// `filter`: `queue` (pending-payment queue), `history` (payment
  /// verified onward, i.e. "Completed Payments" — date-ranged via
  /// [fromDate]/[toDate], both `Y-m-d`, only meaningful when
  /// `filter=history`), or `refunds` (surgery_refused, awaiting/done full
  /// refund — never date-filtered, web pull 2026-08-07,
  /// WEB_PULL_2026_08_07_APP_PARITY_AUDIT.md §4). `today`/`completed`
  /// aliases still accepted server-side but `queue`/`history` are the
  /// canonical values (web pull 2026-09-19 Queue/Refunds/All toggle,
  /// `FiltersOtDeskLists` trait).
  Future<
    ({
      List<OtBookingSummary> items,
      OtPaginationMeta meta,
      OtMoneySummary? moneySummary,
    })
  >
  fetchBookings({
    String filter = 'queue',
    String? fromDate,
    String? toDate,
    int page = 1,
    int perPage = 25,
  }) async {
    final uri = Uri.parse('$_base/ot/accountant/bookings').replace(
      queryParameters: {
        'filter': filter,
        if (fromDate != null) 'from_date': fromDate,
        if (toDate != null) 'to_date': toDate,
        'page': '$page',
        'per_page': '$perPage',
      },
    );
    final res = await http
        .get(uri, headers: await headers)
        .timeout(AppConfig.requestTimeout);
    final body = _parse(res);
    final data = body['data'] as Map<String, dynamic>;
    final items = (data['data'] as List? ?? [])
        .map((e) => OtBookingSummary.fromJson(e as Map<String, dynamic>))
        .toList();
    final metaJson = body['meta'] as Map<String, dynamic>?;
    final moneySummaryJson =
        metaJson?['money_summary'] as Map<String, dynamic>?;
    return (
      items: items,
      meta: OtPaginationMeta.fromJson(data),
      moneySummary: moneySummaryJson != null
          ? OtMoneySummary.fromJson(moneySummaryJson)
          : null,
    );
  }

  /// Collected vs refunded report. Omitting dates uses the hospital's today.
  Future<OtMoneyReport> fetchMoneyReport({
    String? startDate,
    String? endDate,
  }) async {
    final params = <String, String>{};
    if (startDate != null) params['start_date'] = startDate;
    if (endDate != null) params['end_date'] = endDate;
    final uri = Uri.parse(
      '$_base/ot/accountant/money',
    ).replace(queryParameters: params.isEmpty ? null : params);
    final res = await http
        .get(uri, headers: await headers)
        .timeout(AppConfig.requestTimeout);
    final body = _parse(res);
    return OtMoneyReport.fromJson(body['data'] as Map<String, dynamic>);
  }

  /// Web's OT Money Report page has two separate "Export" buttons
  /// ("Payments in range" / "Refunds in range"), both hitting
  /// `OtAccountantController::moneyExport` with a `section` param — this
  /// screen had the data but no export action at all until now. Same
  /// download-bytes-then-open pattern as `DashboardService.downloadCollectionExport`.
  Future<void> downloadMoneyExport({
    required String section,
    String? startDate,
    String? endDate,
  }) async {
    final params = <String, String>{'section': section};
    if (startDate != null) params['start_date'] = startDate;
    if (endDate != null) params['end_date'] = endDate;
    final uri = Uri.parse(
      '$_base/ot/accountant/money/export',
    ).replace(queryParameters: params);
    final req = http.Request('GET', uri);
    (await headers).forEach((k, v) => req.headers[k] = v);

    final client = http.Client();
    try {
      final streamedRes = await client
          .send(req)
          .timeout(const Duration(seconds: 120));
      if (streamedRes.statusCode != 200) {
        throw Exception('Export failed (${streamedRes.statusCode})');
      }
      final bytes = await streamedRes.stream.toBytes();
      final ts = DateTime.now().millisecondsSinceEpoch;

      Directory dir;
      if (Platform.isAndroid) {
        dir =
            (await getExternalStorageDirectory()) ??
            await getApplicationDocumentsDirectory();
      } else {
        dir = await getApplicationDocumentsDirectory();
      }

      final file = File('${dir.path}/ot_${section}_$ts.xlsx');
      await file.writeAsBytes(bytes);
      await OpenFilex.open(file.path);
    } finally {
      client.close();
    }
  }

  Future<OtRefundFormData> fetchRefundFormData(int bookingId) async {
    final res = await http
        .get(
          Uri.parse('$_base/ot/bookings/$bookingId/refund-form-data'),
          headers: await headers,
        )
        .timeout(AppConfig.requestTimeout);
    final body = _parse(res);
    return OtRefundFormData.fromJson(body['data'] as Map<String, dynamic>);
  }

  /// Amount is deliberately not a parameter — the server always forces the
  /// full refundable balance, matching web exactly (no partial-refund UI
  /// exists). See WEB_PULL_2026_08_07_APP_PARITY_AUDIT.md §4.
  Future<OtRefundResult> storeRefund(
    int bookingId, {
    required String paymentMode,
    String? receiptNumber,
    String? reason,
  }) async {
    final res = await http
        .post(
          Uri.parse('$_base/ot/bookings/$bookingId/refunds'),
          headers: await headers,
          body: jsonEncode({
            'payment_mode': paymentMode,
            if (receiptNumber != null && receiptNumber.isNotEmpty)
              'receipt_number': receiptNumber,
            if (reason != null && reason.trim().isNotEmpty)
              'reason': reason.trim(),
          }),
        )
        .timeout(AppConfig.requestTimeout);
    final body = _parse(res);
    return OtRefundResult.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<OtPaymentStatus> fetchPaymentStatus(int bookingId) async {
    final res = await http
        .get(
          Uri.parse('$_base/ot/bookings/$bookingId/payment-status'),
          headers: await headers,
        )
        .timeout(AppConfig.requestTimeout);
    final body = _parse(res);
    return OtPaymentStatus.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<OtPaymentFormData> fetchPaymentFormData(int bookingId) async {
    final res = await http
        .get(
          Uri.parse('$_base/ot/bookings/$bookingId/payment-form-data'),
          headers: await headers,
        )
        .timeout(AppConfig.requestTimeout);
    final body = _parse(res);
    return OtPaymentFormData.fromJson(body['data'] as Map<String, dynamic>);
  }

  /// `package_amount` is deliberately NOT sent — web pull 2026-08-07 removed
  /// partial payments entirely; the server always forces the full remaining
  /// balance regardless of what's sent. See
  /// WEB_PULL_2026_08_07_APP_PARITY_AUDIT.md §2.
  Future<OtPaymentResult> storePayment(
    int bookingId, {
    String? receiptNumber,
    required String paymentMode,
  }) async {
    final res = await http
        .post(
          Uri.parse('$_base/ot/bookings/$bookingId/payments'),
          headers: await headers,
          body: jsonEncode({
            if (receiptNumber != null && receiptNumber.isNotEmpty)
              'receipt_number': receiptNumber,
            'payment_mode': paymentMode,
          }),
        )
        .timeout(AppConfig.requestTimeout);
    final body = _parse(res);
    return OtPaymentResult.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<OtPaymentReceipt> fetchReceipt(int paymentId) async {
    final res = await http
        .get(
          Uri.parse('$_base/ot/payments/$paymentId/receipt'),
          headers: await headers,
        )
        .timeout(AppConfig.requestTimeout);
    final body = _parse(res);
    return OtPaymentReceipt.fromJson(body['data'] as Map<String, dynamic>);
  }
}
