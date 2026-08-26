class PhoneRules {
  static const _regex = r'^\+?[0-9]{7,15}$';
  static const _msg   = 'Enter a valid phone number (7–15 digits, optional +)';

  static String? required(String? v) {
    if (v == null || v.trim().isEmpty) return 'Phone number required';
    if (!RegExp(_regex).hasMatch(v.trim())) return _msg;
    return null;
  }

  static String? nullable(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    if (!RegExp(_regex).hasMatch(v.trim())) return _msg;
    return null;
  }

  static bool hasEnoughDigits(String v) =>
      v.replaceAll(RegExp(r'[^\d]'), '').length >= 7;
}
