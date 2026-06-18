// lib/screens/auth/forgot_password_screen.dart

import 'package:flutter/material.dart';
import '../../core/api_client.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();
  final _formKey   = GlobalKey<FormState>();
  bool    _loading  = false;
  bool    _sent     = false;
  String? _error;

  static const _kPrimary = Color(0xFF1A3C6E);

  @override
  void dispose() { _emailCtrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });

    try {
      await ApiClient.forgotPassword(_emailCtrl.text.trim());
      if (mounted) setState(() { _sent = true; _loading = false; });
    } on ApiException catch (e) {
      setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      setState(() {
        _error = 'Could not connect. Please check your internet connection.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Forgot Password'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: _sent ? _buildSuccess() : _buildForm(isDark),
      ),
    );
  }

  Widget _buildForm(bool isDark) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),

          // Icon
          Center(
            child: Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: _kPrimary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text('🔑', style: TextStyle(fontSize: 36)),
              ),
            ),
          ),
          const SizedBox(height: 24),

          const Text('Reset Your Password',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(
            'Enter the email address associated with your account and we\'ll '
            'send you a link to reset your password.',
            style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: isDark ? Colors.white60 : Colors.black54),
          ),
          const SizedBox(height: 28),

          // Email field
          TextFormField(
            controller:   _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            autocorrect:  false,
            decoration: InputDecoration(
              labelText:   'Email Address',
              hintText:    'yourname@example.com',
              prefixIcon:  const Icon(Icons.email_outlined),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Email is required';
              if (!v.contains('@') || !v.contains('.')) {
                return 'Please enter a valid email address';
              }
              return null;
            },
          ),

          // Error
          if (_error != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(_error!,
                    style: const TextStyle(color: Colors.red, fontSize: 13))),
              ]),
            ),
          ],

          const SizedBox(height: 24),

          // Submit button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _loading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: _kPrimary.withOpacity(0.4),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              icon: _loading
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.send_rounded),
              label: Text(
                _loading ? 'Sending...' : 'Send Reset Link',
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
          ),

          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Back to Login',
                  style: TextStyle(color: _kPrimary)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccess() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        const SizedBox(height: 40),
        Center(
          child: Container(
            width: 90, height: 90,
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text('📧', style: TextStyle(fontSize: 42)),
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text('Check Your Email',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        Text(
          'We\'ve sent a password reset link to:\n${_emailCtrl.text.trim()}\n\n'
          'Click the link in the email to create a new password. '
          'The link expires in 60 minutes.\n\n'
          'Don\'t see it? Check your spam or junk folder.',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 14,
              height: 1.6,
              color: isDark ? Colors.white60 : Colors.black54),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kPrimary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Back to Login',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          ),
        ),
        const SizedBox(height: 14),
        TextButton(
          onPressed: () => setState(() { _sent = false; _error = null; }),
          child: Text('Try a different email',
              style: TextStyle(
                  color: isDark ? Colors.white54 : Colors.black45,
                  fontSize: 13)),
        ),
      ],
    );
  }
}
