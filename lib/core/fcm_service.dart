// lib/core/fcm_service.dart
//
// Handles all push notification logic:
//   - Firebase Messaging initialisation
//   - Android 13+ runtime POST_NOTIFICATIONS permission request
//   - Notification channel creation (required Android 8+)
//   - Foreground message display via flutter_local_notifications
//   - Background/terminated message handling
//   - FCM token registration with backend
//
// Key fix: Android 13+ (API 33+) requires POST_NOTIFICATIONS to be both
// declared in AndroidManifest.xml AND requested at runtime via
// FirebaseMessaging.requestPermission(). Without the runtime request,
// the permission dialog never appears and all notifications are silently
// blocked by the OS regardless of the manifest declaration.

import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';
import '../core/api_client.dart';
import '../core/storage.dart';
import '../models/notification_model.dart';
import '../providers/notification_provider.dart';

// Navigator key — used to access providers from FCM handlers that run
// outside of a normal widget build context.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// ── Background / terminated handler ──────────────────────────────────────────
// Must be a top-level function (not a class method).
// Keep lightweight — no UI or provider access available here.
// FCM will show the notification banner automatically for data+notification
// messages when the app is in the background or terminated, as long as
// the correct channel ID is set in AndroidManifest.xml meta-data.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM] background message: ${message.messageId}');
}

class FcmService {
  static final _messaging          = FirebaseMessaging.instance;
  static final _localNotifications = FlutterLocalNotificationsPlugin();

  // Channel ID must match the value in AndroidManifest.xml meta-data:
  // com.google.firebase.messaging.default_notification_channel_id
  static const _androidChannel = AndroidNotificationChannel(
    'cs_simplified_channel',           // ← must match AndroidManifest.xml
    'CS Simplified Notifications',
    description: 'Notifications for new materials, announcements and study reminders',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );

  static Future<void> init() async {
    // 1. Register background handler first — must be done before any
    //    other Firebase Messaging calls.
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 2. Request permission.
    //    On Android 13+ this shows the system permission dialog.
    //    On Android 12 and below this always grants (no dialog).
    //    On iOS this shows the iOS permission dialog.
    final settings = await _messaging.requestPermission(
      alert:         true,
      badge:         true,
      sound:         true,
      announcement:  false,
      carPlay:       false,
      criticalAlert: false,
      provisional:   false,
    );

    debugPrint('[FCM] permission status: ${settings.authorizationStatus}');

    // If the user denied permission, notifications won't show.
    // We still continue — they may grant it later in device settings.
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('[FCM] notification permission denied by user.');
    }

    // 3. Create the Android notification channel.
    //    Must be created before any notification is shown.
    //    Safe to call multiple times — Android ignores duplicate creates.
    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(_androidChannel);

    // 4. Initialise flutter_local_notifications.
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,  // already requested above via FCM
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // 5. Get FCM token and register with backend.
    final token = await _messaging.getToken();
    debugPrint('[FCM] token: $token');
    if (token != null) {
      await AppStorage.saveFcmToken(token);
      try {
        await ApiClient.registerFcmToken(token);
      } catch (e) {
        debugPrint('[FCM] token registration failed: $e');
      }
    }

    // 6. Refresh token when FCM rotates it.
    _messaging.onTokenRefresh.listen((newToken) async {
      debugPrint('[FCM] token refreshed');
      await AppStorage.saveFcmToken(newToken);
      try {
        await ApiClient.registerFcmToken(newToken);
      } catch (e) {
        debugPrint('[FCM] token refresh registration failed: $e');
      }
    });

    // 7. Foreground message handler.
    //    When the app is open and a push arrives:
    //      a) Show a local notification banner (FCM suppresses its own
    //         banner when the app is in the foreground on Android).
    //      b) Insert into NotificationProvider so the badge updates.
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // 8. Handle notification tap when app was in background (not terminated).
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationOpen);

    // 9. Handle notification tap when app was terminated.
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationOpen(initialMessage);
    }
  }

  // ── Foreground message handler ────────────────────────────────────────────

  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('[FCM] foreground message: ${message.messageId}');

    final notification = message.notification;
    if (notification == null) return;

    // Show the system notification banner.
    // FCM does NOT show banners automatically when the app is foregrounded
    // on Android — we must call flutter_local_notifications ourselves.
    await _localNotifications.show(
      // Use a stable int ID so duplicate messages don't stack infinitely.
      // hashCode on the notification object is stable per message.
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          icon: '@mipmap/ic_launcher',
          importance: Importance.high,
          priority: Priority.high,
          // Show notification even when app is in foreground
          playSound: true,
          enableVibration: true,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );

    // Insert into NotificationProvider so badge increments immediately.
    final ctx = navigatorKey.currentContext;
    if (ctx != null) {
      final category = message.data['category'] as String? ?? 'announcement';
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

  // ── Notification tap handler ──────────────────────────────────────────────

  static void _handleNotificationOpen(RemoteMessage message) {
    debugPrint('[FCM] notification opened: ${message.data}');
    // Navigate to notifications screen when user taps the notification.
    // Uses the navigator key to navigate outside of widget context.
    final ctx = navigatorKey.currentContext;
    if (ctx == null) return;
    // Refresh notifications so the tapped item shows as read
    ctx.read<NotificationProvider>().fetchNotifications();
    // Optional: navigate to notifications page
    // Navigator.of(ctx).pushNamed('/notifications');
  }

  static void _onNotificationTapped(NotificationResponse response) {
    debugPrint('[FCM] local notification tapped: ${response.payload}');
    final ctx = navigatorKey.currentContext;
    if (ctx == null) return;
    ctx.read<NotificationProvider>().fetchNotifications();
  }

  // ── Study reminder helper ─────────────────────────────────────────────────
  // Used by the Study Planner to show a local reminder notification.

  static Future<void> showStudyReminder({
    required int id,
    required String title,
    required String body,
  }) async {
    await _localNotifications.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          icon: '@mipmap/ic_launcher',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          // Study reminders use a distinct color
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
}
