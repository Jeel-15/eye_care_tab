import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/patient_models.dart';
import 'base_service.dart';
import 'cache_service.dart';

class PatientService with AuthenticatedService {
  PatientService._();
  static final PatientService instance = PatientService._();


  // ── Patients List ────────────────────────────────────────────────────────

  // Scoped by hospital + user (see [scopeFor]) — an earlier, un-scoped
  // version of this key let a stale, previously-cached full patient list
  // leak from one account into a different, less-privileged account on the
  // same device. See ROLES_PERMISSIONS_DEEP_AUDIT_ROUND2.md Part B.
  static String _cacheKey(bool showAll, String scope) =>
      showAll ? 'cache_patients_all_v2_$scope' : 'cache_patients_today_v2_$scope';

  /// Cache scope key for a given hospital+user — pass the same value into
  /// every call below for one logged-in session, and into [clearCache] on
  /// logout so a stale list can't linger for the next account on this device.
  static String scopeFor({required String hospitalSlug, required int userId}) =>
      '${hospitalSlug}_$userId';

  Future<void> clearCache(String scope) async {
    await CacheService.instance.remove(_cacheKey(true, scope));
    await CacheService.instance.remove(_cacheKey(false, scope));
  }

  Future<({List<Patient> patients, PatientMeta meta, PatientStats stats})?>
      getCachedPatients({bool showAll = false, required String scope}) async {
    try {
      final json = await CacheService.instance.getJson(_cacheKey(showAll, scope));
      if (json == null) return null;
      final body = json as Map<String, dynamic>;
      final data = body['data'] as Map<String, dynamic>;
      final patients = (data['data'] as List)
          .map((e) => Patient.fromJson(e as Map<String, dynamic>))
          .toList();
      final meta = PatientMeta.fromJson(data['meta'] as Map<String, dynamic>);
      final stats = PatientStats.fromJson(data['stats'] as Map<String, dynamic>);
      return (patients: patients, meta: meta, stats: stats);
    } catch (_) {
      return null;
    }
  }

  Future<({List<Patient> patients, PatientMeta meta, PatientStats stats})>
      fetchPatients({
    bool showAll = false,
    String search = '',
    int page = 1,
    required String scope,
  }) async {
    final params = {
      'all': showAll ? '1' : '0',
      if (search.isNotEmpty) 'search': search,
      'page': page.toString(),
      'per_page': '20',
    };
    final uri = Uri.parse('${AppConfig.hospitalApiUrl}/patients')
        .replace(queryParameters: params);

    final resp = await http
        .get(uri, headers: await headers)
        .timeout(AppConfig.requestTimeout);

    // An ordinary permission-denied 403 must never be masked by whatever
    // stale cache the caller may have already rendered — see
    // ROLES_PERMISSIONS_DEEP_AUDIT_ROUND2.md Part B. Also routed through
    // the shared parser now (was hand-rolled before) so this call site also
    // gets the blocked-tenant/session-expired handling every other endpoint
    // has — see ACCESS_CONTROL_AND_DATA_SYNC_PLAN.md Phase 5. Discriminated
    // by the ABSENCE of the `code` key (only CheckSubscriptionActive's
    // tenant/plan-blocked 403 sends `code`) — NOT by `error`, which
    // CheckPermission's ordinary permission-denied 403 also sends; using
    // `error` here was a real bug found in DOCTOR_DASHBOARD_FIX_PLAN.md
    // Phase 3 that made this branch never actually fire.
    if (resp.statusCode == 403) {
      Map<String, dynamic>? decoded;
      try {
        decoded = jsonDecode(resp.body) as Map<String, dynamic>;
      } catch (_) {}
      if (decoded == null || !decoded.containsKey('code')) {
        throw PermissionDeniedException(
          (decoded?['message'] as String?) ?? 'You do not have permission to view patients.',
        );
      }
    }

    final body = parseApiResponse(resp);

    // Cache page-1 no-search result for instant next open
    if (page == 1 && search.isEmpty) {
      await CacheService.instance.setJson(_cacheKey(showAll, scope), body);
    }
    final data = body['data'] as Map<String, dynamic>;

    final patients = (data['data'] as List)
        .map((e) => Patient.fromJson(e as Map<String, dynamic>))
        .toList();

    final meta = PatientMeta.fromJson(data['meta'] as Map<String, dynamic>);
    final stats =
        PatientStats.fromJson(data['stats'] as Map<String, dynamic>);

    return (patients: patients, meta: meta, stats: stats);
  }

  // ── Next MRD ─────────────────────────────────────────────────────────────
  Future<String> fetchNextMrd() async {
    final uri = Uri.parse('${AppConfig.hospitalApiUrl}/patients/next-mrd');
    final resp = await http
        .get(uri, headers: await headers)
        .timeout(AppConfig.requestTimeout);

    if (resp.statusCode != 200) {
      throw Exception('Failed to fetch MRD: ${resp.statusCode}');
    }

    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    return body['mrd'] as String? ?? '';
  }

  // ── Search by contact ────────────────────────────────────────────────────
  Future<List<ContactSuggestion>> searchByContact(String contact) async {
    final uri = Uri.parse('${AppConfig.hospitalApiUrl}/patients/search-by-contact')
        .replace(queryParameters: {'contact': contact});

    final resp = await http
        .get(uri, headers: await headers)
        .timeout(AppConfig.requestTimeout);

    if (resp.statusCode != 200) return [];

    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final list = body['patients'] as List? ?? [];

    return list
        .map((e) => ContactSuggestion.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Phone appointment history. Same filters as the hospital page:
  /// name or mobile, optional appointment-date range.
  Future<({List<Patient> patients, PatientMeta meta})> fetchPhoneHistory({
    String search = '',
    String? fromDate,
    String? toDate,
    int page = 1,
  }) async {
    final params = <String, String>{
      'page': '$page',
      if (search.trim().isNotEmpty) 'search': search.trim(),
      if (fromDate != null && fromDate.isNotEmpty) 'from_date': fromDate,
      if (toDate != null && toDate.isNotEmpty) 'to_date': toDate,
    };
    final uri = Uri.parse('${AppConfig.hospitalApiUrl}/patients/phone-history').replace(queryParameters: params);
    final resp = await http.get(uri, headers: await headers).timeout(AppConfig.requestTimeout);
    final body = parseApiResponse(resp);
    final data = body['data'] as Map<String, dynamic>;
    final patients = (data['data'] as List).map((e) => Patient.fromJson(e as Map<String, dynamic>)).toList();
    final meta = PatientMeta.fromJson(data['meta'] as Map<String, dynamic>);
    return (patients: patients, meta: meta);
  }

  // ── Register Walk-in ─────────────────────────────────────────────────────
  Future<Patient> registerWalkIn(Map<String, dynamic> data) async {
    final uri = Uri.parse('${AppConfig.hospitalApiUrl}/patients');
    final resp = await http
        .post(uri,
            headers: await headers,
            body: jsonEncode(data))
        .timeout(AppConfig.requestTimeout);

    if (resp.statusCode != 201) {
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      throw Exception(body['message'] ?? 'Failed to register patient.');
    }

    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    return Patient.fromJson(body['data'] as Map<String, dynamic>);
  }

  // ── Register Phone Appointment ───────────────────────────────────────────
  Future<Patient> registerPhone(Map<String, dynamic> data) async {
    final uri = Uri.parse('${AppConfig.hospitalApiUrl}/patients/phone');
    final resp = await http
        .post(uri,
            headers: await headers,
            body: jsonEncode(data))
        .timeout(AppConfig.requestTimeout);

    if (resp.statusCode != 201) {
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      throw Exception(body['message'] ?? 'Failed to register phone appointment.');
    }

    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    return Patient.fromJson(body['data'] as Map<String, dynamic>);
  }

  // ── Single patient fetch (Patient Details modal — WEB_VIEW_BUTTONS_
  // PARITY_AUDIT.md finding #2) ────────────────────────────────────────────
  Future<Patient> fetchOne(int id) async {
    final uri = Uri.parse('${AppConfig.hospitalApiUrl}/patients/$id');
    final resp = await http.get(uri, headers: await headers).timeout(AppConfig.requestTimeout);
    final body = parseApiResponse(resp);
    return Patient.fromJson(body['data'] as Map<String, dynamic>);
  }

  /// Exam screens' "Patient Details" modal's editable Personal Information
  /// section — doctor-only on the server, mirrors web's quick-personal.
  Future<Patient> quickUpdatePersonal(int id, {
    required String fullName,
    required int age,
    required String gender,
    required String contactNo,
    required int locationId,
  }) async {
    final uri = Uri.parse('${AppConfig.hospitalApiUrl}/patients/$id/quick-personal');
    final resp = await http
        .patch(uri, headers: await headers, body: jsonEncode({
          'full_name': fullName,
          'age': age,
          'gender': gender,
          'contact_no': contactNo,
          'location_id': locationId,
        }))
        .timeout(AppConfig.requestTimeout);
    // parseApiResponse still runs for its error-throwing/permission-sync
    // side effects; the endpoint's own response only carries the Personal
    // Information fields (name/age/gender/contact/city), so re-fetch the
    // full record instead of hand-mapping a second, narrower Patient shape
    // — keeps the modal's Appointment Information section (doctor/case/
    // fee/referrer/receptionist, all unaffected by this save) populated too.
    parseApiResponse(resp);
    return fetchOne(id);
  }

  // ── Update Patient ───────────────────────────────────────────────────────
  Future<Patient> updatePatient(int id, Map<String, dynamic> data) async {
    final uri = Uri.parse('${AppConfig.hospitalApiUrl}/patients/$id');
    final resp = await http
        .put(uri,
            headers: await headers,
            body: jsonEncode(data))
        .timeout(AppConfig.requestTimeout);

    // Routed through the shared parser (was hand-rolled before) so this
    // call site also gets the blocked-tenant/session-expired/stale-record
    // handling every other endpoint has. See
    // ACCESS_CONTROL_AND_DATA_SYNC_PLAN.md Phase 5.
    final body = parseApiResponse(resp);
    return Patient.fromJson(body['data'] as Map<String, dynamic>);
  }

  // ── Check-in ─────────────────────────────────────────────────────────────
  Future<Patient> checkIn(
      int patientId, Map<String, dynamic> data) async {
    final uri =
        Uri.parse('${AppConfig.hospitalApiUrl}/patients/$patientId/checkin');
    final resp = await http
        .post(uri,
            headers: await headers,
            body: jsonEncode(data))
        .timeout(AppConfig.requestTimeout);

    if (resp.statusCode != 200) {
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      throw Exception(body['message'] ?? 'Check-in failed.');
    }

    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    return Patient.fromJson(body['data'] as Map<String, dynamic>);
  }
}
