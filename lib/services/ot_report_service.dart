import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import '../config/app_config.dart';
import '../models/ot_report_models.dart';
import 'base_service.dart';

/// Round 3 Phase 8 — `OtReportApiController`. Built last since it only
/// visualizes data every other phase produces.
class OtReportService with AuthenticatedService {
  OtReportService._();
  static final OtReportService instance = OtReportService._();

  String get _base => AppConfig.hospitalApiUrl;

  Map<String, dynamic> _parse(http.Response res) => parseApiResponse(res);

  Future<List<OtReportTypeGroup>> fetchReportTypes() async {
    final res = await http.get(Uri.parse('$_base/reports/ot'), headers: await headers).timeout(AppConfig.requestTimeout);
    final body = _parse(res);
    return parseOtReportGroups(body['data'] as Map<String, dynamic>);
  }

  Future<OtReportResult> fetchReport(String type, {String? from, String? to}) async {
    final qp = <String, String>{if (from != null) 'from': from, if (to != null) 'to': to};
    final uri = Uri.parse('$_base/reports/ot/$type').replace(queryParameters: qp.isEmpty ? null : qp);
    final res = await http.get(uri, headers: await headers).timeout(AppConfig.requestTimeout);
    final body = _parse(res);
    return OtReportResult.fromJson(body['data'] as Map<String, dynamic>);
  }

  /// Download+open pattern ported from `ReportService.downloadAndOpenExport`.
  Future<void> exportReport(String type, {required String format, String? from, String? to}) async {
    final path = format == 'pdf' ? 'reports/ot/$type/export-pdf' : 'reports/ot/$type/export';
    final qp = <String, String>{if (format == 'excel') 'format': 'excel', if (from != null) 'from': from, if (to != null) 'to': to};
    final uri = Uri.parse('$_base/$path').replace(queryParameters: qp.isEmpty ? null : qp);

    final req = http.Request('GET', uri);
    (await headers).forEach((k, v) => req.headers[k] = v);
    final client = http.Client();
    try {
      final streamedRes = await client.send(req).timeout(const Duration(seconds: 120));
      if (streamedRes.statusCode != 200) throw Exception('Export failed (${streamedRes.statusCode})');
      final bytes = await streamedRes.stream.toBytes();
      final ext = format == 'excel' ? 'xlsx' : 'pdf';
      final ts = DateTime.now().millisecondsSinceEpoch;
      Directory dir = Platform.isAndroid ? ((await getExternalStorageDirectory()) ?? await getApplicationDocumentsDirectory()) : await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/OT_${type}_$ts.$ext');
      await file.writeAsBytes(bytes);
      await OpenFilex.open(file.path);
    } finally {
      client.close();
    }
  }

  /// Downloads+opens the "Hospital Report" prescription drill-down PDF for
  /// one patient row (Phase 2's new `apiPrescriptionPdf` endpoint).
  Future<void> downloadPrescriptionPdf(int patientId) async {
    final uri = Uri.parse('$_base/reports/ot/prescription/$patientId/pdf');
    final req = http.Request('GET', uri);
    (await headers).forEach((k, v) => req.headers[k] = v);
    final client = http.Client();
    try {
      final streamedRes = await client.send(req).timeout(const Duration(seconds: 60));
      if (streamedRes.statusCode != 200) {
        throw Exception('Failed to load prescription (${streamedRes.statusCode})');
      }
      final bytes = await streamedRes.stream.toBytes();
      final ts = DateTime.now().millisecondsSinceEpoch;
      Directory dir = Platform.isAndroid ? ((await getExternalStorageDirectory()) ?? await getApplicationDocumentsDirectory()) : await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/Prescription_${patientId}_$ts.pdf');
      await file.writeAsBytes(bytes);
      await OpenFilex.open(file.path);
    } finally {
      client.close();
    }
  }
}
