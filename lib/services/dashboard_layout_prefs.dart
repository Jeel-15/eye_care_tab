import 'package:shared_preferences/shared_preferences.dart';

/// Per-user layout for the tablet dashboard's three blocks — My Primary
/// Queue, Revenue Overview, Reception — Today.
///
/// Each block remembers a WIDTH as a fraction of the row, keyed by the
/// block id, so changing order does not mix those widths up. Order is a
/// separate list of those same ids. The dashboard `Wrap` still places them
/// left to right; moving a block left or right only swaps it with its
/// neighbour. Cards are not free-positioned.
///
/// Scoped per user id (not per device) so two roles sharing one tablet at a
/// reception desk don't inherit each other's resize choices, matching the
/// per-user scoping convention already used elsewhere for cached data (see
/// PatientService.scopeFor).
class DashboardLayoutPrefs {
  DashboardLayoutPrefs._();
  static final DashboardLayoutPrefs instance = DashboardLayoutPrefs._();

  static const String queueBlock = 'primary_queue';
  static const String revenueBlock = 'revenue_overview';
  static const String receptionBlock = 'reception_today';
  static const List<String> defaultOrder = [queueBlock, revenueBlock, receptionBlock];

  String _key(int userId, String blockId) => 'dash_block_w_v1_${userId}_$blockId';
  String _orderKey(int userId) => 'dash_block_order_v1_$userId';

  // In-memory cache — avoids a SharedPreferences round-trip on every
  // rebuild while a drag is in progress (the widget itself holds the live
  // value during the drag; this is read once on screen load).
  final Map<String, double> _cache = {};

  Future<double?> getFraction(int userId, String blockId) async {
    final k = _key(userId, blockId);
    if (_cache.containsKey(k)) return _cache[k];
    try {
      final prefs = await SharedPreferences.getInstance();
      final v = prefs.getDouble(k);
      if (v != null) _cache[k] = v;
      return v;
    } catch (_) {
      return null;
    }
  }

  Future<void> setFraction(int userId, String blockId, double fraction) async {
    final k = _key(userId, blockId);
    _cache[k] = fraction;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(k, fraction);
    } catch (_) {
      // Silent — a failed save just means this resize doesn't persist;
      // never worth surfacing an error for a layout preference.
    }
  }

  Future<List<String>> getOrder(int userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_orderKey(userId));
      if (raw == null) return List<String>.from(defaultOrder);
      return _decodeOrder(raw);
    } catch (_) {
      return List<String>.from(defaultOrder);
    }
  }

  List<String> _decodeOrder(String? raw) {
    final saved = raw?.split(',').where((id) => defaultOrder.contains(id)).toList() ?? [];
    return [
      ...saved,
      for (final id in defaultOrder)
        if (!saved.contains(id)) id,
    ];
  }

  Future<void> setOrder(int userId, List<String> order) async {
    final k = _orderKey(userId);
    final raw = order.join(',');
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(k, raw);
    } catch (_) {}
  }

  Future<void> resetAll(int userId) async {
    for (final id in const [queueBlock, revenueBlock, receptionBlock]) {
      final k = _key(userId, id);
      _cache.remove(k);
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(k);
      } catch (_) {}
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_orderKey(userId));
    } catch (_) {}
  }

  bool hasAnyCustomWidth(int userId) => const [queueBlock, revenueBlock, receptionBlock]
      .any((id) => _cache.containsKey(_key(userId, id)));
}
