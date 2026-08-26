import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'base_service.dart';

// ── Hospital Settings Data ────────────────────────────────────────────────────

class HospitalSettingsData {
  final String hospitalName;
  final String hospitalEmail;
  final String hospitalPhone;
  final String hospitalAddress;
  final String hospitalLogoUrl;
  // Location names
  final String hospitalCountry;
  final String hospitalState;
  final String hospitalDistrict;
  final String hospitalCity;
  final String hospitalTimezone;
  // Location IDs (resolved server-side for cascade pickers)
  final int? hospitalCountryId;
  final int? hospitalStateId;
  final int? hospitalDistrictId;
  // Billing
  final String invoicePrefix;
  final double taxPercentage;
  // Print
  final bool letterPadAvailable;
  final String printHeaderNote;
  final String printFooterNote;
  // Pagination
  final int paginationLimit;
  // Queue
  final int defaultDilationTime;
  // Wait — R
  final int waitGreenMax;
  final int waitOrangeMax;
  final int waitRedMax;
  // Wait — D
  final int waitDGreenMax;
  final int waitDOrangeMax;
  final int waitDRedMax;
  // Wait — ND
  final int waitNdGreenMax;
  final int waitNdOrangeMax;
  final int waitNdRedMax;

  const HospitalSettingsData({
    required this.hospitalName,
    required this.hospitalEmail,
    required this.hospitalPhone,
    required this.hospitalAddress,
    required this.hospitalLogoUrl,
    required this.hospitalCountry,
    required this.hospitalState,
    required this.hospitalDistrict,
    required this.hospitalCity,
    required this.hospitalTimezone,
    this.hospitalCountryId,
    this.hospitalStateId,
    this.hospitalDistrictId,
    required this.invoicePrefix,
    required this.taxPercentage,
    required this.letterPadAvailable,
    required this.printHeaderNote,
    required this.printFooterNote,
    required this.paginationLimit,
    required this.defaultDilationTime,
    required this.waitGreenMax,
    required this.waitOrangeMax,
    required this.waitRedMax,
    required this.waitDGreenMax,
    required this.waitDOrangeMax,
    required this.waitDRedMax,
    required this.waitNdGreenMax,
    required this.waitNdOrangeMax,
    required this.waitNdRedMax,
  });

  factory HospitalSettingsData.fromJson(Map<String, dynamic> j) =>
      HospitalSettingsData(
        hospitalName:        j['hospital_name']     as String? ?? '',
        hospitalEmail:       j['hospital_email']    as String? ?? '',
        hospitalPhone:       j['hospital_phone']    as String? ?? '',
        hospitalAddress:     j['hospital_address']  as String? ?? '',
        hospitalLogoUrl:     j['hospital_logo_url'] as String? ?? '',
        hospitalCountry:     j['hospital_country']  as String? ?? '',
        hospitalCountryId:   (j['hospital_country_id'] as num?)?.toInt(),
        hospitalState:       j['hospital_state']    as String? ?? '',
        hospitalStateId:     (j['hospital_state_id'] as num?)?.toInt(),
        hospitalDistrict:    j['hospital_district'] as String? ?? '',
        hospitalDistrictId:  (j['hospital_district_id'] as num?)?.toInt(),
        hospitalCity:        j['hospital_city']     as String? ?? '',
        hospitalTimezone:    j['hospital_timezone'] as String? ?? 'UTC',
        invoicePrefix:       j['invoice_prefix']    as String? ?? 'INV-',
        taxPercentage:       (j['tax_percentage']   as num?)?.toDouble() ?? 0.0,
        letterPadAvailable:  j['letter_pad'] == 'available',
        printHeaderNote:     j['print_header_note'] as String? ?? '',
        printFooterNote:     j['print_footer_note'] as String? ?? '',
        paginationLimit:     (j['pagination_limit']      as num?)?.toInt() ?? 25,
        defaultDilationTime: (j['default_dilation_time'] as num?)?.toInt() ?? 40,
        waitGreenMax:        (j['wait_green_max']    as num?)?.toInt() ?? 30,
        waitOrangeMax:       (j['wait_orange_max']   as num?)?.toInt() ?? 60,
        waitRedMax:          (j['wait_red_max']      as num?)?.toInt() ?? 120,
        waitDGreenMax:       (j['wait_d_green_max']  as num?)?.toInt() ?? 40,
        waitDOrangeMax:      (j['wait_d_orange_max'] as num?)?.toInt() ?? 90,
        waitDRedMax:         (j['wait_d_red_max']    as num?)?.toInt() ?? 120,
        waitNdGreenMax:      (j['wait_nd_green_max']  as num?)?.toInt() ?? 20,
        waitNdOrangeMax:     (j['wait_nd_orange_max'] as num?)?.toInt() ?? 60,
        waitNdRedMax:        (j['wait_nd_red_max']    as num?)?.toInt() ?? 120,
      );
}

// ── Location Cascade Models ───────────────────────────────────────────────────

class LocationCountry {
  final int id;
  final String name;
  final String? defaultTimezone;

  const LocationCountry({required this.id, required this.name, this.defaultTimezone});

  factory LocationCountry.fromJson(Map<String, dynamic> j) => LocationCountry(
        id: (j['id'] as num).toInt(),
        name: j['name'] as String,
        defaultTimezone: j['default_timezone'] as String?,
      );
}

class LocationItem {
  final int id;
  final String name;

  const LocationItem({required this.id, required this.name});

  factory LocationItem.fromJson(Map<String, dynamic> j) => LocationItem(
        id: (j['id'] as num).toInt(),
        name: j['name'] as String,
      );
}

class LocationTimezone {
  final String value;
  final String label;
  final String offset;

  const LocationTimezone({required this.value, required this.label, required this.offset});

  factory LocationTimezone.fromJson(Map<String, dynamic> j) => LocationTimezone(
        value:  j['value']  as String,
        label:  j['label']  as String,
        offset: j['offset'] as String,
      );
}

// ── Settings Service ──────────────────────────────────────────────────────────

class SettingsService with AuthenticatedService {
  SettingsService._();
  static final SettingsService instance = SettingsService._();

  // ── Settings CRUD ───────────────────────────────────────────────────────────

  Future<HospitalSettingsData> fetchSettings() async {
    final res = await http
        .get(
          Uri.parse('${AppConfig.hospitalApiUrl}/settings'),
          headers: await headers,
        )
        .timeout(AppConfig.requestTimeout);

    final body = parseApiResponse(res);
    return HospitalSettingsData.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<void> updateSettings({
    required String hospitalName,
    required String hospitalEmail,
    required String hospitalPhone,
    required String hospitalAddress,
    required String hospitalCountry,
    required String hospitalState,
    required String hospitalDistrict,
    required String hospitalCity,
    required String hospitalTimezone,
    required String invoicePrefix,
    required double taxPercentage,
    required bool letterPadAvailable,
    required String printHeaderNote,
    required String printFooterNote,
    required int paginationLimit,
    required int defaultDilationTime,
    required Map<String, int> waitThresholds,
  }) async {
    final payload = <String, dynamic>{
      'hospital_name':         hospitalName,
      'hospital_email':        hospitalEmail,
      'hospital_phone':        hospitalPhone,
      'hospital_address':      hospitalAddress,
      'hospital_country':      hospitalCountry,
      'hospital_state':        hospitalState,
      'hospital_district':     hospitalDistrict,
      'hospital_city':         hospitalCity,
      'hospital_timezone':     hospitalTimezone,
      'invoice_prefix':        invoicePrefix,
      'tax_percentage':        taxPercentage,
      'letter_pad':            letterPadAvailable ? 'available' : 'unavailable',
      'print_header_note':     printHeaderNote,
      'print_footer_note':     printFooterNote,
      'pagination_limit':      paginationLimit,
      'default_dilation_time': defaultDilationTime,
      ...waitThresholds,
    };

    final res = await http
        .put(
          Uri.parse('${AppConfig.hospitalApiUrl}/settings'),
          headers: await headers,
          body: jsonEncode(payload),
        )
        .timeout(AppConfig.requestTimeout);

    parseApiResponse(res);
  }

  // ── Logo upload ─────────────────────────────────────────────────────────────

  Future<String> uploadLogo(File imageFile) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${AppConfig.hospitalApiUrl}/settings/logo'),
    );
    request.headers.addAll(await headers);
    request.files.add(await http.MultipartFile.fromPath('logo', imageFile.path));

    final streamed = await request.send().timeout(AppConfig.requestTimeout);
    final res      = await http.Response.fromStream(streamed);
    final body     = parseApiResponse(res);

    return (body['data'] as Map<String, dynamic>)['url'] as String;
  }

  // ── Change password ─────────────────────────────────────────────────────────

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String newPasswordConfirmation,
  }) async {
    final res = await http
        .post(
          Uri.parse('${AppConfig.hospitalApiUrl}/settings/change-password'),
          headers: await headers,
          body: jsonEncode({
            'current_password':          currentPassword,
            'new_password':              newPassword,
            'new_password_confirmation': newPasswordConfirmation,
          }),
        )
        .timeout(AppConfig.requestTimeout);

    parseApiResponse(res);
  }

  // ── Location cascade ────────────────────────────────────────────────────────

  Future<List<LocationCountry>> fetchCountries() async {
    final res = await http
        .get(Uri.parse('${AppConfig.hospitalApiUrl}/masters/location/countries'), headers: await headers)
        .timeout(AppConfig.requestTimeout);
    final body = parseApiResponse(res);
    return (body['data'] as List).map((e) => LocationCountry.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<LocationItem>> fetchStates(int countryId) async {
    final res = await http
        .get(Uri.parse('${AppConfig.hospitalApiUrl}/masters/location/states?country_id=$countryId'), headers: await headers)
        .timeout(AppConfig.requestTimeout);
    final body = parseApiResponse(res);
    return (body['data'] as List).map((e) => LocationItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<LocationItem>> fetchDistricts(int stateId) async {
    final res = await http
        .get(Uri.parse('${AppConfig.hospitalApiUrl}/masters/location/districts?state_id=$stateId'), headers: await headers)
        .timeout(AppConfig.requestTimeout);
    final body = parseApiResponse(res);
    return (body['data'] as List).map((e) => LocationItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<LocationItem>> fetchCities(int districtId) async {
    final res = await http
        .get(Uri.parse('${AppConfig.hospitalApiUrl}/masters/location/cities?district_id=$districtId'), headers: await headers)
        .timeout(AppConfig.requestTimeout);
    final body = parseApiResponse(res);
    return (body['data'] as List).map((e) => LocationItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<LocationTimezone>> fetchTimezones() async {
    final res = await http
        .get(Uri.parse('${AppConfig.hospitalApiUrl}/masters/location/timezones'), headers: await headers)
        .timeout(const Duration(seconds: 20));
    final body = parseApiResponse(res);
    return (body['data'] as List).map((e) => LocationTimezone.fromJson(e as Map<String, dynamic>)).toList();
  }
}
