class RoleInfo {
  final int id;
  final String name;
  final String slug;
  final String color;
  final bool isSuper;
  final List<String> permissions;

  const RoleInfo({
    required this.id,
    required this.name,
    required this.slug,
    required this.color,
    required this.isSuper,
    this.permissions = const [],
  });

  factory RoleInfo.fromJson(Map<String, dynamic> json) => RoleInfo(
        id: json['id'] as int,
        name: json['name'] as String,
        slug: json['slug'] as String,
        color: (json['color'] as String?) ?? '#1B4F72',
        isSuper: json['is_super'] == true,
        permissions: (json['permissions'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'slug': slug,
        'color': color,
        'is_super': isSuper,
        'permissions': permissions,
      };
}

class UserInfo {
  final int id;
  final String name;
  final String email;
  final String? contact;
  final String status;
  final String? doctorPrefix;
  final String? profilePhotoUrl;
  final RoleInfo? role;

  const UserInfo({
    required this.id,
    required this.name,
    required this.email,
    this.contact,
    required this.status,
    this.doctorPrefix,
    this.profilePhotoUrl,
    this.role,
  });

  factory UserInfo.fromJson(Map<String, dynamic> json) => UserInfo(
        id: json['id'] as int,
        name: json['name'] as String,
        email: json['email'] as String,
        contact: json['contact'] as String?,
        status: (json['status'] as String?) ?? 'active',
        doctorPrefix: json['doctor_prefix'] as String?,
        profilePhotoUrl: json['profile_photo_url'] as String?,
        role: json['role'] != null
            ? RoleInfo.fromJson(json['role'] as Map<String, dynamic>)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'contact': contact,
        'status': status,
        'doctor_prefix': doctorPrefix,
        'profile_photo_url': profilePhotoUrl,
        'role': role?.toJson(),
      };
}

class HospitalInfo {
  final String name;
  final String slug;
  final int? primaryColor;
  final int? primaryLightColor;
  final int? secondaryColor;
  final int? backgroundColor;

  const HospitalInfo({
    required this.name,
    required this.slug,
    this.primaryColor,
    this.primaryLightColor,
    this.secondaryColor,
    this.backgroundColor,
  });

  factory HospitalInfo.fromJson(Map<String, dynamic> json) => HospitalInfo(
        name: json['name'] as String,
        slug: json['slug'] as String,
        primaryColor:      json['primary_color']       as int?,
        primaryLightColor: json['primary_light_color'] as int?,
        secondaryColor:    json['secondary_color']     as int?,
        backgroundColor:   json['background_color']    as int?,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'slug': slug,
        if (primaryColor != null)      'primary_color':       primaryColor,
        if (primaryLightColor != null) 'primary_light_color': primaryLightColor,
        if (secondaryColor != null)    'secondary_color':     secondaryColor,
        if (backgroundColor != null)   'background_color':    backgroundColor,
      };
}

class LoginResult {
  final bool success;
  final String message;
  final String? token;
  final UserInfo? user;
  final HospitalInfo? hospital;

  const LoginResult({
    required this.success,
    required this.message,
    this.token,
    this.user,
    this.hospital,
  });
}
