// core/storage.dart — Local token and user storage

import 'package:shared_preferences/shared_preferences.dart';
import 'constants.dart';

class AppStorage {
  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ── Token ──────────────────────────────────────────────────────────────────

  static Future<void> saveToken(String token) async {
    await _prefs?.setString(AppConstants.tokenKey, token);
  }

  static String? getToken() {
    return _prefs?.getString(AppConstants.tokenKey);
  }

  static Future<void> clearToken() async {
    await _prefs?.remove(AppConstants.tokenKey);
  }

  // ── User ───────────────────────────────────────────────────────────────────

  static Future<void> saveUser(String userJson) async {
    await _prefs?.setString(AppConstants.userKey, userJson);
  }

  static String? getUser() {
    return _prefs?.getString(AppConstants.userKey);
  }

  static Future<void> clearUser() async {
    await _prefs?.remove(AppConstants.userKey);
  }

  // ── Auth ───────────────────────────────────────────────────────────────────

  static bool get isLoggedIn => getToken() != null;

  static Future<void> logout() async {
    await clearToken();
    await clearUser();
  }
}
