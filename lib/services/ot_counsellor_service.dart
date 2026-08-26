import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/ot_booking_models.dart';
import '../models/ot_counsellor_models.dart';
import 'base_service.dart';

/// Round 3 Phase 1 — `OtCounsellorApiController`.
class OtCounsellorService with AuthenticatedService {
  OtCounsellorService._();
  static final OtCounsellorService instance = OtCounsellorService._();

  String get _base => AppConfig.hospitalApiUrl;

  Map<String, dynamic> _parse(http.Response res) => parseApiResponse(res);

  Future<({List<OtBookingSummary> items, OtPaginationMeta meta})> fetchBookings({int page = 1, int perPage = 25}) async {
    final uri = Uri.parse('$_base/ot/counsellor/bookings').replace(queryParameters: {'page': '$page', 'per_page': '$perPage'});
    final res = await http.get(uri, headers: await headers).timeout(AppConfig.requestTimeout);
    final body = _parse(res);
    final data = body['data'] as Map<String, dynamic>;
    final items = (data['data'] as List? ?? []).map((e) => OtBookingSummary.fromJson(e as Map<String, dynamic>)).toList();
    return (items: items, meta: OtPaginationMeta.fromJson(data));
  }

  Future<OtPackageLookupSuggestion?> lookupPackage({required double lensCost, required String roomCategory}) async {
    final uri = Uri.parse('$_base/ot/counsellor/package-lookup').replace(queryParameters: {'lens_cost': '$lensCost', 'room_category': roomCategory});
    final res = await http.get(uri, headers: await headers).timeout(AppConfig.requestTimeout);
    final body = _parse(res);
    final data = body['data'] as Map<String, dynamic>;
    if (data['found'] != true || data['package'] == null) return null;
    return OtPackageLookupSuggestion.fromJson(data['package'] as Map<String, dynamic>);
  }

  Future<OtCounsellingDetail> fetchCounsellingDetail(int bookingId) async {
    final res = await http.get(Uri.parse('$_base/ot/bookings/$bookingId/counselling'), headers: await headers).timeout(AppConfig.requestTimeout);
    final body = _parse(res);
    return OtCounsellingDetail.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<double> storeCounselling(int bookingId, OtCounsellingItem counselling) async {
    final res = await http
        .post(Uri.parse('$_base/ot/bookings/$bookingId/counselling'), headers: await headers, body: jsonEncode(counselling.toJson()))
        .timeout(AppConfig.requestTimeout);
    final body = _parse(res);
    final data = body['data'] as Map<String, dynamic>;
    return (data['total_estimate'] as num?)?.toDouble() ?? 0;
  }

  Future<OtConsentItem> storeConsent(int bookingId, {required bool consentGiven, String? patientSignatureDataUri, String? guardianSignatureDataUri, String? witnessName}) async {
    final res = await http
        .post(
          Uri.parse('$_base/ot/bookings/$bookingId/consent'),
          headers: await headers,
          body: jsonEncode({
            'consent_given': consentGiven,
            if (patientSignatureDataUri != null) 'patient_signature': patientSignatureDataUri,
            if (guardianSignatureDataUri != null) 'guardian_signature': guardianSignatureDataUri,
            'witness_name': witnessName,
          }),
        )
        .timeout(AppConfig.requestTimeout);
    final body = _parse(res);
    return OtConsentItem.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<String> sendToBilling(int bookingId) async {
    final res = await http.post(Uri.parse('$_base/ot/bookings/$bookingId/send-to-billing'), headers: await headers).timeout(AppConfig.requestTimeout);
    final body = _parse(res);
    return (body['data'] as Map<String, dynamic>)['ot_status'] as String? ?? '';
  }
}
