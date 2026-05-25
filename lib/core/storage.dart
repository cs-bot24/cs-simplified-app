import 'package:shared_preferences/shared_preferences.dart';
import 'constants.dart';

class AppStorage {
  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static Future<void> saveToken(String token) async =>
      await _prefs?.setString(AppConstants.tokenKey, token);

  static String? getToken() => _prefs?.getString(AppConstants.tokenKey);

  static Future<void> saveUser(String json) async =>
      await _prefs?.setString(AppConstants.userKey, json);

  static String? getUser() => _prefs?.getString(AppConstants.userKey);

  static bool get isLoggedIn => getToken() != null;

  static Future<void> logout() async {
    await _prefs?.remove(AppConstants.tokenKey);
    await _prefs?.remove(AppConstants.userKey);
  }
}
