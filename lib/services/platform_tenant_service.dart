import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/platform_tenant_models.dart';
import 'platform_auth_service.dart';

class PlatformTenantService with PlatformAuthenticatedService {
  PlatformTenantService._();
  static final PlatformTenantService instance = PlatformTenantService._();

  final String _base = '${AppConfig.platformApiUrl}/hospitals';

  // ── List ───────────────────────────────────────────────────────────────────

  Future<TenantListResult?> list({String? search, String? status, int page = 1}) async {
    try {
      final params = <String, String>{'page': '$page'};
      if (search != null && search.isNotEmpty) params['search'] = search;
      if (status != null && status.isNotEmpty) params['status'] = status;

      final uri      = Uri.parse(_base).replace(queryParameters: params);
      final response = await http.get(uri, headers: await headers).timeout(AppConfig.requestTimeout);

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        if (body['success'] == true) {
          final data = body['data'] as Map<String, dynamic>;
          final meta = data['meta'] as Map<String, dynamic>;
          return TenantListResult(
            hospitals: (data['hospitals'] as List)
                .map((e) => TenantSummary.fromJson(e as Map<String, dynamic>))
                .toList(),
            total:    meta['total']     as int,
            lastPage: meta['last_page'] as int,
          );
        }
      }
    } catch (e) {
      debugPrint('[PlatformTenant] list ERROR: $e');
    }
    return null;
  }

  // ── Detail ─────────────────────────────────────────────────────────────────

  Future<TenantDetail?> getDetail(int id) async {
    try {
      final response = await http
          .get(Uri.parse('$_base/$id'), headers: await headers)
          .timeout(AppConfig.requestTimeout);

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        if (body['success'] == true) {
          return TenantDetail.fromJson(body['data'] as Map<String, dynamic>);
        }
      }
    } catch (e) {
      debugPrint('[PlatformTenant] detail ERROR: $e');
    }
    return null;
  }

  // ── Create ─────────────────────────────────────────────────────────────────

  Future<({bool success, String message})> create(Map<String, dynamic> data) async =>
      _post(_base, data);

  // ── Update ─────────────────────────────────────────────────────────────────

  Future<({bool success, String message})> update(int id, Map<String, dynamic> data) async =>
      _put('$_base/$id', data);

  // ── Archive ────────────────────────────────────────────────────────────────

  Future<({bool success, String message})> archive(int id) async => _delete('$_base/$id');

  // ── Lifecycle actions ──────────────────────────────────────────────────────

  Future<({bool success, String message})> activate(int id)   => _action(id, 'activate');
  Future<({bool success, String message})> suspend(int id)    => _action(id, 'suspend');
  Future<({bool success, String message})> reactivate(int id) => _action(id, 'reactivate');
  Future<({bool success, String message})> reseedMasters(int id) => _action(id, 'reseed-masters');

  Future<({bool success, String message})> extendGrace(int id, int days) =>
      _post('$_base/$id/extend', {'days': days});

  // ── Private helpers ────────────────────────────────────────────────────────

  Future<({bool success, String message})> _action(int id, String action) =>
      _post('$_base/$id/$action', {});

  Future<({bool success, String message})> _post(String url, Map<String, dynamic> body) async {
    try {
      final response = await http
          .post(Uri.parse(url), headers: await headers, body: jsonEncode(body))
          .timeout(AppConfig.requestTimeout);
      final parsed = jsonDecode(response.body) as Map<String, dynamic>;
      return (success: parsed['success'] as bool? ?? false, message: parsed['message'] as String? ?? '');
    } catch (e) {
      debugPrint('[PlatformTenant] POST ERROR: $e');
      return (success: false, message: 'Network error.');
    }
  }

  Future<({bool success, String message})> _put(String url, Map<String, dynamic> body) async {
    try {
      final response = await http
          .put(Uri.parse(url), headers: await headers, body: jsonEncode(body))
          .timeout(AppConfig.requestTimeout);
      final parsed = jsonDecode(response.body) as Map<String, dynamic>;
      return (success: parsed['success'] as bool? ?? false, message: parsed['message'] as String? ?? '');
    } catch (e) {
      debugPrint('[PlatformTenant] PUT ERROR: $e');
      return (success: false, message: 'Network error.');
    }
  }

  Future<({bool success, String message})> _delete(String url) async {
    try {
      final response = await http
          .delete(Uri.parse(url), headers: await headers)
          .timeout(AppConfig.requestTimeout);
      final parsed = jsonDecode(response.body) as Map<String, dynamic>;
      return (success: parsed['success'] as bool? ?? false, message: parsed['message'] as String? ?? '');
    } catch (e) {
      debugPrint('[PlatformTenant] DELETE ERROR: $e');
      return (success: false, message: 'Network error.');
    }
  }
}
