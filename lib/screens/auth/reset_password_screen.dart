// lib/screens/auth/reset_password_screen.dart
//
// Shown when the user taps the reset link in their email.
// The deep-link delivers the token via the route argument.
//
// Deep-link format:  cssimplified://reset-password?token=<token>
// Web format:        https://cssimplified.app/reset-password?token=<token>

import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import 'login_screen.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String token;
  const ResetPasswordScreen({super.key, required this.token});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _passCtrl    = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _formKey     = GlobalKey<FormState>();

  bool    _loading      = false;
  bool    _verifying    = true;
  bool    _tokenValid   = false;
  bool    _obscure      = true;
  bool    _obscureConf  = true;
  bool    _success      = false;
  String? _error;
  String? _userEmail;

  static const _kPrimary = Color(0xFF1A3C6E);

  @override
  void initState() {
    super.initState();
    _verifyToken();
  }

  @override
  void dispose() {
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _verifyToken() async {
    try {
      final data = await ApiClient.verifyResetToken(widget.token);
      if (mounted) {
        setState(() {
          _tokenValid = true;
          _userEmail  = data['email'] as String?;
          _verifying  = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _verifying = false; });
    } catch (_) {
      if (mounted) setState(() {
        _error    = 'Could not verify reset link. Please try again.';
        _verifying = false;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });

    try {
      await ApiClient.resetPassword(
        token:       widget.token,
        newPassword: _passCtrl.text,
      );
      if (mounted) setState(() { _success = true; _loading = false; });
    } on ApiException catch (e) {
      setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      setState(() {
        _error   = 'Could not reset password. Please try again.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reset Password'),
        centerTitle: true,
        automaticallyImplyLeading: !_success,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: _verifying
            ? _buildVerifying()
            : _success
                ? _buildSuccess(isDark)
                : !_tokenValid
                    ? _buildInvalidToken(isDark)
                    : _buildForm(isDark),
      ),
    );
  }

  Widget _buildVerifying() => const Center(
    child: Padding(
      padding: EdgeInsets.only(top: 80),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        CircularProgressIndicator(),
        SizedBox(height: 16),
        Text('Verifying reset link…',
            style: TextStyle(color: Colors.grey)),
      ]),
    ),
  );

  Widget _buildInvalidToken(bool isDark) => Column(
    children: [
      const SizedBox(height: 40),
      const Center(
        child: Text('❌', style: TextStyle(fontSize: 56)),
      ),
      const SizedBox(height: 20),
      const Text('Link Invalid or Expired',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
      const SizedBox(height: 12),
      Text(
        _error ??
            'This reset link is invalid or has expired.\n'
            'Reset links are only valid for 60 minutes.',
        textAlign: TextAlign.center,
        style: TextStyle(
            fontSize: 14,
            height: 1.5,
            color: isDark ? Colors.white60 : Colors.black54),
      ),
      const SizedBox(height: 32),
      SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          ),
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
    ],
  );

  Widget _buildForm(bool isDark) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Center(
            child: Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: _kPrimary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text('🔒', style: TextStyle(fontSize: 36)),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Create New Password',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          if (_userEmail != null)
            Text('For: $_userEmail',
                style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white54 : Colors.black45)),
          const SizedBox(height: 24),

          // New password
          TextFormField(
            controller:  _passCtrl,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText:  'New Password',
              hintText:   'At least 6 characters',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                icon: Icon(_obscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Password is required';
              if (v.length < 6) return 'Password must be at least 6 characters';
              return null;
            },
          ),
          const SizedBox(height: 14),

          // Confirm password
          TextFormField(
            controller:  _confirmCtrl,
            obscureText: _obscureConf,
            decoration: InputDecoration(
              labelText:  'Confirm New Password',
              hintText:   'Enter password again',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                icon: Icon(_obscureConf
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _obscureConf = !_obscureConf),
              ),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Please confirm your password';
              if (v != _passCtrl.text) return 'Passwords do not match';
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
                  : const Icon(Icons.check_rounded),
              label: Text(
                _loading ? 'Resetting...' : 'Reset Password',
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccess(bool isDark) => Column(
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
            child: Text('✅', style: TextStyle(fontSize: 42)),
          ),
        ),
      ),
      const SizedBox(height: 24),
      const Text('Password Reset!',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
      const SizedBox(height: 12),
      Text(
        'Your password has been reset successfully.\n'
        'You can now log in with your new password.',
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
          onPressed: () => Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (_) => false,
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: _kPrimary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
          child: const Text('Go to Login',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        ),
      ),
    ],
  );
}
