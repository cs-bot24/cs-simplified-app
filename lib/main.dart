import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'core/storage.dart';
import 'core/fcm_service.dart';
import 'core/connectivity_service.dart';
import 'providers/auth_provider.dart';
import 'providers/academic_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/home_provider.dart';
import 'providers/offline_provider.dart';
import 'providers/admin_stats_provider.dart';
import 'providers/support_provider.dart';
import 'providers/leaderboard_provider.dart';
import 'providers/achievement_provider.dart';
import 'providers/ai_provider.dart';
import 'providers/study_planner_provider.dart';
import 'widgets/offline_mode_banner.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'core/fcm_service.dart' show navigatorKey;
import 'providers/lecturer_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Must be ready before anything else checks connectivity (offline
  // banner, requireInternet() gates, provider cache fallbacks).
  await ConnectivityService.instance.initialize();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await AppStorage.init();
  await AppStorage.loadTokenToCache();
  await AppStorage.loadUserToCache();

  final themeProvider = ThemeProvider();
  await themeProvider.loadTheme();

  runApp(CsSimplifiedApp(themeProvider: themeProvider));

  // Push-notification setup (FCM token fetch + backend registration) makes
  // real network calls that can hang for a long time — up to a minute or
  // more — with no connectivity. This must NEVER block the first frame;
  // the app has to be usable immediately regardless of network state.
  // Fire-and-forget: if it's offline, this just quietly finishes late
  // (or fails) once connectivity returns.
  unawaited(FcmService.init());
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
        ChangeNotifierProvider(create: (_) => SupportProvider()),
        ChangeNotifierProvider(create: (_) => LeaderboardProvider()),
        ChangeNotifierProvider(create: (_) => AchievementProvider()),
        ChangeNotifierProvider(create: (_) => AiProvider()),
        ChangeNotifierProvider(create: (_) => LecturerProvider()),
        ChangeNotifierProvider(create: (_) => StudyPlannerProvider()),
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
          builder: (context, child) => OfflineModeBanner(child: child!),
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
      _refreshStudyPlanner();
      _wireAuthCallbacks();
    });
  }

  /// Wire up login/logout callbacks so entitlements refresh immediately
  /// on every account switch — no app restart required.
  void _wireAuthCallbacks() {
    if (!mounted) return;
    final auth    = context.read<AuthProvider>();
    final ai      = context.read<AiProvider>();
    final planner = context.read<StudyPlannerProvider>();

    auth.onLoginSuccess = () async {
      // Reload plan entitlements for the newly logged-in user
      await ai.loadPlan();
      // Reload today's study sessions for the new user
      planner.refresh();
    };

    auth.onLogoutSuccess = () async {
      // Clear cached entitlements — next user starts fresh with defaultPermissive
      // until their /ai/plan call resolves
      ai.clearPlan();
      planner.clear();
    };
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
      _refreshStudyPlanner(newDayOnly: true);
    }
  }

  void _refreshNotifications() {
    if (!mounted) return;
    context.read<NotificationProvider>().fetchNotifications();
  }

  void _refreshStudyPlanner({bool newDayOnly = false}) {
    if (!mounted) return;
    final planner = context.read<StudyPlannerProvider>();
    if (newDayOnly) {
      planner.refreshIfNewDay();
    } else {
      planner.refresh();
    }
  }

  @override
  Widget build(BuildContext context) => const SplashScreen();
}
