import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/storage.dart';
import 'providers/auth_provider.dart';
import 'providers/academic_provider.dart';
import 'providers/theme_provider.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppStorage.init();
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
