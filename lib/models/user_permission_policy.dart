enum UserCategory { doctor, reception, otStaff }

class UserPermissionPolicy {
  const UserPermissionPolicy._();

  /// Must resolve to the same category `UserApiController::roleCategory`
  /// authorizes against, otherwise the tab shows actions the API rejects
  /// (or hides ones it allows). [userCategory] is the API's own answer
  /// (`user_category`); the slug/name fallback mirrors the backend for
  /// older API builds.
  static UserCategory categoryFor({
    String? userCategory,
    required String roleSlug,
    required String roleName,
  }) {
    switch (userCategory) {
      case 'doctor':
        return UserCategory.doctor;
      case 'reception':
        return UserCategory.reception;
      case 'ot_staff':
        return UserCategory.otStaff;
    }
    final slug = roleSlug.toLowerCase();
    final name = roleName.toLowerCase();
    if (slug.contains('doctor') || name.contains('doctor')) {
      return UserCategory.doctor;
    }
    if (slug.contains('reception') || name.contains('reception')) {
      return UserCategory.reception;
    }
    return UserCategory.otStaff;
  }

  static String permissionKey(UserCategory category, String action) {
    final feature = switch (category) {
      UserCategory.doctor => 'user_doctor',
      UserCategory.reception => 'user_reception',
      UserCategory.otStaff => 'user_ot_staff',
    };
    return '${feature}_$action';
  }
}
