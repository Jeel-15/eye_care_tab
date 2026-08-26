import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'auth_service.dart';

class ProfileRoleData {
  final int id;
  final String name;
  final String slug;
  final String color;
  final bool isSuper;

  const ProfileRoleData({
    required this.id,
    required this.name,
    required this.slug,
    required this.color,
    required this.isSuper,
  });

  factory ProfileRoleData.fromJson(Map<String, dynamic> j) => ProfileRoleData(
        id: j['id'] as int,
        name: j['name'] as String,
        slug: j['slug'] as String,
        color: (j['color'] as String?) ?? '#1B4F72',
        isSuper: j['is_super'] == true,
      );
}

class ProfileData {
  final int id;
  final String name;
  final String email;
  final String? contact;
  final String status;
  final bool isDoctor;
  final ProfileRoleData? role;
  final String? doctorType;
  final String? doctorPrefix;
  final bool focPermission;
  final String? registrationNo;
  final int? experienceYears;

  const ProfileData({
    required this.id,
    required this.name,
    required this.email,
    this.contact,
    required this.status,
    required this.isDoctor,
    this.role,
    this.doctorType,
    this.doctorPrefix,
    this.focPermission = false,
    this.registrationNo,
    this.experienceYears,
  });

  factory ProfileData.fromJson(Map<String, dynamic> j) => ProfileData(
        id: j['id'] as int,
        name: j['name'] as String,
        email: j['email'] as String,
        contact: j['contact'] as String?,
        status: (j['status'] as String?) ?? 'active',
        isDoctor: j['is_doctor'] == true,
        role: j['role'] != null
            ? ProfileRoleData.fromJson(j['role'] as Map<String, dynamic>)
            : null,
        doctorType: j['doctor_type'] as String?,
        doctorPrefix: j['doctor_prefix'] as String?,
        focPermission: j['foc_permission'] == true,
        registrationNo: j['registration_no'] as String?,
        experienceYears: j['experience_years'] as int?,
      );
}

class ProfileService {
  ProfileService._();
  static final ProfileService instance = ProfileService._();

  Future<Map<String, String>> _headers() async {
    final token = await AuthService.instance.getStoredToken();
    return {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
  }

  Future<ProfileData> fetchProfile() async {
    final res = await http
        .get(
          Uri.parse('${AppConfig.hospitalApiUrl}/profile'),
          headers: await _headers(),
        )
        .timeout(AppConfig.requestTimeout);

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400) {
      throw Exception(body['message'] ?? 'Request failed (${res.statusCode})');
    }
    return ProfileData.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<ProfileData> updateProfile({
    required String name,
    required String email,
    String? currentPassword,
    String? newPassword,
    String? registrationNo,
    int? experienceYears,
  }) async {
    final payload = <String, dynamic>{
      'name': name,
      'email': email,
    };

    if (currentPassword != null && currentPassword.isNotEmpty) {
      payload['current_password'] = currentPassword;
      payload['new_password'] = newPassword ?? '';
      payload['new_password_confirmation'] = newPassword ?? '';
    }

    if (registrationNo != null) {
      payload['registration_no'] = registrationNo.isEmpty ? null : registrationNo;
    }
    if (experienceYears != null) {
      payload['experience_years'] = experienceYears;
    }

    final res = await http
        .put(
          Uri.parse('${AppConfig.hospitalApiUrl}/profile'),
          headers: await _headers(),
          body: jsonEncode(payload),
        )
        .timeout(AppConfig.requestTimeout);

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400) {
      final errors = body['errors'] as Map<String, dynamic>?;
      if (errors != null && errors.isNotEmpty) {
        final firstVal = errors.values.first;
        final msg = firstVal is List
            ? firstVal.first.toString()
            : firstVal.toString();
        throw Exception(msg);
      }
      throw Exception(body['message'] ?? 'Update failed (${res.statusCode})');
    }
    return ProfileData.fromJson(body['data'] as Map<String, dynamic>);
  }
}
