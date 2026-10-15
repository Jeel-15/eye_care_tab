import 'package:flutter/foundation.dart';
import '../models/auth_models.dart';
import '../models/permission_matrix.dart';

/// Listeners are notified whenever the effective permissions change (login,
/// /auth/me refresh, logout) so the shell, rail, buttons and PermissionGuard
/// rebuild without a logout/login.
class PermissionService extends ChangeNotifier {
  PermissionService._();
  static final PermissionService instance = PermissionService._();

  List<String> _permissions = [];
  bool _isSuper = false;
  bool _loaded = false;
  List<String>? _modules;
  String? _permissionsVersion;

  /// Load permissions from a [RoleInfo]. Call this after login and after
  /// every /auth/me refresh. Passing null is safe (results in no permissions).
  /// [modules]/[version] come from the API's permission-sync contract and are
  /// null on older API builds.
  void load(RoleInfo? role, {List<String>? modules, String? version}) {
    final isSuper = role?.isSuper ?? false;
    // Expand manage/bundle keys so can('casetype_add') works when the role
    // only has casetype_manage (matches web expand_map + API login expansion).
    final permissions = PermissionMatrix.expandGranted(role?.permissions ?? []);
    final changed = !_loaded ||
        isSuper != _isSuper ||
        !setEquals(permissions.toSet(), _permissions.toSet()) ||
        !_sameModules(modules, _modules);

    _isSuper = isSuper;
    _permissions = permissions;
    _modules = modules == null ? null : List.unmodifiable(modules);
    _permissionsVersion = version;
    _loaded = true;
    if (changed) notifyListeners();
  }

  static bool _sameModules(List<String>? a, List<String>? b) {
    if (a == null || b == null) return a == b;
    return setEquals(a.toSet(), b.toSet());
  }

  /// Version of the permissions currently loaded (server hash), null until
  /// the API sends one.
  String? get permissionsVersion => _permissionsVersion;

  /// True when the server reports a different permissions version than the
  /// one currently loaded. A missing server header never counts as a change.
  bool isStale(String? serverVersion) =>
      _loaded &&
      serverVersion != null &&
      serverVersion.isNotEmpty &&
      serverVersion != _permissionsVersion;

  /// True if the user has the given permission key.
  /// Always returns true for super-admin roles.
  /// Returns false if permissions have not been loaded yet.
  bool can(String permission) {
    if (!_loaded) return false;
    if (_isSuper) return true;
    return _permissions.contains(permission);
  }

  /// True if the user has ANY of the given permission keys.
  bool canAny(List<String> permissions) => permissions.any(can);

  /// True if the user has ALL of the given permission keys.
  bool canAll(List<String> permissions) => permissions.every(can);

  /// True if the user has at least one permission that belongs to [module]
  /// per the permission matrix (e.g. canModule('ot') — any ot_* key).
  /// Looks up each granted key's module via [PermissionMatrix.keyToModule]
  /// rather than string-prefix matching, since the new flat key scheme
  /// (e.g. 'patient_view' → module 'opd') doesn't encode its module as a
  /// literal string prefix the way the old dotted scheme did.
  bool canModule(String module) {
    if (!_loaded) return false;
    if (_isSuper) return true;
    return _permissions.any((p) => PermissionMatrix.keyToModule[p] == module);
  }

  /// True if the user has at least one permission belonging to [feature]
  /// within [module] (e.g. canFeature('master', 'location')).
  bool canFeature(String module, String feature) {
    if (!_loaded) return false;
    if (_isSuper) return true;
    return _permissions.any((p) =>
        PermissionMatrix.keyToModule[p] == module &&
        PermissionMatrix.keyToFeature[p] == feature);
  }

  /// True if the user can reach [key] module (e.g. 'opd', 'ot', 'master').
  /// Uses the server's module list when the API sends one, otherwise derives
  /// it from the granted keys.
  bool hasModule(String key) {
    if (!_loaded) return false;
    if (_isSuper) return true;
    final modules = _modules;
    if (modules != null) return modules.contains(key);
    return canModule(key);
  }

  bool get isLoaded => _loaded;
  bool get isSuper => _isSuper;

  /// True if the user should see Masters nav/entry.
  /// Web landing uses any CRUD verb per feature — not view-only.
  bool get canAccessMasters =>
      canFeature('master', 'casetype') ||
      canFeature('master', 'location') ||
      canFeature('master', 'referrer') ||
      canFeature('master', 'duration') ||
      PermissionMatrix.eyeExamMasterTypes.any(
        (type) => canFeature('master', type.$1),
      ) ||
      canFeature('master', 'ot_slot') ||
      canFeature('master', 'ot_type') ||
      canFeature('master', 'ot_surgery_type') ||
      canFeature('master', 'ot_charge') ||
      canFeature('master', 'ot_inventory') ||
      canFeature('master', 'ot_lens_option') ||
      canFeature('master', 'ot_lens_power') ||
      canFeature('master', 'ot_package_master');

  bool get canAccessEyeExamMasters => PermissionMatrix.eyeExamMasterTypes.any(
        (type) => canFeature('master', type.$1),
      );

  /// Clear all permissions. Call this on logout.
  void clear() {
    final wasLoaded = _loaded;
    _permissions = [];
    _isSuper = false;
    _loaded = false;
    _modules = null;
    _permissionsVersion = null;
    if (wasLoaded) notifyListeners();
  }
}
