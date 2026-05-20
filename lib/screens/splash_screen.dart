import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../core/storage.dart';
import '../providers/auth_provider.dart';
import 'home/home_screen.dart';
import 'auth/login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>    _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();
    _navigate();
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    await context.read<AuthProvider>().loadFromStorage();
    if (!mounted) return;
    final isLoggedIn = AppStorage.isLoggedIn;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
            isLoggedIn ? const HomeScreen() : const LoginScreen(),
      ),
    );
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(AppConstants.primaryColorValue),
      body: FadeTransition(
        opacity: _fade,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 90, height: 90,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(Icons.school_rounded,
                    color: Colors.white, size: 52),
              ),
              const SizedBox(height: 20),
              const Text(AppConstants.appName,
                  style: TextStyle(
                      color: Colors.white, fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5)),
              const SizedBox(height: 8),
              const Text(AppConstants.appTagline,
                  style: TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 48),
              const SizedBox(
                width: 24, height: 24,
                child: CircularProgressIndicator(
                    color: Colors.white70, strokeWidth: 2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
