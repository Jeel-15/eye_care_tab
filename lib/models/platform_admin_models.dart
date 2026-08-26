class PlatformAdmin {
  final int id;
  final String name;
  final String email;
  final String role;
  final DateTime? lastLoginAt;
  final String? lastLoginIp;

  const PlatformAdmin({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.lastLoginAt,
    this.lastLoginIp,
  });

  factory PlatformAdmin.fromJson(Map<String, dynamic> json) => PlatformAdmin(
        id:           json['id'] as int,
        name:         json['name'] as String,
        email:        json['email'] as String,
        role:         json['role'] as String,
        lastLoginAt:  json['last_login_at'] != null
            ? DateTime.tryParse(json['last_login_at'] as String)
            : null,
        lastLoginIp:  json['last_login_ip'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id':            id,
        'name':          name,
        'email':         email,
        'role':          role,
        'last_login_at': lastLoginAt?.toIso8601String(),
        'last_login_ip': lastLoginIp,
      };

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : 'SA';
  }
}

class PlatformLoginResult {
  final bool success;
  final String message;
  final String? token;
  final PlatformAdmin? admin;

  const PlatformLoginResult({
    required this.success,
    required this.message,
    this.token,
    this.admin,
  });
}
