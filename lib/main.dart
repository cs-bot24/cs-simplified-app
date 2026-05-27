// lib/main.dart
// ─────────────────────────────────────────────────────────────────────────────
// CHANGES vs original:
//
//   Added two cache-loader calls after AppStorage.init():
//     • AppStorage.loadTokenToCache()  — primes the synchronous getToken()
//     • AppStorage.loadUserToCache()   — primes the synchronous getUser()
//
//   These are required by the new secure-storage implementation in storage.dart.
//   Without them, getToken() would return null on the first request even when
//   the user is still logged in from a previous session (because the secure
//   store hasn't been read into memory yet).
//
//   Everything else is unchanged.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'core/storage.dart';
import 'core/fcm_service.dart';
import 'providers/auth_provider.dart';
import 'providers/academic_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/notification_provider.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 1. Init SharedPreferences (must come first).
  await AppStorage.init();

  // 2. NEW: Load the JWT token and user JSON from secure storage into the
  //    in-memory caches.  This makes AppStorage.getToken() and getUser()
  //    return the correct values synchronously for the rest of the session.
  await AppStorage.loadTokenToCache();
  await AppStorage.loadUserToCache();

  // 3. Init FCM (reads the cached token to register it with the backend).
  await FcmService.init();

  // 4. Restore saved theme preference before first paint.
  final themeProvider = ThemeProvider();
  await themeProvider.loadTheme();

  runApp(CsSimplifiedApp(themeProvider: themeProvider));
}

class CsSimplifiedApp extends StatelessWidget {
  final ThemeProvider themeProvider;
  const CsSimplifiedApp({super.key, required this.themeProvider});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => AcademicProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (_, theme, __) => MaterialApp(
          title: 'CS Simplified',
          debugShowCheckedModeBanner: false,
          themeMode: theme.mode,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          home: const SplashScreen(),
        ),
      ),
    );
  }
}
