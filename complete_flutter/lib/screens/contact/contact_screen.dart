import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api_client.dart';
import '../../core/constants.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_button.dart';

class ContactScreen extends StatefulWidget {
  const ContactScreen({super.key});
  @override State<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {
  final _subjectCtrl = TextEditingController();
  final _msgCtrl     = TextEditingController();
  final _formKey     = GlobalKey<FormState>();
  String _type  = 'question';
  bool _sending = false;

  @override
  void dispose() { _subjectCtrl.dispose(); _msgCtrl.dispose(); super.dispose(); }

  // ── URL launching ─────────────────────────────────────────────────────────

  Future<void> _launchWhatsApp() async {
    final uri = Uri.parse(AppConstants.adminWhatsApp);
    dev.log('[Contact] Opening WhatsApp: $uri', name: 'ContactScreen');
    await _tryLaunch(uri, fallback: AppConstants.adminWhatsApp);
  }

  Future<void> _launchTelegram() async {
    final uri = Uri.parse(AppConstants.adminTelegram);
    dev.log('[Contact] Opening Telegram: $uri', name: 'ContactScreen');
    await _tryLaunch(uri, fallback: AppConstants.adminTelegram);
  }

  Future<void> _launchEmail() async {
    final uri = Uri(
      scheme: 'mailto',
      path: AppConstants.adminEmail,
      queryParameters: {
        'subject': AppConstants.adminEmailSubjectDefault,
        'body': 'Hi Admin,\n\n',
      },
    );
    dev.log('[Contact] Opening Email: $uri', name: 'ContactScreen');
    await _tryLaunch(uri, fallback: 'mailto:${AppConstants.adminEmail}');
  }

  Future<void> _tryLaunch(Uri uri, {required String fallback}) async {
    try {
      bool launched = false;

      // Try external app first
      if (await canLaunchUrl(uri)) {
        launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      }

      // Fallback: try in-browser
      if (!launched) {
        final fbUri = Uri.parse(fallback);
        if (await canLaunchUrl(fbUri)) {
          launched = await launchUrl(fbUri, mode: LaunchMode.externalApplication);
        }
      }

      if (!launched && mounted) {
        _snack('Application not installed or unable to open link.',
            success: false);
      }
    } catch (e) {
      dev.log('[Contact] Launch error: $e', name: 'ContactScreen');
      if (mounted) _snack('Unable to open link.', success: false);
    }
  }

  // ── In-app message form ───────────────────────────────────────────────────

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _sending = true);
    try {
      await ApiClient.sendContactMessage(
        subject: _subjectCtrl.text.trim(),
        message: _msgCtrl.text.trim(),
        type: _type,
      );
      if (!mounted) return;
      _subjectCtrl.clear();
      _msgCtrl.clear();
      _snack('Message sent! We\'ll get back to you soon.', success: true);
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString(), success: false);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _snack(String msg, {required bool success}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(success ? Icons.check_circle : Icons.error_outline,
            color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(msg)),
      ]),
      backgroundColor: success ? Colors.green : Colors.red,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: Duration(seconds: success ? 3 : 5),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final auth   = context.watch<AuthProvider>();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Contact Admin')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Quick contact ──────────────────────────────────────────────
            const Text('Quick Contact',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 12),

            _ContactCard(
              icon: Icons.chat_rounded,
              color: const Color(0xFF25D366),
              title: 'WhatsApp',
              subtitle: 'Chat admin directly — fast support',
              onTap: _launchWhatsApp,
            ),
            const SizedBox(height: 10),
            _ContactCard(
              icon: Icons.send_rounded,
              color: const Color(0xFF0088CC),
              title: 'Telegram',
              subtitle: 'Message on Telegram',
              onTap: _launchTelegram,
            ),
            const SizedBox(height: 10),
            _ContactCard(
              icon: Icons.email_rounded,
              color: Colors.orange,
              title: 'Email',
              subtitle: AppConstants.adminEmail,
              onTap: _launchEmail,
            ),

            const SizedBox(height: 28),

            // ── In-app message ─────────────────────────────────────────────
            const Text('Send a Message',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 4),
            Text('We usually respond within 24 hours',
                style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            const SizedBox(height: 16),

            if (auth.isLoggedIn) ...[
              // Type selector
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _TypeChip(label: '❓ Question', value: 'question',
                        selected: _type == 'question',
                        onTap: () => setState(() => _type = 'question')),
                    const SizedBox(width: 8),
                    _TypeChip(label: '🐛 Bug Report', value: 'bug',
                        selected: _type == 'bug',
                        onTap: () => setState(() => _type = 'bug')),
                    const SizedBox(width: 8),
                    _TypeChip(label: '📚 Request Material',
                        value: 'material_request',
                        selected: _type == 'material_request',
                        onTap: () => setState(() => _type = 'material_request')),
                    const SizedBox(width: 8),
                    _TypeChip(label: '💬 Other', value: 'other',
                        selected: _type == 'other',
                        onTap: () => setState(() => _type = 'other')),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Form(
                key: _formKey,
                child: Column(children: [
                  TextFormField(
                    controller: _subjectCtrl,
                    decoration: InputDecoration(
                      labelText: 'Subject',
                      prefixIcon: const Icon(Icons.subject_rounded),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (v) =>
                        v!.trim().isEmpty ? 'Enter a subject' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _msgCtrl,
                    maxLines: 5,
                    maxLength: 1000,
                    decoration: InputDecoration(
                      labelText: 'Message',
                      alignLabelWithHint: true,
                      prefixIcon: const Padding(
                        padding: EdgeInsets.only(bottom: 80),
                        child: Icon(Icons.message_rounded),
                      ),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (v) => v!.trim().length < 10
                        ? 'Min 10 characters'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  AppButton(
                    label: 'Send Message',
                    loading: _sending,
                    onTap: _send,
                    icon: Icons.send_rounded,
                  ),
                ]),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.orange.withOpacity(0.2)),
                ),
                child: Row(children: [
                  const Icon(Icons.info_outline, color: Colors.orange),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Sign in to send a direct message',
                            style: TextStyle(fontWeight: FontWeight.w600,
                                fontSize: 13)),
                        const SizedBox(height: 2),
                        Text('Use WhatsApp, Telegram or Email above '
                            'to contact admin without signing in.',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[600])),
                      ],
                    ),
                  ),
                ]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Reusable contact card ─────────────────────────────────────────────────────

class _ContactCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title, subtitle;
  final VoidCallback onTap;

  const _ContactCard({
    required this.icon, required this.color,
    required this.title, required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.06),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        splashColor: color.withOpacity(0.15),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Container(
                width: 46, height: 46,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: color)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey[500])),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 14, color: color.withOpacity(0.5)),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label, value;
  final bool selected;
  final VoidCallback onTap;
  const _TypeChip({required this.label, required this.value,
      required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? scheme.primary : scheme.primary.withOpacity(0.07),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w500,
                color: selected ? Colors.white : scheme.primary)),
      ),
    );
  }
}
