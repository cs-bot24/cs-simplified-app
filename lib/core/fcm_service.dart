// lib/core/fcm_service.dart
//
// Platform-adaptive FCM service.
//
// Mobile: full FCM initialisation — permission request, channel creation,
//         topic subscription, foreground handler, token registration.
//
// Web:    FCM is skipped entirely for the MVP.
//         The in-app notification feed (NotificationProvider) works on web
//         without any FCM involvement.

import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';
import '../firebase_options.dart';
import '../core/api_client.dart';
import '../core/storage.dart';
import '../models/notification_model.dart';
import '../providers/notification_provider.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// ── Background handler ────────────────────────────────────────────────────────
// MUST be a top-level function (not a method).
// MUST call Firebase.initializeApp() — the isolate has no Flutter binding yet.
// MUST be annotated with @pragma('vm:entry-point').
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  debugPrint('[FCM] background/terminated message: ${message.messageId}');
  // flutter_local_notifications cannot show a notification here on Android
  // because the isolate has no UI context.
  // FCM will show the notification automatically from the `notification` payload
  // as long as the default_notification_channel_id in AndroidManifest.xml
  // matches the channel we created (cs_simplified_channel).
}

class FcmService {
  static final _messaging          = FirebaseMessaging.instance;
  static final _localNotifications = FlutterLocalNotificationsPlugin();

  static const _channelId   = 'cs_simplified_channel';
  static const _channelName = 'CS Simplified Notifications';
  static const _channelDesc =
      'Notifications for new materials, announcements and study reminders';

  static const _androidChannel = AndroidNotificationChannel(
    _channelId,
    _channelName,
    description: _channelDesc,
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );

  // Windows desktop check via defaultTargetPlatform (not dart:io Platform)
  // deliberately — this file is compiled into the web bundle too (guarded
  // by the kIsWeb check below, not by conditional import), and dart:io
  // isn't available there. firebase_options.dart already uses this same
  // API for exactly this reason.
  static bool get _isWindowsDesktop =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  // ── Public entry point ─────────────────────────────────────────────────────

  static Future<void> init() async {
    if (kIsWeb) {
      debugPrint('[FCM] Web platform — FCM initialisation skipped for MVP.');
      return;
    }

    // Windows desktop (desktop audit Part 12): Firebase Core/Messaging have
    // no official Windows support, and main.dart already skips
    // Firebase.initializeApp() entirely on Windows — so nothing below this
    // point (which all assumes an initialized Firebase app) is safe to run
    // here. Local (non-Firebase) notifications are still fully available
    // on Windows via flutter_local_notifications — see
    // _initWindowsLocalNotificationsOnly() and showDownloadComplete() etc.
    // below, which the offline DownloadManager already calls today.
    if (_isWindowsDesktop) {
      await _initWindowsLocalNotificationsOnly();
      return;
    }

    // Register background handler FIRST — before any other Firebase call.
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Request permission (Android 13+ shows a system dialog).
    final settings = await _messaging.requestPermission(
      alert:         true,
      badge:         true,
      sound:         true,
      announcement:  false,
      carPlay:       false,
      criticalAlert: false,
      provisional:   false,
    );
    debugPrint('[FCM] permission: ${settings.authorizationStatus}');

    // Ensure the high-importance notification channel exists on Android.
    // This must match android:value in AndroidManifest.xml meta-data.
    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_androidChannel);

    // Initialise flutter_local_notifications (used for foreground display).
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // On Android, FCM suppresses the heads-up notification when the app is
    // in the foreground. We must show it ourselves via flutter_local_notifications.
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Fetch and register the FCM token.
    await _registerToken();

    // Subscribe to the all_users topic so admin broadcasts reach this device
    // even if the token was never individually registered.
    try {
      await _messaging.subscribeToTopic('all_users');
      debugPrint('[FCM] subscribed to topic: all_users');
    } catch (e) {
      debugPrint('[FCM] topic subscription failed: $e');
    }

    // Keep the token fresh.
    _messaging.onTokenRefresh.listen((newToken) async {
      debugPrint('[FCM] token refreshed');
      await AppStorage.saveFcmToken(newToken);
      try {
        await ApiClient.registerFcmToken(newToken);
      } catch (e) {
        debugPrint('[FCM] token refresh registration failed: $e');
      }
    });

    // Foreground messages — must be shown manually.
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // User tapped a notification while app was backgrounded.
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationOpen);

    // App was launched by tapping a notification (terminated state).
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) _handleNotificationOpen(initialMessage);
  }

  // ── Windows desktop: local notifications only, no Firebase ─────────────────

  /// Called instead of the Firebase init path on Windows. Firebase itself
  /// has no official Windows support, and (see the note below) neither
  /// does the flutter_local_notifications version this project depends
  /// on, so this is currently a no-op beyond logging. `DownloadManager`'s
  /// `FcmService.showDownloadComplete()` / `showDownloadFailed()` /
  /// `showStorageFull()` calls (see lib/services/offline/download_manager.dart)
  /// no-op on Windows too (see `_isWindowsDesktop` guard on each), and are
  /// already wrapped in `.catchError((_) {})` at every call site, so downloads
  /// themselves are unaffected either way.
  ///
  /// NOTE: flutter_local_notifications (the version resolved in
  /// pubspec.lock, 17.2.4) has no Windows platform implementation —
  /// there is no `WindowsInitializationSettings`/`WindowsNotificationDetails`
  /// in this package, and `InitializationSettings`/`NotificationDetails`
  /// have no `windows` parameter. An earlier pass assumed Windows support
  /// that doesn't exist in this dependency, which is what broke
  /// `flutter analyze`. Until a Windows-capable notifications package is
  /// added, local notifications are a no-op on Windows — every
  /// `FcmService.show*()` call site already treats notification failures
  /// as non-fatal (see download_manager.dart's `.catchError((_) {})`), so
  /// this preserves the same "downloads work either way" behavior without
  /// calling into a plugin that has nothing registered for this platform.
  static Future<void> _initWindowsLocalNotificationsOnly() async {
    debugPrint('[FCM] Windows desktop — local notifications skipped '
        '(flutter_local_notifications has no Windows implementation; '
        'Firebase Messaging also skipped: no official Windows support).');
  }

  // ── Token registration ─────────────────────────────────────────────────────

  static Future<void> _registerToken() async {
    try {
      final token = await _messaging.getToken().timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          debugPrint('[FCM] getToken() timed out — likely no connectivity');
          return null;
        },
      );
      debugPrint('[FCM] token: $token');
      if (token != null) {
        await AppStorage.saveFcmToken(token);
        await ApiClient.registerFcmToken(token);
      }
    } catch (e) {
      debugPrint('[FCM] token registration failed: $e');
    }
  }

  // ── Foreground message handler ─────────────────────────────────────────────

  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    if (kIsWeb) return;
    final notification = message.notification;

    // Show the heads-up notification that FCM suppresses in foreground.
    if (notification != null) {
      await _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDesc,
            icon: '@mipmap/ic_launcher',
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
            color: const Color(0xFF6C63FF),
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
      );
    }

    // Also update the in-app notification feed immediately.
    final ctx = navigatorKey.currentContext;
    if (ctx != null && notification != null) {
      final category =
          message.data['category'] as String? ?? 'announcement';
      final newItem = NotificationModel(
        id:        DateTime.now().millisecondsSinceEpoch,
        title:     notification.title ?? '',
        body:      notification.body  ?? '',
        category:  category,
        isRead:    false,
        createdAt: DateTime.now(),
      );
      ctx.read<NotificationProvider>().addLocal(newItem);
    }
  }

  // ── Notification tap handlers ──────────────────────────────────────────────

  static void _handleNotificationOpen(RemoteMessage message) {
    if (kIsWeb) return;
    final ctx = navigatorKey.currentContext;
    if (ctx == null) return;
    ctx.read<NotificationProvider>().fetchNotifications();
  }

  static void _onNotificationTapped(NotificationResponse response) {
    if (kIsWeb) return;
    final ctx = navigatorKey.currentContext;
    if (ctx == null) return;
    ctx.read<NotificationProvider>().fetchNotifications();
  }

  // ── Study reminder (local only) ────────────────────────────────────────────

  static Future<void> showStudyReminder({
    required int id,
    required String title,
    required String body,
  }) async {
    if (kIsWeb || _isWindowsDesktop) return;
    await _localNotifications.show(
      id, title, body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          icon: '@mipmap/ic_launcher',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          color: const Color(0xFF6C63FF),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: false,
          presentSound: true,
        ),
      ),
    );
  }

  // ── Offline download complete (local only) ─────────────────────────────────

  static Future<void> showDownloadComplete({
    required int id,
    required String materialTitle,
  }) async {
    if (kIsWeb || _isWindowsDesktop) return;
    await _localNotifications.show(
      id, 'Download complete', '"$materialTitle" is now available offline.',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          icon: '@mipmap/ic_launcher',
          importance: Importance.low,
          priority: Priority.low,
          color: const Color(0xFF6C63FF),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: false,
          presentSound: false,
        ),
      ),
    );
  }

  static Future<void> showDownloadFailed({required String materialTitle}) async {
    if (kIsWeb || _isWindowsDesktop) return;
    await _localNotifications.show(
      materialTitle.hashCode & 0x7fffffff,
      'Download failed',
      '"$materialTitle" could not be downloaded. Tap to retry.',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId, _channelName,
          channelDescription: _channelDesc,
          icon: '@mipmap/ic_launcher',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          color: const Color(0xFF6C63FF),
        ),
        iOS: const DarwinNotificationDetails(presentAlert: true, presentSound: false),
      ),
    );
  }

  static Future<void> showStorageFull() async {
    if (kIsWeb || _isWindowsDesktop) return;
    await _localNotifications.show(
      999001,
      'Storage full',
      'Your device is out of space. Free up storage to continue downloading.',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId, _channelName,
          channelDescription: _channelDesc,
          icon: '@mipmap/ic_launcher',
          importance: Importance.high,
          priority: Priority.high,
          color: const Color(0xFF6C63FF),
        ),
        iOS: const DarwinNotificationDetails(presentAlert: true, presentSound: true),
      ),
    );
  }

  static Future<void> showUpdateAvailable({required int count}) async {
    if (kIsWeb || _isWindowsDesktop) return;
    await _localNotifications.show(
      999002,
      'Updates available',
      '$count downloaded material${count == 1 ? '' : 's'} ${count == 1 ? 'has' : 'have'} a newer version.',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId, _channelName,
          channelDescription: _channelDesc,
          icon: '@mipmap/ic_launcher',
          importance: Importance.low,
          priority: Priority.low,
          color: const Color(0xFF6C63FF),
        ),
        iOS: const DarwinNotificationDetails(presentAlert: true, presentSound: false),
      ),
    );
  }
}
