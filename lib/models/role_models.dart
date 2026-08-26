class RolePermissionItem {
  final int id;
  final String action;
  final String label;
  final String description;
  final bool isGranted;

  const RolePermissionItem({
    required this.id,
    required this.action,
    required this.label,
    required this.description,
    required this.isGranted,
  });

  factory RolePermissionItem.fromJson(Map<String, dynamic> j) =>
      RolePermissionItem(
        id: j['id'] as int? ?? 0,
        action: j['action'] as String? ?? '',
        label: j['label'] as String? ?? '',
        description: j['description'] as String? ?? '',
        isGranted: j['is_granted'] == true,
      );

  RolePermissionItem copyWith({bool? isGranted}) => RolePermissionItem(
        id: id,
        action: action,
        label: label,
        description: description,
        isGranted: isGranted ?? this.isGranted,
      );
}

class RoleModel {
  final int id;
  final String name;
  final String slug;
  final String color;
  final String? description;
  final bool isSystem;
  final bool isSuper;
  final int usersCount;
  final bool isDeletable;
  // Only populated when fetching single role (show endpoint)
  final Map<String, List<RolePermissionItem>> permissions;

  const RoleModel({
    required this.id,
    required this.name,
    required this.slug,
    required this.color,
    this.description,
    required this.isSystem,
    required this.isSuper,
    required this.usersCount,
    required this.isDeletable,
    this.permissions = const {},
  });

  factory RoleModel.fromJson(Map<String, dynamic> j) {
    final permsRaw = j['permissions'] as Map<String, dynamic>?;
    final perms = <String, List<RolePermissionItem>>{};
    if (permsRaw != null) {
      for (final entry in permsRaw.entries) {
        perms[entry.key] = (entry.value as List)
            .map((e) =>
                RolePermissionItem.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    }
    return RoleModel(
      id: j['id'] as int? ?? 0,
      name: j['name'] as String? ?? '',
      slug: j['slug'] as String? ?? '',
      color: j['color'] as String? ?? '#1B4F72',
      description: j['description'] as String?,
      isSystem: j['is_system'] == true,
      isSuper: j['is_super'] == true,
      usersCount: j['users_count'] as int? ?? 0,
      isDeletable: j['is_deletable'] == true,
      permissions: perms,
    );
  }
}

class AllPermissionsResult {
  final Map<String, List<RolePermissionItem>> modules;

  const AllPermissionsResult({required this.modules});

  factory AllPermissionsResult.fromJson(Map<String, dynamic> j) {
    final data = j['data'] as Map<String, dynamic>? ?? {};
    final modules = <String, List<RolePermissionItem>>{};
    for (final entry in data.entries) {
      modules[entry.key] = (entry.value as List)
          .map((e) =>
              RolePermissionItem.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return AllPermissionsResult(modules: modules);
  }
}
