import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

// Thrown when the server returns 401 — screens/global handler can catch this
// specifically to redirect to login.
class SessionExpiredException implements Exception {
  const SessionExpiredException();
  @override
  String toString() => 'Session expired. Please log in again.';
}

/// Centralised HTTP response parser used by every service.
/// - 401 → [SessionExpiredException]
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
    throw const SessionExpiredException();
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
