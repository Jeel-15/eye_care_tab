import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/platform_payment_models.dart';
import 'platform_auth_service.dart';

class PlatformPaymentService with PlatformAuthenticatedService {
  PlatformPaymentService._();
  static final PlatformPaymentService instance = PlatformPaymentService._();

  final String _base = '${AppConfig.platformApiUrl}/payments';

  Future<PlatformPaymentListResult?> getPayments({
    String? status,
    String? method,
    String? from,
    String? to,
    int page = 1,
  }) async {
    try {
      final params = <String, String>{'page': '$page'};
      if (status != null && status.isNotEmpty) params['status'] = status;
      if (method != null && method.isNotEmpty) params['method'] = method;
      if (from   != null && from.isNotEmpty)   params['from']   = from;
      if (to     != null && to.isNotEmpty)     params['to']     = to;

      final uri = Uri.parse(_base).replace(queryParameters: params);
      final response = await http.get(uri, headers: await headers).timeout(AppConfig.requestTimeout);

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        if (body['success'] == true) {
          final data = body['data'] as Map<String, dynamic>;
          final meta = data['meta'] as Map<String, dynamic>;
          return PlatformPaymentListResult(
            payments: (data['payments'] as List)
                .map((e) => PlatformPayment.fromJson(e as Map<String, dynamic>))
                .toList(),
            stats:    PlatformPaymentStats.fromJson(data['stats'] as Map<String, dynamic>),
            total:    meta['total']     as int,
            lastPage: meta['last_page'] as int,
          );
        }
      }
    } catch (e) {
      debugPrint('[PlatformPayment] list ERROR: $e');
    }
    return null;
  }

  Future<List<TenantOption>> getTenantOptions() async {
    try {
      final response = await http
          .get(Uri.parse('$_base/tenant-options'), headers: await headers)
          .timeout(AppConfig.requestTimeout);
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        if (body['success'] == true) {
          return (body['data'] as List)
              .map((e) => TenantOption.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }
    } catch (e) {
      debugPrint('[PlatformPayment] tenantOptions ERROR: $e');
    }
    return [];
  }

  Future<({bool success, String message})> storeOffline(Map<String, dynamic> data) async {
    try {
      final response = await http
          .post(Uri.parse('$_base/offline'), headers: await headers, body: jsonEncode(data))
          .timeout(AppConfig.requestTimeout);
      final parsed = jsonDecode(response.body) as Map<String, dynamic>;
      return (success: parsed['success'] as bool? ?? false, message: parsed['message'] as String? ?? '');
    } catch (e) {
      debugPrint('[PlatformPayment] storeOffline ERROR: $e');
      return (success: false, message: 'Network error.');
    }
  }

  Future<Uint8List?> getInvoiceBytes(int id) async {
    try {
      final response = await http
          .get(Uri.parse('$_base/$id/invoice'), headers: await headers)
          .timeout(const Duration(seconds: 60));
      if (response.statusCode == 200) return response.bodyBytes;
    } catch (e) {
      debugPrint('[PlatformPayment] invoice ERROR: $e');
    }
    return null;
  }
}
