import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import '../config/app_config.dart';
import '../models/report_models.dart';
import 'base_service.dart';

class ReportService with AuthenticatedService {
  ReportService._();
  static final ReportService instance = ReportService._();

  String get _base => AppConfig.hospitalApiUrl;

  Future<ReportResult> fetchReport(
    ReportFilter filter, {
    int page = 1,
  }) async {
    final params = filter.toQueryParams(page: page);
    final uri = Uri.parse('$_base/reports').replace(queryParameters: params);
    final res = await http.get(uri, headers: await headers);
    return ReportResult.fromJson(parseApiResponse(res));
  }

  Future<ReportFilterOptions> fetchFilterData() async {
    final uri = Uri.parse('$_base/reports/filter-data');
    final res = await http.get(uri, headers: await headers);
    final body = parseApiResponse(res);
    return ReportFilterOptions.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<ReportChannelCounts> fetchChannelCounts(ReportFilter filter) async {
    final params = filter.toQueryParams()..remove('page');
    final uri = Uri.parse('$_base/reports/channel-counts').replace(queryParameters: params);
    final res = await http.get(uri, headers: await headers);
    final body = parseApiResponse(res);
    return ReportChannelCounts.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<ReportChannelResult> fetchChannel(
    String channel,
    ReportFilter filter, {
    int page = 1,
  }) async {
    final params = filter.toQueryParams(page: page);
    final uri = Uri.parse('$_base/reports/channel/$channel').replace(queryParameters: params);
    final res = await http.get(uri, headers: await headers);
    final body = parseApiResponse(res);
    return ReportChannelResult.fromJson(body['data'] as Map<String, dynamic>);
  }

  /// Downloads the export file and opens it immediately with the system viewer.
  /// Returns the saved file path.
  Future<String> downloadAndOpenExport({
    required String format, // 'excel' | 'pdf'
    required ReportFilter filter,
  }) async {
    final endpoint = format == 'excel' ? 'export/excel' : 'export/pdf';
    final params = filter.toQueryParams();
    final uri = Uri.parse('$_base/reports/$endpoint').replace(queryParameters: params);

    final req = http.Request('GET', uri);
    (await headers).forEach((k, v) => req.headers[k] = v);

    final client = http.Client();
    try {
      final streamedRes = await client.send(req).timeout(const Duration(seconds: 120));
      if (streamedRes.statusCode != 200) {
        throw Exception('Export failed (${streamedRes.statusCode})');
      }

      final bytes = await streamedRes.stream.toBytes();
      final ext = format == 'excel' ? 'xlsx' : 'pdf';
      final ts = DateTime.now().millisecondsSinceEpoch;

      // Prefer external storage so the file is accessible from the file manager
      Directory dir;
      if (Platform.isAndroid) {
        dir = (await getExternalStorageDirectory()) ??
            await getApplicationDocumentsDirectory();
      } else {
        dir = await getApplicationDocumentsDirectory();
      }

      final filename = 'Patient_Report_$ts.$ext';
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(bytes);

      // Open immediately with the system viewer
      await OpenFilex.open(file.path);

      return file.path;
    } finally {
      client.close();
    }
  }
}
