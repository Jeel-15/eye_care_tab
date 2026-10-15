import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import '../config/app_config.dart';
import '../models/subscription_billing_models.dart';
import 'base_service.dart';

/// Web pull parity (2026-09-29) — `SubscriptionApiController`, VIEW-only
/// mirror of `hospital.subscription.index`'s Plan History table + Invoice
/// download. See WEB_VIEW_BUTTONS_PARITY_AUDIT.md finding #1.
class SubscriptionBillingService with AuthenticatedService {
  SubscriptionBillingService._();
  static final SubscriptionBillingService instance = SubscriptionBillingService._();

  String get _base => AppConfig.hospitalApiUrl;

  Future<SubscriptionBillingData> fetch() async {
    final res = await http.get(Uri.parse('$_base/subscription'), headers: await headers).timeout(AppConfig.requestTimeout);
    final body = parseApiResponse(res);
    return SubscriptionBillingData.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<void> downloadInvoice(int paymentId) async {
    final uri = Uri.parse('$_base/subscription/invoice/$paymentId');
    await _downloadAndOpen(uri, 'Invoice_$paymentId');
  }

  // Same download-bytes-to-disk-then-open pattern as OtDischargeService —
  // these print/PDF endpoints require the Bearer auth header, so a plain
  // url_launcher can't fetch them directly.
  Future<void> _downloadAndOpen(Uri uri, String filenameBase) async {
    final req = http.Request('GET', uri);
    (await headers).forEach((k, v) => req.headers[k] = v);

    final client = http.Client();
    try {
      final streamedRes = await client.send(req).timeout(const Duration(seconds: 120));
      syncPermissionsVersion(streamedRes.headers, statusCode: streamedRes.statusCode);
      if (streamedRes.statusCode != 200) {
        throw Exception('Failed to load invoice (${streamedRes.statusCode})');
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
