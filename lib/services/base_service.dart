import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'access_guard.dart';
import 'auth_service.dart';
import 'permission_service.dart';

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
// `code` JSON key that only CheckSubscriptionActive sends (both shapes
// happen to also carry an `error` key, so `error` alone is NOT a safe
// discriminator — found and fixed in DOCTOR_DASHBOARD_FIX_PLAN.md Phase 3
// after CheckPermission's `error`-keyed 403 was found to incorrectly
// trigger this same branch). AccessGuard has already navigated to the
// Access Restricted screen by the time this is thrown. See
// ACCESS_CONTROL_AND_DATA_SYNC_PLAN.md Phase 2.
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

// Thrown on an ordinary permission-denied 403 (Laravel's default `message`
// shape, as opposed to the `error`-keyed tenant/plan-blocked 403 above).
// Distinguished so a screen that eagerly renders locally-cached data before
// its real fetch resolves can tell "you are not allowed to see this" apart
// from a transient network failure — the former must always clear stale
// data and show an error, the latter is fine to leave the stale data up.
// See ROLES_PERMISSIONS_DEEP_AUDIT_ROUND2.md Part B.
class PermissionDeniedException implements Exception {
  final String humanMessage;
  const PermissionDeniedException(this.humanMessage);
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
  if (res.statusCode != 401) syncPermissionsVersion(res.headers);

  Map<String, dynamic> body;
  try {
    body = jsonDecode(res.body) as Map<String, dynamic>;
  } catch (_) {
    throw Exception('Unexpected server response (${res.statusCode}).');
  }

  if (res.statusCode == 401) {
    unawaited(AuthService.instance.clearSession());
    AccessGuard.instance.showSessionExpired();
    throw const SessionExpiredException();
  }

  if (res.statusCode == 403 && body.containsKey('code')) {
    final message = body['error'] as String? ?? 'Access to this hospital is currently restricted.';
    AccessGuard.instance.showAccessBlocked(message);
    throw PlanAccessBlockedException(message);
  }

  // Ordinary permission-denied 403: the server already knows the user lost
  // this permission, so refresh the app's copy (rail/buttons/guards update).
  if (res.statusCode == 403) {
    unawaited(AuthService.instance.refreshMe());
    throw PermissionDeniedException(
      _nonBlank(body['message']) ?? _nonBlank(body['error']) ?? 'You do not have permission to perform this action.',
    );
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
      final text = first is List ? first.first.toString() : first.toString();
      throw Exception(_nonBlank(text) ?? 'Validation failed.');
    }
    throw Exception(_nonBlank(body['message']) ?? 'Validation failed.');
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

String? _nonBlank(dynamic value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

/// Header the API attaches to every authenticated response. The `http`
/// package exposes response header names lowercased.
const permissionsVersionHeader = 'x-permissions-version';

/// Starts a background permission refresh when the server's permissions
/// version differs from the one the app has loaded. Callers that bypass
/// [parseApiResponse] (file downloads/exports) also pass [statusCode] so a
/// permission-denied 403 refreshes too.
void syncPermissionsVersion(Map<String, String> headers, {int? statusCode}) {
  if (statusCode == 403 ||
      PermissionService.instance.isStale(headers[permissionsVersionHeader])) {
    unawaited(AuthService.instance.refreshMe());
  }
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
