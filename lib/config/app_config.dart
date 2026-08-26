class AppConfig {
  AppConfig._();

  // ── Environment toggle ───────────────────────────────────────────────────
  // Set to true before building the release APK / Play Store upload.
  static const bool isProduction = false;

  // ── URLs ─────────────────────────────────────────────────────────────────
  // Dev:  uses adb reverse (localhost:8080 on device = PC Apache port 80)
  // Prod: your live domain — update _prodUrl before release build
  // static const String _devUrl  = 'http://localhost:8080/api/v1';
  static const String _devUrl  = 'http://eyenosis.com/api/v1';
  static const String _prodUrl = 'http://eyenosis.com/api/v1';

  static const String apiBaseUrl = isProduction ? _prodUrl : _devUrl;

  // Platform Super Admin — no slug, platform-wide
  static const String platformApiUrl = '$apiBaseUrl/super';

  // ── Hospital session state ────────────────────────────────────────────────
  // Slug is auto-discovered at login via GET /api/v1/find-hospital
  // and restored from SharedPreferences on app restart.
  static String slug = '';
  static String hospitalName = 'Eye-SaaS HMS';

  static String get hospitalApiUrl => '$apiBaseUrl/$slug';

  static const Duration requestTimeout = Duration(seconds: 30);
}
