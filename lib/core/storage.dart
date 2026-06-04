// lib/core/storage.dart
// ─────────────────────────────────────────────────────────────────────────────
// CHANGES vs original:
//
//   1. SECURITY FIX — JWT token and user JSON are now stored in
//      flutter_secure_storage (Android Keystore-backed encryption) instead
//      of plaintext SharedPreferences.  On rooted devices, SharedPreferences
//      is world-readable by any app.  flutter_secure_storage wraps
//      EncryptedSharedPreferences on Android (API 23+), which derives an AES
//      key from the device Keystore that cannot be extracted even by root.
//
//   2. SYNC COMPATIBILITY — SecureStorage is async-only, but getToken() is
//      called synchronously from ApiClient._headers().  We solve this with
//      in-memory caches (_cachedToken, _cachedUser) that are populated once
//      at startup by the two new loaders: loadTokenToCache() and
//      loadUserToCache().  Call both in main() after AppStorage.init().
//
//   3. Non-sensitive values (RememberMe flag, FCM token, notification cache)
//      stay in SharedPreferences — they are not security-sensitive and
//      SharedPreferences has better performance for frequently-read values.
//
// REQUIRED CHANGES IN main.dart (see comments there):
//   await AppStorage.init();
//   await AppStorage.loadTokenToCache();   ← NEW
//   await AppStorage.loadUserToCache();    ← NEW
// ─────────────────────────────────────────────────────────────────────────────

import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'constants.dart';

class AppStorage {
  static SharedPreferences? _prefs;

  /// FlutterSecureStorage with Android Keystore encryption.
  /// encryptedSharedPreferences: true wraps EncryptedSharedPreferences
  /// (API 23+), which is the strongest available option on Android.
  static const _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      // Use the default accessibility (unlocked device).  Change to
      // IOSAccessibility.first_unlock if background access is needed.
      accessibility: KeychainAccessibility.unlocked_this_device,
    ),
  );

  // ── In-memory caches ──────────────────────────────────────────────────────
  // The ApiClient calls getToken() synchronously from within every request
  // header builder.  Since SecureStorage reads are async, we load the token
  // into memory once at app startup and keep it in sync on every write/delete.

  static String? _cachedToken;
  static String? _cachedUser;

  // ── Initialisation ────────────────────────────────────────────────────────

  /// Initialise SharedPreferences.  Call first, before the cache loaders.
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Load the JWT token from secure storage into the in-memory cache.
  /// Call once in main() after init().
  static Future<void> loadTokenToCache() async {
    _cachedToken = await _secure.read(key: AppConstants.tokenKey);
  }

  /// Load the user JSON from secure storage into the in-memory cache.
  /// Call once in main() after init().
  static Future<void> loadUserToCache() async {
    _cachedUser = await _secure.read(key: AppConstants.userKey);
  }

  // ── Auth Token ────────────────────────────────────────────────────────────

  /// Persist the JWT token in secure storage and update the in-memory cache.
  static Future<void> saveToken(String token) async {
    _cachedToken = token;
    await _secure.write(key: AppConstants.tokenKey, value: token);
  }

  /// Synchronous read from in-memory cache.
  /// Guaranteed to be populated after loadTokenToCache() is called at startup,
  /// and kept current by saveToken() and logout().
  static String? getToken() => _cachedToken;

  // ── User JSON ─────────────────────────────────────────────────────────────

  /// Persist the user JSON in secure storage and update the in-memory cache.
  static Future<void> saveUser(String json) async {
    _cachedUser = json;
    await _secure.write(key: AppConstants.userKey, value: json);
  }

  /// Synchronous read from the in-memory cache (populated at startup).
  static String? getUser() => _cachedUser;

  /// True when a JWT is present in the cache.
  static bool get isLoggedIn => _cachedToken != null;

  // ── Remember Me (non-sensitive — stays in SharedPreferences) ─────────────

  static Future<void> saveRememberMe(bool value) async =>
      await _prefs?.setBool(AppConstants.rememberMeKey, value);

  static bool get rememberMe =>
      _prefs?.getBool(AppConstants.rememberMeKey) ?? false;

  // ── FCM Token (non-sensitive) ─────────────────────────────────────────────

  static Future<void> saveFcmToken(String token) async =>
      await _prefs?.setString(AppConstants.fcmTokenKey, token);

  static String? getFcmToken() => _prefs?.getString(AppConstants.fcmTokenKey);

  // ── Notification cache (non-sensitive) ───────────────────────────────────

  static Future<void> saveNotifications(String json) async =>
      await _prefs?.setString('cached_notifications', json);

  static String? getNotifications() =>
      _prefs?.getString('cached_notifications');

  // ── Generic key-value (for reply-seen timestamps etc.) ───────────────────

  static Future<void> setString(String key, String value) async =>
      await _prefs?.setString(key, value);

  static String? getString(String key) => _prefs?.getString(key);

  static Future<void> removeKey(String key) async =>
      await _prefs?.remove(key);

  // ── Logout ────────────────────────────────────────────────────────────────

  /// Clear the auth token and user from both secure storage and the cache.
  /// If clearRememberMe is true, also remove the "stay signed in" preference.
  static Future<void> logout({bool clearRememberMe = false}) async {
    // Clear in-memory caches immediately so synchronous callers (like
    // ApiClient.getToken()) see the logged-out state right away.
    _cachedToken = null;
    _cachedUser  = null;

    // Then flush secure storage asynchronously.
    await _secure.delete(key: AppConstants.tokenKey);
    await _secure.delete(key: AppConstants.userKey);

    if (clearRememberMe) {
      await _prefs?.remove(AppConstants.rememberMeKey);
    }
  }
}
