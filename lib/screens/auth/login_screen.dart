import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';
import 'register_screen.dart';
import '../home/home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool _showPass   = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final ok = await auth.login(
      email: _emailCtrl.text.trim(),
      password: _passCtrl.text,
    );
    if (!mounted) return;
    if (ok) {
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => const HomeScreen()));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.error ?? 'Login failed'),
            backgroundColor: const Color(AppConstants.errorColorValue)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 48),
                // Logo & title
                Center(
                  child: Column(children: [
                    Container(
                      width: 72, height: 72,
                      decoration: BoxDecoration(
                        color: const Color(AppConstants.primaryColorValue),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(Icons.school_rounded,
                          color: Colors.white, size: 40),
                    ),
                    const SizedBox(height: 16),
                    const Text('CS Simplified',
                        style: TextStyle(
                            fontSize: 26, fontWeight: FontWeight.bold,
                            color: Color(AppConstants.primaryColorValue))),
                    const SizedBox(height: 4),
                    const Text('Your academic learning hub',
                        style: TextStyle(
                            fontSize: 14,
                            color: Color(AppConstants.textLightValue))),
                  ]),
                ),
                const SizedBox(height: 48),
                const Text('Welcome back',
                    style: TextStyle(fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(AppConstants.textDarkValue))),
                const SizedBox(height: 4),
                const Text('Sign in to continue',
                    style: TextStyle(
                        color: Color(AppConstants.textLightValue))),
                const SizedBox(height: 28),
                AppTextField(
                  label: 'Email',
                  controller: _emailCtrl,
                  prefixIcon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) =>
                      v!.contains('@') ? null : 'Enter a valid email',
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'Password',
                  controller: _passCtrl,
                  prefixIcon: Icons.lock_outline,
                  obscure: !_showPass,
                  suffix: GestureDetector(
                    onTap: () => setState(() => _showPass = !_showPass),
                    child: Icon(_showPass
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                        size: 20,
                        color: const Color(AppConstants.textLightValue)),
                  ),
                  validator: (v) =>
                      v!.length >= 6 ? null : 'Min 6 characters',
                ),
                const SizedBox(height: 28),
                AppButton(
                  label: 'Sign In',
                  loading: auth.loading,
                  onTap: _login,
                  icon: Icons.login_rounded,
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Don't have an account? ",
                        style: TextStyle(
                            color: Color(AppConstants.textLightValue))),
                    GestureDetector(
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(
                              builder: (_) => const RegisterScreen())),
                      child: const Text('Sign Up',
                          style: TextStyle(
                              color: Color(AppConstants.primaryColorValue),
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
