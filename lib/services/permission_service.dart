import '../models/auth_models.dart';

class PermissionService {
  PermissionService._();
  static final PermissionService instance = PermissionService._();

  List<String> _permissions = [];
  bool _isSuper = false;
  bool _loaded = false;

  /// Load permissions from a [RoleInfo]. Call this after login and after
  /// every /auth/me refresh. Passing null is safe (results in no permissions).
  void load(RoleInfo? role) {
    _isSuper = role?.isSuper ?? false;
    _permissions = role?.permissions ?? [];
    _loaded = true;
  }

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

  /// True if the user has at least one permission whose key starts with
  /// [module] followed by a dot. E.g. canModule('ot') checks for 'ot.*'.
  bool canModule(String module) {
    if (!_loaded) return false;
    if (_isSuper) return true;
    return _permissions.any((p) => p.startsWith('$module.'));
  }

  bool get isLoaded => _loaded;
  bool get isSuper => _isSuper;

  /// Clear all permissions. Call this on logout.
  void clear() {
    _permissions = [];
    _isSuper = false;
    _loaded = false;
  }
}
