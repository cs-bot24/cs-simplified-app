// FCM Service - Push Notifications
//
// SETUP REQUIRED:
//   1. Add your google-services.json to android/app/
//   2. Add your GoogleService-Info.plist to ios/Runner/
//   3. Run: flutterfire configure
//
// This file initialises Firebase Messaging and handles incoming push
// notifications. It is called from main.dart after Firebase.initializeApp().

import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';
import '../core/api_client.dart';
import '../core/storage.dart';
import '../models/notification_model.dart';
import '../providers/notification_provider.dart';

// The navigator key is used to access the NotificationProvider from the
// FCM foreground handler, which runs outside a widget context.
// It is set in main.dart on the MaterialApp.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Top-level handler for background/terminated state messages.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Keep lightweight — no UI/provider access is possible here.
  debugPrint('FCM background: ${message.messageId}');
}

class FcmService {
  static final _messaging          = FirebaseMessaging.instance;
  static final _localNotifications = FlutterLocalNotificationsPlugin();

  static const _androidChannel = AndroidNotificationChannel(
    'cs_simplified_channel',
    'CS Simplified Notifications',
    description: 'Notifications for new materials and announcements',
    importance: Importance.high,
    playSound: true,
  );

  static Future<void> init() async {
    // Register background handler.
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Request permission (iOS / Android 13+).
    await _messaging.requestPermission(
      alert: true, badge: true, sound: true,
    );

    // Create Android notification channel.
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_androidChannel);

    // Initialise local notifications plugin.
    await _localNotifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );

    // Get and register FCM token.
    final token = await _messaging.getToken();
    if (token != null) {
      await AppStorage.saveFcmToken(token);
      await ApiClient.registerFcmToken(token);
    }

    // Refresh token when FCM rotates it.
    _messaging.onTokenRefresh.listen((newToken) async {
      await AppStorage.saveFcmToken(newToken);
      await ApiClient.registerFcmToken(newToken);
    });

    // ── Foreground message handler ────────────────────────────────────────
    // When the app is open and a push arrives:
    //   1. Show a local notification so the user sees a banner.
    //   2. Insert the item into NotificationProvider so the badge
    //      updates immediately — the user does NOT need to navigate
    //      to the notifications page first.
    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      if (notification == null) return;

      // 1. Show the system notification banner.
      final android = notification.android;
      if (android != null) {
        _localNotifications.show(
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
            ),
          ),
        );
      }

      // 2. Inject into NotificationProvider so the badge increments.
      //    We use the navigator key to reach the provider outside of
      //    a normal widget build context.
      final ctx = navigatorKey.currentContext;
      if (ctx != null) {
        final category = message.data['category'] as String? ?? 'announcement';
        final newItem  = NotificationModel(
          // Use a large unique int from timestamp for the local ID.
          // Negative IDs are reserved for announcement merges in the provider.
          id:        DateTime.now().millisecondsSinceEpoch,
          title:     notification.title ?? '',
          body:      notification.body  ?? '',
          category:  category,
          isRead:    false,
          createdAt: DateTime.now(),
        );
        ctx.read<NotificationProvider>().addLocal(newItem);
      }
    });
  }
}
