import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'auth_service.dart';

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
        id: j['id'] as int,
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

class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  Future<List<LocationItem>> fetchAll() async {
    final token = await AuthService.instance.getStoredToken();
    final res = await http
        .get(
          Uri.parse('${AppConfig.hospitalApiUrl}/masters/locations'),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        )
        .timeout(AppConfig.requestTimeout);

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400) {
      throw Exception(body['message'] ?? 'Request failed (${res.statusCode})');
    }
    return (body['data'] as List? ?? [])
        .map((e) => LocationItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
