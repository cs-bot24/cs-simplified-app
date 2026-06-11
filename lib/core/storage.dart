// lib/core/storage.dart
//
// Platform-adaptive storage layer.
//
// Mobile (Android/iOS):
//   - JWT + user JSON stored in flutter_secure_storage (Keystore-backed AES)
//   - Non-sensitive values in SharedPreferences
//
// Web:
//   - flutter_secure_storage on web falls back to localStorage automatically.
//   - This is acceptable for MVP. For production hardening, migrate to
//     HttpOnly cookies (requires backend session endpoint).
//   - The IOSOptions and AndroidOptions are ignored on web — no crash.
//
// The in-memory cache pattern is retained for both platforms because
// ApiClient._headers() is called synchronously and needs the token
// without an await.

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'constants.dart';

class AppStorage {
  static SharedPreferences? _prefs;

  // On web, flutter_secure_storage uses localStorage under the hood.
  // AndroidOptions and IOSOptions are safely ignored on web.
  static final _secure = kIsWeb
      ? const FlutterSecureStorage()
      : const FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
          iOptions: IOSOptions(
            accessibility: KeychainAccessibility.unlocked_this_device,
          ),
        );

  // ── In-memory caches ──────────────────────────────────────────────────────
  static String? _cachedToken;
  static String? _cachedUser;

  // ── Initialisation ────────────────────────────────────────────────────────

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static Future<void> loadTokenToCache() async {
    _cachedToken = await _secure.read(key: AppConstants.tokenKey);
  }

  static Future<void> loadUserToCache() async {
    _cachedUser = await _secure.read(key: AppConstants.userKey);
  }

  // ── Auth Token ────────────────────────────────────────────────────────────

  static Future<void> saveToken(String token) async {
    _cachedToken = token;
    await _secure.write(key: AppConstants.tokenKey, value: token);
  }

  static String? getToken() => _cachedToken;

  // ── User JSON ─────────────────────────────────────────────────────────────

  static Future<void> saveUser(String json) async {
    _cachedUser = json;
    await _secure.write(key: AppConstants.userKey, value: json);
  }

  static String? getUser() => _cachedUser;

  static bool get isLoggedIn => _cachedToken != null;

  // ── Remember Me ───────────────────────────────────────────────────────────

  static Future<void> saveRememberMe(bool value) async =>
      await _prefs?.setBool(AppConstants.rememberMeKey, value);

  static bool get rememberMe =>
      _prefs?.getBool(AppConstants.rememberMeKey) ?? false;

  // ── FCM Token ─────────────────────────────────────────────────────────────

  static Future<void> saveFcmToken(String token) async =>
      await _prefs?.setString(AppConstants.fcmTokenKey, token);

  static String? getFcmToken() => _prefs?.getString(AppConstants.fcmTokenKey);

  // ── Notification cache ────────────────────────────────────────────────────

  static Future<void> saveNotifications(String json) async =>
      await _prefs?.setString('cached_notifications', json);

  static String? getNotifications() =>
      _prefs?.getString('cached_notifications');

  // ── Generic key-value ─────────────────────────────────────────────────────

  static Future<void> setString(String key, String value) async =>
      await _prefs?.setString(key, value);

  static String? getString(String key) => _prefs?.getString(key);

  static Future<void> removeKey(String key) async =>
      await _prefs?.remove(key);

  // ── Logout ────────────────────────────────────────────────────────────────

  static Future<void> logout({bool clearRememberMe = false}) async {
    _cachedToken = null;
    _cachedUser  = null;
    await _secure.delete(key: AppConstants.tokenKey);
    await _secure.delete(key: AppConstants.userKey);
    if (clearRememberMe) {
      await _prefs?.remove(AppConstants.rememberMeKey);
    }
  }
}
