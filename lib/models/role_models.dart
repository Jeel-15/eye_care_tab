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

/// One feature row inside a module (e.g. module "opd" → feature "patient").
/// The pre-rewrite backend shape has no feature grouping at all — for that
/// shape every permission in a module is placed under a single synthetic
/// feature with an empty label (see [PermissionModuleGroup.fromFlatList]).
class PermissionFeatureGroup {
  final String label;
  final List<RolePermissionItem> permissions;

  const PermissionFeatureGroup({required this.label, required this.permissions});

  factory PermissionFeatureGroup.fromJson(Map<String, dynamic> j) =>
      PermissionFeatureGroup(
        label: j['label'] as String? ?? '',
        permissions: (j['permissions'] as List? ?? [])
            .map((e) => RolePermissionItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// One module row (e.g. "opd", "ot", "master"), grouping its features.
///
/// Two backend shapes are known to occur and both are handled here:
///  - New (post role/permission rewrite): `module => {label, features: {...}}`.
///  - Old (pre-rewrite; still returned by `RoleApiController::permissions()`
///    until that endpoint is migrated): `module => [permission, ...]` — a
///    flat list with no feature grouping.
class PermissionModuleGroup {
  final String label;
  final Map<String, PermissionFeatureGroup> features;

  const PermissionModuleGroup({required this.label, required this.features});

  factory PermissionModuleGroup.fromJson(Map<String, dynamic> j) =>
      PermissionModuleGroup(
        label: j['label'] as String? ?? '',
        features: {
          for (final e
              in (j['features'] as Map<String, dynamic>? ?? {}).entries)
            e.key: PermissionFeatureGroup.fromJson(e.value as Map<String, dynamic>),
        },
      );

  static const _legacyModuleLabels = {
    'opd': 'OPD',
    'ot': 'OT (Operation Theatre)',
    'master': 'Masters',
    'settings': 'Settings',
    'setting': 'Settings',
    'reports': 'Reports',
    'report': 'Reports',
    'dashboard': 'Dashboard',
  };

  factory PermissionModuleGroup.fromFlatList(String moduleKey, List list) {
    final perms = list
        .map((e) => RolePermissionItem.fromJson(e as Map<String, dynamic>))
        .toList();
    final label = _legacyModuleLabels[moduleKey] ??
        (moduleKey.isEmpty
            ? moduleKey
            : moduleKey[0].toUpperCase() + moduleKey.substring(1));
    return PermissionModuleGroup(
      label: label,
      features: {'_all': PermissionFeatureGroup(label: '', permissions: perms)},
    );
  }

  List<RolePermissionItem> get allPermissions =>
      features.values.expand((f) => f.permissions).toList();
}

Map<String, PermissionModuleGroup> _parseModuleTree(dynamic raw) {
  if (raw is! Map<String, dynamic>) return {};
  final result = <String, PermissionModuleGroup>{};
  for (final e in raw.entries) {
    final value = e.value;
    if (value is List) {
      result[e.key] = PermissionModuleGroup.fromFlatList(e.key, value);
    } else if (value is Map<String, dynamic>) {
      result[e.key] = PermissionModuleGroup.fromJson(value);
    }
  }
  return result;
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
  final Map<String, PermissionModuleGroup> permissions;

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
      permissions: _parseModuleTree(j['permissions']),
    );
  }
}

class AllPermissionsResult {
  final Map<String, PermissionModuleGroup> modules;

  const AllPermissionsResult({required this.modules});

  factory AllPermissionsResult.fromJson(Map<String, dynamic> j) {
    return AllPermissionsResult(modules: _parseModuleTree(j['data']));
  }
}
