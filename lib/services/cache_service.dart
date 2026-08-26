import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CacheService {
  CacheService._();
  static final instance = CacheService._();

  Future<void> setJson(String key, dynamic data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, jsonEncode(data));
    } catch (_) {}
  }

  Future<dynamic> getJson(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null) return null;
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> remove(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
    } catch (_) {}
  }
}
