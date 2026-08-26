import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/platform_audit_log_models.dart';
import 'platform_auth_service.dart';

class PlatformAuditLogService with PlatformAuthenticatedService {
  PlatformAuditLogService._();
  static final PlatformAuditLogService instance = PlatformAuditLogService._();

  final String _base = '${AppConfig.platformApiUrl}/audit-logs';

  Future<PlatformAuditLogListResult?> getLogs({
    String? action,
    int? tenantId,
    String? from,
    String? to,
    int page = 1,
  }) async {
    try {
      final params = <String, String>{'page': '$page'};
      if (action   != null && action.isNotEmpty)       params['action']    = action;
      if (tenantId != null)                            params['tenant_id'] = '$tenantId';
      if (from     != null && from.isNotEmpty)         params['from']      = from;
      if (to       != null && to.isNotEmpty)           params['to']        = to;

      final uri      = Uri.parse(_base).replace(queryParameters: params);
      final response = await http.get(uri, headers: await headers).timeout(AppConfig.requestTimeout);

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        if (body['success'] == true) {
          final data = body['data'] as Map<String, dynamic>;
          final meta = data['meta'] as Map<String, dynamic>;
          return PlatformAuditLogListResult(
            logs: (data['logs'] as List)
                .map((e) => PlatformAuditLog.fromJson(e as Map<String, dynamic>))
                .toList(),
            tenants: (data['tenants'] as List)
                .map((e) => TenantFilterOption.fromJson(e as Map<String, dynamic>))
                .toList(),
            total:    meta['total']     as int,
            lastPage: meta['last_page'] as int,
          );
        }
      }
    } catch (e) {
      debugPrint('[PlatformAuditLog] getLogs ERROR: $e');
    }
    return null;
  }
}
