import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';
import '../home/home_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _nameCtrl  = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool _showPass   = false;

  @override
  void dispose() {
    _nameCtrl.dispose(); _emailCtrl.dispose(); _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final ok = await auth.register(
      fullName: _nameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      password: _passCtrl.text,
    );
    if (!mounted) return;
    if (ok) {
      context.read<NotificationProvider>().fetchNotifications();
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => const HomeScreen()));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.error ?? 'Registration failed'),
            backgroundColor: Theme.of(context).colorScheme.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth   = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Create Account'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Join CS Simplified',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Create your free account',
                    style: TextStyle(color: Colors.grey[500])),
                const SizedBox(height: 32),
                AppTextField(
                  label: 'Full Name', controller: _nameCtrl,
                  prefixIcon: Icons.person_outline,
                  validator: (v) => v!.length >= 2 ? null : 'Enter your full name',
                ),
                const SizedBox(height: 16),
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
                const SizedBox(height: 32),
                AppButton(
                  label: 'Create Account', loading: auth.loading,
                  onTap: _register, icon: Icons.person_add_rounded,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
