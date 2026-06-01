import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants.dart';
import '../../providers/auth_provider.dart';
import 'support_center_screen.dart';

class ContactScreen extends StatefulWidget {
  const ContactScreen({super.key});
  @override State<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {

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

      if (await canLaunchUrl(uri)) {
        launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      }

      if (!launched) {
        final fbUri = Uri.parse(fallback);
        if (await canLaunchUrl(fbUri)) {
          launched = await launchUrl(fbUri, mode: LaunchMode.externalApplication);
        }
      }

      if (!launched && mounted) {
        _snack('Application not installed or unable to open link.', success: false);
      }
    } catch (e) {
      dev.log('[Contact] Launch error: $e', name: 'ContactScreen');
      if (mounted) _snack('Unable to open link.', success: false);
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

            // ── Quick Contact ──────────────────────────────────────────────
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

            // ── Support Center ─────────────────────────────────────────────
            const Text('Support Center',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 4),
            Text('Track your requests and get admin replies',
                style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            const SizedBox(height: 14),

            if (auth.isLoggedIn)
              _ContactCard(
                icon: Icons.support_agent_rounded,
                color: scheme.primary,
                title: 'Open Support Center',
                subtitle: 'Submit tickets, track status, read replies',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const SupportCenterScreen()),
                ),
              )
            else
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
                        const Text('Sign in to use the Support Center',
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
