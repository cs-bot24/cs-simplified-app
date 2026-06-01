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
import 'providers/home_provider.dart';
import 'providers/offline_provider.dart';
import 'providers/admin_stats_provider.dart';
import 'providers/request_provider.dart';
import 'providers/support_provider.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'core/fcm_service.dart' show navigatorKey;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await AppStorage.init();
  await AppStorage.loadTokenToCache();
  await AppStorage.loadUserToCache();

  await FcmService.init();

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
        ChangeNotifierProvider(create: (_) => HomeProvider()),
        ChangeNotifierProvider(create: (_) => OfflineProvider()),
        ChangeNotifierProvider(create: (_) => AdminStatsProvider()),
        ChangeNotifierProvider(create: (_) => RequestProvider()),
        ChangeNotifierProvider(create: (_) => SupportProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (_, theme, __) => MaterialApp(
          title: 'CS Simplified',
          debugShowCheckedModeBanner: false,
          themeMode: theme.mode,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          // _AppBootstrap replaces SplashScreen as the home widget.
          // It wraps SplashScreen and adds startup/resume badge refresh.
          home: const _AppBootstrap(),
          navigatorKey: navigatorKey,
        ),
      ),
    );
  }
}

/// Thin wrapper around [SplashScreen] that handles two badge requirements:
///
///   1. STARTUP — fetches the unread count immediately after the first frame
///      so the red badge is visible before the user navigates anywhere.
///
///   2. RESUME  — re-fetches whenever the app returns from the background
///      so any announcements sent while the app was backgrounded are reflected.
///
/// Only authenticated users have a valid token; [NotificationProvider] handles
/// 401 responses silently and returns an empty list, so no badge shows for
/// logged-out sessions.
class _AppBootstrap extends StatefulWidget {
  const _AppBootstrap();
  @override
  State<_AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<_AppBootstrap>
    with WidgetsBindingObserver {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshNotifications();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshNotifications();
    }
  }

  void _refreshNotifications() {
    if (!mounted) return;
    context.read<NotificationProvider>().fetchNotifications();
  }

  @override
  Widget build(BuildContext context) => const SplashScreen();
}
