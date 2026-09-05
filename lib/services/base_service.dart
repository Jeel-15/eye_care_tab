import 'dart:convert';
import 'package:http/http.dart' as http;
import 'access_guard.dart';
import 'auth_service.dart';

// Thrown when the server returns 401 — AccessGuard has already navigated to
// the login screen by the time this is thrown; callers' own catch blocks can
// safely ignore it (their screen is being replaced) or no-op.
class SessionExpiredException implements Exception {
  const SessionExpiredException();
  @override
  String toString() => 'Session expired. Please log in again.';
}

// Thrown when a hospital's plan has expired/is suspended/is pending
// approval — distinguished from an ordinary permission-denied 403 by the
// `error` JSON key (vs Laravel's default `message` key). AccessGuard has
// already navigated to the Access Restricted screen by the time this is
// thrown. See ACCESS_CONTROL_AND_DATA_SYNC_PLAN.md Phase 2.
class PlanAccessBlockedException implements Exception {
  final String humanMessage;
  const PlanAccessBlockedException(this.humanMessage);
  @override
  String toString() => humanMessage;
}

// Thrown on 409 — the record being saved was changed elsewhere (another
// platform/tab) since this screen fetched it. Distinguished from a generic
// error so the caller can show a clear "reload before saving" prompt
// instead of a plain failure message. See
// ACCESS_CONTROL_AND_DATA_SYNC_PLAN.md Phase 5.
class StaleRecordException implements Exception {
  final String humanMessage;
  const StaleRecordException(this.humanMessage);
  @override
  String toString() => humanMessage;
}

/// Centralised HTTP response parser used by every service.
/// - 401 → [SessionExpiredException] (+ global redirect to login)
/// - 403 with an `error` key → [PlanAccessBlockedException] (+ global
///   redirect to the Access Restricted screen) — a normal permission-denied
///   403 uses Laravel's default `message` key and is unaffected.
/// - 404 → friendly "not found" message
/// - 422 → first validation error message
/// - 5xx → generic server error
/// - other 4xx → cleaned message (internal class paths stripped)
Map<String, dynamic> parseApiResponse(http.Response res) {
  Map<String, dynamic> body;
  try {
    body = jsonDecode(res.body) as Map<String, dynamic>;
  } catch (_) {
    throw Exception('Unexpected server response (${res.statusCode}).');
  }

  if (res.statusCode == 401) {
    AccessGuard.instance.showSessionExpired();
    throw const SessionExpiredException();
  }

  if (res.statusCode == 403 && body.containsKey('error')) {
    final message = body['error'] as String? ?? 'Access to this hospital is currently restricted.';
    AccessGuard.instance.showAccessBlocked(message);
    throw PlanAccessBlockedException(message);
  }

  if (res.statusCode == 409 && body.containsKey('error')) {
    throw StaleRecordException(body['error'] as String? ?? 'This record was changed elsewhere. Please reload before saving.');
  }

  if (res.statusCode == 404) {
    throw Exception('Record not found. Please refresh the list.');
  }

  if (res.statusCode == 422) {
    final errors = body['errors'] as Map<String, dynamic>?;
    if (errors != null && errors.isNotEmpty) {
      final first = errors.values.first;
      throw Exception(first is List ? first.first.toString() : first.toString());
    }
    throw Exception(body['message'] ?? 'Validation failed.');
  }

  if (res.statusCode >= 500) {
    throw Exception('Server error. Please try again later.');
  }

  if (res.statusCode >= 400) {
    var msg = body['message'] as String? ?? 'Request failed (${res.statusCode}).';
    // Strip internal Laravel model class paths e.g.
    // "No query results for model [App\Models\Hospital\OT\OtSlot] 303"
    msg = msg.replaceAll(RegExp(r'\[App\\[^\]]+\]\s*\d*'), '').trim();
    if (msg.isEmpty) msg = 'Request failed (${res.statusCode}).';
    throw Exception(msg);
  }

  return body;
}

mixin AuthenticatedService {
  Future<Map<String, String>> get headers async {
    final token = await AuthService.instance.getStoredToken();
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }
}
