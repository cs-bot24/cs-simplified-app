// lib/core/fcm_service.dart
//
// Platform-adaptive FCM service.
//
// Mobile: full FCM initialisation — permission request, channel creation,
//         topic subscription, foreground handler, token registration.
//
// Web:    FCM is skipped entirely for the MVP.
//         Push notifications on web require a VAPID key, a service worker
//         (firebase-messaging-sw.js), and HTTPS. These are post-MVP concerns.
//         The in-app notification feed (NotificationProvider) works on web
//         without any FCM involvement.
//
// All callers use FcmService.init() and FcmService.showStudyReminder() —
// both are safe to call on web (they return immediately without crashing).

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';
import '../core/api_client.dart';
import '../core/storage.dart';
import '../models/notification_model.dart';
import '../providers/notification_provider.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM] background message: ${message.messageId}');
}

class FcmService {
  static final _messaging          = FirebaseMessaging.instance;
  static final _localNotifications = FlutterLocalNotificationsPlugin();

  static const _androidChannel = AndroidNotificationChannel(
    'cs_simplified_channel',
    'CS Simplified Notifications',
    description: 'Notifications for new materials, announcements and study reminders',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );

  static Future<void> init() async {
    // Skip all FCM setup on web — not needed for MVP.
    // The in-app notification feed still works via NotificationProvider.
    if (kIsWeb) {
      debugPrint('[FCM] Web platform — FCM initialisation skipped for MVP.');
      return;
    }

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

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

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_androidChannel);

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

    // Subscribe to all_users topic for global announcements
    try {
      await _messaging.subscribeToTopic('all_users');
      debugPrint('[FCM] subscribed to topic: all_users');
    } catch (e) {
      debugPrint('[FCM] topic subscription failed: $e');
    }

    _messaging.onTokenRefresh.listen((newToken) async {
      debugPrint('[FCM] token refreshed');
      await AppStorage.saveFcmToken(newToken);
      try {
        await ApiClient.registerFcmToken(newToken);
      } catch (e) {
        debugPrint('[FCM] token refresh registration failed: $e');
      }
    });

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationOpen);

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) _handleNotificationOpen(initialMessage);
  }

  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    if (kIsWeb) return;
    final notification = message.notification;
    if (notification == null) return;

    await _localNotifications.show(
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

  // ── Study reminder ────────────────────────────────────────────────────────
  // Safe to call on web — returns immediately without crashing.

  static Future<void> showStudyReminder({
    required int id,
    required String title,
    required String body,
  }) async {
    if (kIsWeb) return; // No local notifications on web for MVP
    await _localNotifications.show(
      id, title, body,
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
