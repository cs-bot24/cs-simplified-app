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
import 'providers/home_provider.dart';   // Phase 1.5A
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';

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
        // Phase 1.5A — registered at root so streak ping survives navigation
        ChangeNotifierProvider(create: (_) => HomeProvider()),
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
