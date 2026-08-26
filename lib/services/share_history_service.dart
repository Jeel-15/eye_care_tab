import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/share_history_models.dart';
import 'base_service.dart';

class ShareHistoryService with AuthenticatedService {
  ShareHistoryService._();
  static final ShareHistoryService instance = ShareHistoryService._();


  String get _base => '${AppConfig.hospitalApiUrl}/share-history';

  // ── Tab 1: Patient History ────────────────────────────────────────

  Future<({List<HistoryPatient> patients, ShareHistoryMeta meta})> fetchPatients({
    String patientName = '',
    String doctorName = '',
    String contactNo = '',
    String date = '',
    int page = 1,
  }) async {
    final params = <String, String>{
      if (patientName.isNotEmpty) 'patient_name': patientName,
      if (doctorName.isNotEmpty) 'doctor_name': doctorName,
      if (contactNo.isNotEmpty) 'contact_no': contactNo,
      if (date.isNotEmpty) 'date': date,
      'page': page.toString(),
      'per_page': '20',
    };
    final uri = Uri.parse('$_base/patients').replace(queryParameters: params);
    final resp = await http.get(uri, headers: await headers).timeout(AppConfig.requestTimeout);

    if (resp.statusCode != 200) throw Exception('Failed to load patient history: ${resp.statusCode}');

    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>;

    return (
      patients: (data['data'] as List)
          .map((e) => HistoryPatient.fromJson(e as Map<String, dynamic>))
          .toList(),
      meta: ShareHistoryMeta.fromJson(data['meta'] as Map<String, dynamic>),
    );
  }

  // ── Tab 2: Hospital Directory ─────────────────────────────────────

  Future<({List<ShareHospital> hospitals, ShareHistoryMeta meta})> fetchHospitals({
    String hospName = '',
    String city = '',
    String district = '',
    String state = '',
    int page = 1,
  }) async {
    final params = <String, String>{
      if (hospName.isNotEmpty) 'hosp_name': hospName,
      if (city.isNotEmpty) 'city': city,
      if (district.isNotEmpty) 'district': district,
      if (state.isNotEmpty) 'state': state,
      'page': page.toString(),
      'per_page': '20',
    };
    final uri = Uri.parse('$_base/hospitals').replace(queryParameters: params);
    final resp = await http.get(uri, headers: await headers).timeout(AppConfig.requestTimeout);

    if (resp.statusCode != 200) throw Exception('Failed to load hospitals: ${resp.statusCode}');

    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>;

    return (
      hospitals: (data['data'] as List)
          .map((e) => ShareHospital.fromJson(e as Map<String, dynamic>))
          .toList(),
      meta: ShareHistoryMeta.fromJson(data['meta'] as Map<String, dynamic>),
    );
  }

  // ── Hospital Detail ───────────────────────────────────────────────

  Future<HospitalDetail> fetchHospitalDetail(int hospitalId) async {
    final uri = Uri.parse('$_base/hospitals/$hospitalId');
    final resp = await http.get(uri, headers: await headers).timeout(AppConfig.requestTimeout);

    if (resp.statusCode != 200) throw Exception('Failed to load hospital detail: ${resp.statusCode}');

    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    return HospitalDetail.fromJson(body['data'] as Map<String, dynamic>);
  }

  // ── Tab 3: Connections ────────────────────────────────────────────

  Future<ConnectionsData> fetchConnections() async {
    final uri = Uri.parse('$_base/connections');
    final resp = await http.get(uri, headers: await headers).timeout(AppConfig.requestTimeout);

    if (resp.statusCode != 200) throw Exception('Failed to load connections: ${resp.statusCode}');

    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>;

    return ConnectionsData(
      accepted: (data['accepted_connections'] as List)
          .map((e) => ShareConnection.fromJson(e as Map<String, dynamic>))
          .toList(),
      incoming: (data['incoming_requests'] as List)
          .map((e) => IncomingRequest.fromJson(e as Map<String, dynamic>))
          .toList(),
      sent: (data['sent_requests'] as List)
          .map((e) => SentRequest.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  // ── Actions ───────────────────────────────────────────────────────

  Future<void> sendRequest(int toTenantId) async {
    final uri = Uri.parse('$_base/requests');
    final resp = await http
        .post(uri, headers: await headers, body: jsonEncode({'to_tenant_id': toTenantId}))
        .timeout(AppConfig.requestTimeout);

    if (resp.statusCode != 200) {
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      throw Exception(body['message'] ?? 'Failed to send request.');
    }
  }

  Future<void> acceptRequest(int requestId) async {
    final uri = Uri.parse('$_base/requests/$requestId/accept');
    final resp = await http.post(uri, headers: await headers).timeout(AppConfig.requestTimeout);

    if (resp.statusCode != 200) {
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      throw Exception(body['message'] ?? 'Failed to accept request.');
    }
  }

  Future<void> removeRequest(int requestId) async {
    final uri = Uri.parse('$_base/requests/$requestId');
    final resp = await http.delete(uri, headers: await headers).timeout(AppConfig.requestTimeout);

    if (resp.statusCode != 200) {
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      throw Exception(body['message'] ?? 'Failed to remove request.');
    }
  }

  // ── Partner Patients ──────────────────────────────────────────────

  Future<({List<HistoryPatient> patients, ShareHistoryMeta meta, String partnerName})>
      fetchPartnerPatients(
    int partnerTenantId, {
    String patientName = '',
    String doctorName = '',
    String contactNo = '',
    String date = '',
    int page = 1,
  }) async {
    final params = <String, String>{
      if (patientName.isNotEmpty) 'patient_name': patientName,
      if (doctorName.isNotEmpty) 'doctor_name': doctorName,
      if (contactNo.isNotEmpty) 'contact_no': contactNo,
      if (date.isNotEmpty) 'date': date,
      'page': page.toString(),
      'per_page': '20',
    };
    final uri = Uri.parse('$_base/partner/$partnerTenantId/patients')
        .replace(queryParameters: params);
    final resp = await http.get(uri, headers: await headers).timeout(AppConfig.requestTimeout);

    if (resp.statusCode == 403) throw Exception('No accepted connection with this hospital.');
    if (resp.statusCode != 200) throw Exception('Failed to load partner patients: ${resp.statusCode}');

    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>;

    return (
      patients: (data['data'] as List)
          .map((e) => HistoryPatient.fromJson(e as Map<String, dynamic>))
          .toList(),
      meta: ShareHistoryMeta.fromJson(data['meta'] as Map<String, dynamic>),
      partnerName: (data['partner_hospital'] as Map<String, dynamic>?)?['name'] as String? ?? '',
    );
  }
}
