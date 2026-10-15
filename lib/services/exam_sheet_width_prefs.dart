import 'package:shared_preferences/shared_preferences.dart';

/// Per-user width for the exam section sheet (`showExamSectionSheet`) — the
/// right-side panel every Primary/Secondary exam field group (C/O, Vision,
/// O/E, Fundus, ...) opens in. All of them funnel through that one function,
/// so a single saved width applies to every section automatically — there
/// is deliberately no per-section id here, unlike `DashboardLayoutPrefs`.
///
/// Stored as a fraction of screen width (not raw px) so it still looks
/// right if the user switches to a different/rotated screen — same
/// convention as `DashboardLayoutPrefs`.
class ExamSheetWidthPrefs {
  ExamSheetWidthPrefs._();
  static final ExamSheetWidthPrefs instance = ExamSheetWidthPrefs._();

  String _key(int userId) => 'exam_sheet_w_v1_$userId';

  // In-memory cache — avoids a SharedPreferences round-trip on every sheet
  // open; only one user is ever "current" in a running app.
  int? _cachedUserId;
  double? _cachedFraction;

  Future<double?> getFraction(int userId) async {
    if (_cachedUserId == userId) return _cachedFraction;
    try {
      final prefs = await SharedPreferences.getInstance();
      final v = prefs.getDouble(_key(userId));
      _cachedUserId = userId;
      _cachedFraction = v;
      return v;
    } catch (_) {
      return null;
    }
  }

  Future<void> setFraction(int userId, double fraction) async {
    _cachedUserId = userId;
    _cachedFraction = fraction;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_key(userId), fraction);
    } catch (_) {
      // Silent — a failed save just means this resize doesn't persist;
      // never worth surfacing an error for a layout preference.
    }
  }

  Future<void> reset(int userId) async {
    _cachedUserId = userId;
    _cachedFraction = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key(userId));
    } catch (_) {}
  }
}
