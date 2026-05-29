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
import '../core/api_client.dart';
import '../core/storage.dart';

/// Top-level handler for background/terminated state messages.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background processing - keep lightweight
  debugPrint('FCM background: ${message.messageId}');
}

class FcmService {
  static final _messaging = FirebaseMessaging.instance;
  static final _localNotifications = FlutterLocalNotificationsPlugin();

  static const _androidChannel = AndroidNotificationChannel(
    'cs_simplified_channel',
    'CS Simplified Notifications',
    description: 'Notifications for new materials and announcements',
    importance: Importance.high,
    playSound: true,
  );

  static Future<void> init() async {
    // Register background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Request permission (iOS / Android 13+)
    await _messaging.requestPermission(
      alert: true, badge: true, sound: true,
    );

    // Create Android notification channel
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_androidChannel);

    // Init local notifications
    await _localNotifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );

    // Get and register FCM token
    final token = await _messaging.getToken();
    if (token != null) {
      await AppStorage.saveFcmToken(token);
      await ApiClient.registerFcmToken(token);
    }

    // Token refresh
    _messaging.onTokenRefresh.listen((newToken) async {
      await AppStorage.saveFcmToken(newToken);
      await ApiClient.registerFcmToken(newToken);
    });

    // Foreground messages → show local notification
    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      final android = message.notification?.android;
      if (notification != null && android != null) {
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
    });
  }
}
