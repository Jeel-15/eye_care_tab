import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/patient_models.dart';
import 'base_service.dart';

class MastersData {
  final List<CaseTypeOption> cases;
  final List<DoctorOption> doctors;
  final List<LocationOption> locations;
  final List<SlotOption> slots;
  final List<ReferrerOption> referrers;

  const MastersData({
    required this.cases,
    required this.doctors,
    required this.locations,
    required this.slots,
    required this.referrers,
  });
}

class MastersService with AuthenticatedService {
  MastersService._();
  static final MastersService instance = MastersService._();

  MastersData? _cache;


  Future<T> _fetch<T>(String path, T Function(List) parse) async {
    final uri = Uri.parse('${AppConfig.hospitalApiUrl}/$path');
    final resp = await http
        .get(uri, headers: await headers)
        .timeout(AppConfig.requestTimeout);

    if (resp.statusCode != 200) {
      throw Exception('Failed to load $path: ${resp.statusCode}');
    }

    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    return parse(body['data'] as List? ?? []);
  }

  Future<MastersData> fetchAll({bool forceRefresh = false}) async {
    if (_cache != null && !forceRefresh) return _cache!;

    final results = await Future.wait([
      _fetch('masters/cases',
          (l) => l.map((e) => CaseTypeOption.fromJson(e as Map<String, dynamic>)).toList()),
      _fetch('masters/doctors',
          (l) => l.map((e) => DoctorOption.fromJson(e as Map<String, dynamic>)).toList()),
      _fetch('masters/locations',
          (l) => l.map((e) => LocationOption.fromJson(e as Map<String, dynamic>)).toList()),
      _fetch('masters/slots',
          (l) => l.map((e) => SlotOption.fromJson(e as Map<String, dynamic>)).toList()),
      _fetch('masters/referrers',
          (l) => l.map((e) => ReferrerOption.fromJson(e as Map<String, dynamic>)).toList()),
    ]);

    _cache = MastersData(
      cases: results[0] as List<CaseTypeOption>,
      doctors: results[1] as List<DoctorOption>,
      locations: results[2] as List<LocationOption>,
      slots: results[3] as List<SlotOption>,
      referrers: results[4] as List<ReferrerOption>,
    );

    return _cache!;
  }

  Future<LocationOption> addLocation({
    required String city,
    required String district,
    required String state,
  }) async {
    final uri = Uri.parse('${AppConfig.hospitalApiUrl}/masters/locations');
    final resp = await http
        .post(uri,
            headers: await headers,
            body: jsonEncode({
              'city': city,
              'district': district,
              'state': state,
            }))
        .timeout(AppConfig.requestTimeout);

    if (resp.statusCode != 201) {
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      throw Exception(body['message'] ?? 'Failed to add city.');
    }

    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final loc = LocationOption.fromJson(body['data'] as Map<String, dynamic>);

    // Append to cache
    if (_cache != null) {
      _cache = MastersData(
        cases: _cache!.cases,
        doctors: _cache!.doctors,
        locations: [..._cache!.locations, loc],
        slots: _cache!.slots,
        referrers: _cache!.referrers,
      );
    }

    return loc;
  }

  void clearCache() => _cache = null;
}
