import 'dart:io';
import 'dart:ui' show Color;
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'base_service.dart';

// ── Models ────────────────────────────────────────────────────────────────────

class UserRole {
  final int id;
  final String name;
  final String slug;
  final String color;
  final bool isSuper;
  final bool isDoctorRole;

  const UserRole({
    required this.id,
    required this.name,
    required this.slug,
    required this.color,
    required this.isSuper,
    required this.isDoctorRole,
  });

  factory UserRole.fromJson(Map<String, dynamic> j) => UserRole(
        id:           (j['id'] as num).toInt(),
        name:         j['name'] as String,
        slug:         j['slug'] as String,
        color:        j['color'] as String? ?? '#1B4F72',
        isSuper:      j['is_super'] == true,
        isDoctorRole: j['is_doctor_role'] == true,
      );

  // Parsed once at deserialization — not on every card build()
  Color get parsedColor {
    try {
      final clean = color.replaceFirst('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return const Color(0xFF1B4F72);
    }
  }
}

class HospitalUserModel {
  final int id;
  final String name;
  final String email;
  final String contact;
  final String status;
  final UserRole? role;
  final bool focPermission;
  final String? lastLoginAt;
  // Full fields (from show/create/update)
  final String? doctorType;
  final String? doctorPrefix;
  final String? registrationNo;
  final int? experienceYears;
  final String? signatureUrl;
  final String? profilePhotoUrl;

  const HospitalUserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.contact,
    required this.status,
    this.role,
    required this.focPermission,
    this.lastLoginAt,
    this.doctorType,
    this.doctorPrefix,
    this.registrationNo,
    this.experienceYears,
    this.signatureUrl,
    this.profilePhotoUrl,
  });

  factory HospitalUserModel.fromJson(Map<String, dynamic> j) => HospitalUserModel(
        id:              (j['id'] as num).toInt(),
        name:            j['name'] as String? ?? '',
        email:           j['email'] as String? ?? '',
        contact:         j['contact'] as String? ?? '',
        status:          j['status'] as String? ?? 'active',
        role:            j['role'] != null
                          ? UserRole.fromJson(j['role'] as Map<String, dynamic>)
                          : null,
        focPermission:   j['foc_permission'] == true,
        lastLoginAt:     j['last_login_at'] as String?,
        doctorType:      j['doctor_type'] as String?,
        doctorPrefix:    j['doctor_prefix'] as String?,
        registrationNo:  j['registration_no'] as String?,
        experienceYears: (j['experience_years'] as num?)?.toInt(),
        signatureUrl:    j['signature_url'] as String?,
        profilePhotoUrl: j['profile_photo_url'] as String?,
      );
}

class DoctorTypeOption {
  final String value;
  final String label;
  const DoctorTypeOption({required this.value, required this.label});
  factory DoctorTypeOption.fromJson(Map<String, dynamic> j) =>
      DoctorTypeOption(value: j['value'] as String, label: j['label'] as String);
}

class UserFormData {
  final List<UserRole> roles;
  final List<DoctorTypeOption> doctorTypes;
  const UserFormData({required this.roles, required this.doctorTypes});
}

class UserListResponse {
  final List<HospitalUserModel> users;
  final int currentPage;
  final int lastPage;
  final int total;

  const UserListResponse({
    required this.users,
    required this.currentPage,
    required this.lastPage,
    required this.total,
  });
}

// ── Service ───────────────────────────────────────────────────────────────────

class UserService with AuthenticatedService {
  UserService._();
  static final UserService instance = UserService._();

  // ── List ──────────────────────────────────────────────────────────────────

  Future<UserListResponse> fetchUsers({
    int page = 1,
    String? search,
    int? roleId,
    String? status,
  }) async {
    final params = <String, String>{'page': page.toString(), 'per_page': '20'};
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (roleId != null) params['role_id'] = roleId.toString();
    if (status != null) params['status'] = status;

    final uri = Uri.parse('${AppConfig.hospitalApiUrl}/config/users')
        .replace(queryParameters: params);

    final res = await http
        .get(uri, headers: await headers)
        .timeout(AppConfig.requestTimeout);

    final body = parseApiResponse(res);

    final data = body['data'] as Map<String, dynamic>;
    final meta = data['meta'] as Map<String, dynamic>;

    return UserListResponse(
      users: (data['users'] as List)
          .map((e) => HospitalUserModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      currentPage: (meta['current_page'] as num).toInt(),
      lastPage:    (meta['last_page'] as num).toInt(),
      total:       (meta['total'] as num).toInt(),
    );
  }

  // ── Form Data ─────────────────────────────────────────────────────────────

  Future<UserFormData> fetchFormData() async {
    final res = await http
        .get(
          Uri.parse('${AppConfig.hospitalApiUrl}/config/users/form-data'),
          headers: await headers,
        )
        .timeout(AppConfig.requestTimeout);

    final body = parseApiResponse(res);

    final data = body['data'] as Map<String, dynamic>;
    return UserFormData(
      roles: (data['roles'] as List)
          .map((e) => UserRole.fromJson(e as Map<String, dynamic>))
          .toList(),
      doctorTypes: (data['doctor_types'] as List)
          .map((e) => DoctorTypeOption.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  // ── Single User ───────────────────────────────────────────────────────────

  Future<HospitalUserModel> fetchUser(int id) async {
    final res = await http
        .get(
          Uri.parse('${AppConfig.hospitalApiUrl}/config/users/$id'),
          headers: await headers,
        )
        .timeout(AppConfig.requestTimeout);

    final body = parseApiResponse(res);
    return HospitalUserModel.fromJson(body['data'] as Map<String, dynamic>);
  }

  // ── Create User ───────────────────────────────────────────────────────────

  Future<HospitalUserModel> createUser({
    required String name,
    required String email,
    required String contact,
    required int roleId,
    required String password,
    required String passwordConfirmation,
    required String status,
    String? doctorType,
    String? doctorPrefix,
    String? registrationNo,
    int? experienceYears,
    bool focPermission = false,
    File? signature,
    File? profilePhoto,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${AppConfig.hospitalApiUrl}/config/users'),
    );
    request.headers.addAll(await headers);

    request.fields['name']                  = name;
    request.fields['email']                 = email;
    request.fields['contact']               = contact;
    request.fields['role_id']               = roleId.toString();
    request.fields['password']              = password;
    request.fields['password_confirmation'] = passwordConfirmation;
    request.fields['status']                = status;
    request.fields['foc_permission']        = focPermission ? '1' : '0';

    if (doctorType != null) request.fields['doctor_type'] = doctorType;
    if (doctorPrefix != null) request.fields['doctor_prefix'] = doctorPrefix;
    if (registrationNo != null) request.fields['registration_no'] = registrationNo;
    if (experienceYears != null) request.fields['experience_years'] = experienceYears.toString();

    if (signature != null) {
      request.files.add(await http.MultipartFile.fromPath('signature', signature.path));
    }
    if (profilePhoto != null) {
      request.files.add(await http.MultipartFile.fromPath('profile_photo', profilePhoto.path));
    }

    final streamed = await request.send().timeout(AppConfig.requestTimeout);
    final res      = await http.Response.fromStream(streamed);
    final body     = parseApiResponse(res);

    return HospitalUserModel.fromJson(body['data'] as Map<String, dynamic>);
  }

  // ── Update User ───────────────────────────────────────────────────────────

  Future<HospitalUserModel> updateUser(
    int id, {
    required String name,
    required String email,
    required String contact,
    required int roleId,
    String? password,
    String? passwordConfirmation,
    required String status,
    String? doctorType,
    String? doctorPrefix,
    String? registrationNo,
    int? experienceYears,
    bool focPermission = false,
    File? signature,
    bool clearSignature = false,
    File? profilePhoto,
    bool clearProfilePhoto = false,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${AppConfig.hospitalApiUrl}/config/users/$id'),
    );
    request.headers.addAll(await headers);

    request.fields['name']           = name;
    request.fields['email']          = email;
    request.fields['contact']        = contact;
    request.fields['role_id']        = roleId.toString();
    request.fields['status']         = status;
    request.fields['foc_permission'] = focPermission ? '1' : '0';

    if (password != null && password.isNotEmpty) {
      request.fields['password']              = password;
      request.fields['password_confirmation'] = passwordConfirmation ?? '';
    }

    if (doctorType != null) request.fields['doctor_type'] = doctorType;
    if (doctorPrefix != null) request.fields['doctor_prefix'] = doctorPrefix;
    if (registrationNo != null) request.fields['registration_no'] = registrationNo;
    if (experienceYears != null) request.fields['experience_years'] = experienceYears.toString();

    if (signature != null) {
      request.files.add(await http.MultipartFile.fromPath('signature', signature.path));
    } else if (clearSignature) {
      request.fields['clear_signature'] = '1';
    }

    if (profilePhoto != null) {
      request.files.add(await http.MultipartFile.fromPath('profile_photo', profilePhoto.path));
    } else if (clearProfilePhoto) {
      request.fields['clear_profile_photo'] = '1';
    }

    final streamed = await request.send().timeout(AppConfig.requestTimeout);
    final res      = await http.Response.fromStream(streamed);
    final body     = parseApiResponse(res);

    return HospitalUserModel.fromJson(body['data'] as Map<String, dynamic>);
  }

  // ── Delete ────────────────────────────────────────────────────────────────

  Future<void> deleteUser(int id) async {
    final res = await http
        .delete(
          Uri.parse('${AppConfig.hospitalApiUrl}/config/users/$id'),
          headers: await headers,
        )
        .timeout(AppConfig.requestTimeout);

    parseApiResponse(res);
  }

  // ── Toggle Status ─────────────────────────────────────────────────────────

  Future<String> toggleStatus(int id) async {
    final res = await http
        .patch(
          Uri.parse('${AppConfig.hospitalApiUrl}/config/users/$id/toggle-status'),
          headers: await headers,
        )
        .timeout(AppConfig.requestTimeout);

    final body = parseApiResponse(res);
    return (body['data'] as Map<String, dynamic>)['status'] as String;
  }
}
