import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import '../config/app_config.dart';
import '../models/ot_booking_models.dart';
import '../models/ot_discharge_models.dart';
import 'base_service.dart';

/// Round 3 Phase 6 — `OtDischargeApiController`. `discharge-bundle` is a
/// JSON manifest of 8 PDF URLs, not a merged file — no server-side PDF
/// merge exists (see build PRD §10 gotcha). "Print All" fetches the
/// manifest and downloads/opens each document in sequence.
class OtDischargeService with AuthenticatedService {
  OtDischargeService._();
  static final OtDischargeService instance = OtDischargeService._();

  String get _base => AppConfig.hospitalApiUrl;

  Map<String, dynamic> _parse(http.Response res) => parseApiResponse(res);

  Future<({List<OtBookingSummary> items, OtPaginationMeta meta})> fetchBookings({int page = 1, int perPage = 25}) async {
    final uri = Uri.parse('$_base/ot/billing/bookings').replace(queryParameters: {'page': '$page', 'per_page': '$perPage'});
    final res = await http.get(uri, headers: await headers).timeout(AppConfig.requestTimeout);
    final body = _parse(res);
    final data = body['data'] as Map<String, dynamic>;
    final items = (data['data'] as List? ?? []).map((e) => OtBookingSummary.fromJson(e as Map<String, dynamic>)).toList();
    return (items: items, meta: OtPaginationMeta.fromJson(data));
  }

  Future<OtInvoiceGenerateResult> generateInvoice(int bookingId, {double? taxAmount, double? discount, String? followUpDate}) async {
    final res = await http
        .post(
          Uri.parse('$_base/ot/bookings/$bookingId/invoice/generate'),
          headers: await headers,
          body: jsonEncode({'tax_amount': taxAmount, 'discount': discount, if (followUpDate != null) 'follow_up_date': followUpDate}),
        )
        .timeout(AppConfig.requestTimeout);
    final body = _parse(res);
    return OtInvoiceGenerateResult.fromJson(body['data'] as Map<String, dynamic>);
  }

  /// `GET .../invoice` — null when no invoice has been generated yet for
  /// this booking (a normal state, not an error). See
  /// OT_DISCHARGE_INVOICES_WEB_PARITY_FIX_PLAN.md TASK 2.2.
  Future<OtInvoiceSummary?> fetchInvoiceDetail(int bookingId) async {
    final res = await http.get(Uri.parse('$_base/ot/bookings/$bookingId/invoice'), headers: await headers).timeout(AppConfig.requestTimeout);
    final body = _parse(res);
    final data = body['data'] as Map<String, dynamic>?;
    return data == null ? null : OtInvoiceSummary.fromJson(data);
  }

  Future<List<OtDischargeDocument>> fetchBundleManifest(int bookingId) async {
    final res = await http.get(Uri.parse('$_base/ot/bookings/$bookingId/print/discharge-bundle'), headers: await headers).timeout(AppConfig.requestTimeout);
    final body = _parse(res);
    return ((body['data'] as Map<String, dynamic>)['documents'] as List? ?? []).map((e) => OtDischargeDocument.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Downloads and opens one of the 8 print documents with the system
  /// viewer — same download/open pattern as `ReportService.
  /// downloadAndOpenExport`. [restDays] only applies to
  /// [OtDischargeDocType.certificate] (1-90, optional).
  Future<void> printDocument(int bookingId, OtDischargeDocType type, {int? restDays}) async {
    final qp = <String, String>{if (type == OtDischargeDocType.certificate && restDays != null) 'rest_days': '$restDays'};
    final uri = Uri.parse('$_base/ot/bookings/$bookingId/print/${type.path}').replace(queryParameters: qp.isEmpty ? null : qp);
    await _downloadAndOpen(uri, '${type.label.replaceAll(' ', '_')}_$bookingId');
  }

  /// Downloads one document from a `discharge-bundle` manifest entry — the
  /// manifest already supplies full, ready-to-use URLs (built server-side
  /// via Laravel's `route()` helper), no need to reconstruct them.
  Future<void> printFromManifestUrl(OtDischargeDocument doc) async {
    await _downloadAndOpen(Uri.parse(doc.downloadUrl), doc.label.replaceAll(' ', '_'));
  }

  Future<void> _downloadAndOpen(Uri uri, String filenameBase) async {
    final req = http.Request('GET', uri);
    (await headers).forEach((k, v) => req.headers[k] = v);

    final client = http.Client();
    try {
      final streamedRes = await client.send(req).timeout(const Duration(seconds: 120));
      if (streamedRes.statusCode != 200) {
        throw Exception('Failed to load document (${streamedRes.statusCode})');
      }
      final bytes = await streamedRes.stream.toBytes();
      final ts = DateTime.now().millisecondsSinceEpoch;

      Directory dir;
      if (Platform.isAndroid) {
        dir = (await getExternalStorageDirectory()) ?? await getApplicationDocumentsDirectory();
      } else {
        dir = await getApplicationDocumentsDirectory();
      }

      final file = File('${dir.path}/${filenameBase}_$ts.pdf');
      await file.writeAsBytes(bytes);
      await OpenFilex.open(file.path);
    } finally {
      client.close();
    }
  }
}
