import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/storage.dart';
import '../core/version_check.dart';
import '../core/connectivity_service.dart';
import '../providers/auth_provider.dart';
import '../providers/ai_provider.dart';
import 'home/home_screen.dart';
import 'auth/login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();
    _navigate();
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    await context.read<AuthProvider>().loadFromStorage();
    if (!mounted) return;

    // If user is already logged in (remember me), load their entitlements now
    // so gates apply immediately without waiting for the AI Tutor screen.
    // Fire-and-forget — this must never block getting into the app.
    if (AppStorage.isLoggedIn) {
      context.read<AiProvider>().loadPlan();
    }

    // Skip the network round-trip entirely when offline — the app must
    // open immediately either way, and VersionCheck already has its own
    // timeout, but there's no reason to wait on it at all with no
    // connection.
    if (ConnectivityService.instance.isOnline) {
      await VersionCheck.check(context);
      if (!mounted) return;
    }

    Navigator.pushReplacement(context, MaterialPageRoute(
        builder: (_) => AppStorage.isLoggedIn
            ? const HomeScreen()
            : const LoginScreen()));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.primary,
      body: FadeTransition(
        opacity: _fade,
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 96, height: 96,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(26),
              ),
              child: const Icon(Icons.school_rounded,
                  color: Colors.white, size: 56),
            ),
            const SizedBox(height: 22),
            const Text('CS Simplified',
                style: TextStyle(color: Colors.white, fontSize: 30,
                    fontWeight: FontWeight.bold, letterSpacing: 0.5)),
            const SizedBox(height: 8),
            const Text('Your academic learning hub',
                style: TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 52),
            const SizedBox(width: 24, height: 24,
                child: CircularProgressIndicator(
                    color: Colors.white70, strokeWidth: 2)),
          ]),
        ),
      ),
    );
  }
}
