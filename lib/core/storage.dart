import 'package:shared_preferences/shared_preferences.dart';
import 'constants.dart';

class AppStorage {
  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ── Auth Token ────────────────────────────────────────────────────────────
  static Future<void> saveToken(String token) async =>
      await _prefs?.setString(AppConstants.tokenKey, token);

  static String? getToken() => _prefs?.getString(AppConstants.tokenKey);

  static Future<void> saveUser(String json) async =>
      await _prefs?.setString(AppConstants.userKey, json);

  static String? getUser() => _prefs?.getString(AppConstants.userKey);

  static bool get isLoggedIn => getToken() != null;

  // ── Remember Me ──────────────────────────────────────────────────────────
  static Future<void> saveRememberMe(bool value) async =>
      await _prefs?.setBool(AppConstants.rememberMeKey, value);

  static bool get rememberMe => _prefs?.getBool(AppConstants.rememberMeKey) ?? false;

  // ── FCM Token ────────────────────────────────────────────────────────────
  static Future<void> saveFcmToken(String token) async =>
      await _prefs?.setString(AppConstants.fcmTokenKey, token);

  static String? getFcmToken() => _prefs?.getString(AppConstants.fcmTokenKey);

  // ── Notifications (local cache) ──────────────────────────────────────────
  static Future<void> saveNotifications(String json) async =>
      await _prefs?.setString('cached_notifications', json);

  static String? getNotifications() => _prefs?.getString('cached_notifications');

  // ── Logout ────────────────────────────────────────────────────────────────
  static Future<void> logout({bool clearRememberMe = false}) async {
    await _prefs?.remove(AppConstants.tokenKey);
    await _prefs?.remove(AppConstants.userKey);
    if (clearRememberMe) {
      await _prefs?.remove(AppConstants.rememberMeKey);
    }
  }
}
