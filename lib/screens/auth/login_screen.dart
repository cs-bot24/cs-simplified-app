import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';
import '../home/home_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool _showPass   = false;
  bool _rememberMe = false;

  @override
  void dispose() { _emailCtrl.dispose(); _passCtrl.dispose(); super.dispose(); }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final ok = await auth.login(
      email: _emailCtrl.text.trim(),
      password: _passCtrl.text,
      rememberMe: _rememberMe,
    );
    if (!mounted) return;
    if (ok) {
      // Fetch notifications immediately so badge is ready when HomeScreen renders
      context.read<NotificationProvider>().fetchNotifications();
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.error ?? 'Login failed'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  void _continueAsGuest() {
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final auth   = context.watch<AuthProvider>();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 48),
                Center(
                  child: Column(children: [
                    Container(
                      width: 80, height: 80,
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: const Icon(Icons.school_rounded, color: Colors.white, size: 44),
                    ),
                    const SizedBox(height: 16),
                    Text('CS Simplified',
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold,
                            color: scheme.primary)),
                    const SizedBox(height: 4),
                    Text('Your academic learning hub',
                        style: TextStyle(fontSize: 14, color: Colors.grey[500])),
                  ]),
                ),
                const SizedBox(height: 48),
                Text('Welcome back',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Sign in to continue',
                    style: TextStyle(color: Colors.grey[500])),
                const SizedBox(height: 28),
                AppTextField(
                  label: 'Email', controller: _emailCtrl,
                  prefixIcon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => v!.contains('@') ? null : 'Enter valid email',
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'Password', controller: _passCtrl,
                  prefixIcon: Icons.lock_outline,
                  obscure: !_showPass,
                  suffix: GestureDetector(
                    onTap: () => setState(() => _showPass = !_showPass),
                    child: Icon(_showPass
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                        size: 20, color: Colors.grey[500]),
                  ),
                  validator: (v) => v!.length >= 6 ? null : 'Min 6 characters',
                ),
                const SizedBox(height: 12),

                // ── Remember Me ──────────────────────────────────────────────
                Row(
                  children: [
                    SizedBox(
                      width: 24, height: 24,
                      child: Checkbox(
                        value: _rememberMe,
                        onChanged: (v) => setState(() => _rememberMe = v ?? false),
                        activeColor: scheme.primary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () => setState(() => _rememberMe = !_rememberMe),
                      child: Text('Remember me',
                          style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                    ),
                  ],
                ),

                const SizedBox(height: 24),
                AppButton(label: 'Sign In', loading: auth.loading,
                    onTap: _login, icon: Icons.login_rounded),
                const SizedBox(height: 14),

                // ── Guest Mode ───────────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _continueAsGuest,
                    icon: const Icon(Icons.explore_outlined),
                    label: const Text('Continue as Guest'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),

                const SizedBox(height: 20),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text("Don't have an account? ",
                      style: TextStyle(color: Colors.grey[500])),
                  GestureDetector(
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const RegisterScreen())),
                    child: Text('Sign Up',
                        style: TextStyle(color: scheme.primary,
                            fontWeight: FontWeight.w600)),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
