import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../utils/json_parse.dart';
import 'base_service.dart';

class LocationItem {
  final int id;
  final String city;
  final String? district;
  final String? state;

  const LocationItem({
    required this.id,
    required this.city,
    this.district,
    this.state,
  });

  factory LocationItem.fromJson(Map<String, dynamic> j) => LocationItem(
        id: jsonInt(j['id']),
        city: j['city'] as String? ?? '',
        district: j['district'] as String?,
        state: j['state'] as String?,
      );

  String get subtitle {
    final parts = [
      if (district != null && district!.isNotEmpty) district!,
      if (state != null && state!.isNotEmpty) state!,
    ];
    return parts.join(', ');
  }
}

class LocationService with AuthenticatedService {
  LocationService._();
  static final LocationService instance = LocationService._();

  Future<List<LocationItem>> fetchAll() async {
    final res = await http
        .get(Uri.parse('${AppConfig.hospitalApiUrl}/masters/locations'), headers: await headers)
        .timeout(AppConfig.requestTimeout);

    final body = parseApiResponse(res);
    return (body['data'] as List? ?? [])
        .map((e) => LocationItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // Web (Hospital\Master\BasicMasterController) has always let a Hospital
  // Admin add/edit/delete locations — the app previously only supported
  // add (used inline by the OT Appointment form) and showed this whole
  // screen as hardcoded read-only. See OT_BUGS_ROUND4_FIX_PLAN.md
  // "Locations master read-only" follow-up.
  Future<LocationItem> create({required String city, required String state, String? district}) async {
    final res = await http
        .post(
          Uri.parse('${AppConfig.hospitalApiUrl}/masters/locations'),
          headers: await headers,
          body: jsonEncode({'city': city, 'state': state, if (district != null && district.isNotEmpty) 'district': district}),
        )
        .timeout(AppConfig.requestTimeout);
    final body = parseApiResponse(res);
    return LocationItem.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<LocationItem> update(int id, {required String city, required String state, String? district}) async {
    final res = await http
        .put(
          Uri.parse('${AppConfig.hospitalApiUrl}/masters/locations/$id'),
          headers: await headers,
          body: jsonEncode({'city': city, 'state': state, if (district != null && district.isNotEmpty) 'district': district}),
        )
        .timeout(AppConfig.requestTimeout);
    final body = parseApiResponse(res);
    return LocationItem.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<void> delete(int id) async {
    final res = await http
        .delete(Uri.parse('${AppConfig.hospitalApiUrl}/masters/locations/$id'), headers: await headers)
        .timeout(AppConfig.requestTimeout);
    parseApiResponse(res);
  }
}
