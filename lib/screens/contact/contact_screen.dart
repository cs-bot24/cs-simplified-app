import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api_client.dart';
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
  String _type       = 'question';
  bool _sending      = false;

  static const _whatsapp = 'https://wa.me/2348000000000';
  static const _telegram = 'https://t.me/cssimplified';
  static const _email    = 'support@cssimplified.app';

  @override
  void dispose() { _subjectCtrl.dispose(); _msgCtrl.dispose(); super.dispose(); }

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
      _subjectCtrl.clear(); _msgCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(children: [
            Icon(Icons.check_circle, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Message sent! We\'ll get back to you soon.'),
          ]),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final auth   = context.watch<AuthProvider>();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Contact Admin')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          // Quick contact buttons
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.primary.withOpacity(0.06),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Quick Contact',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: _QuickButton(
                    icon: Icons.chat_rounded,
                    label: 'WhatsApp',
                    color: const Color(0xFF25D366),
                    onTap: () => _launch(_whatsapp),
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: _QuickButton(
                    icon: Icons.send_rounded,
                    label: 'Telegram',
                    color: const Color(0xFF0088CC),
                    onTap: () => _launch(_telegram),
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: _QuickButton(
                    icon: Icons.email_rounded,
                    label: 'Email',
                    color: Colors.orange,
                    onTap: () => _launch('mailto:$_email'),
                  )),
                ]),
              ],
            ),
          ),

          const SizedBox(height: 24),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Send a Message',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('We usually respond within 24 hours',
                style: TextStyle(fontSize: 12, color: Colors.grey[500])),
          ),
          const SizedBox(height: 16),

          // Type selector
          if (auth.isLoggedIn) ...[
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
                  _TypeChip(label: '📚 Request Material', value: 'material_request',
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
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (v) => v!.trim().isEmpty ? 'Enter a subject' : null,
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
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (v) => v!.trim().length < 10 ? 'Min 10 characters' : null,
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
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.orange.withOpacity(0.2)),
              ),
              child: const Row(children: [
                Icon(Icons.info_outline, color: Colors.orange),
                SizedBox(width: 12),
                Expanded(
                  child: Text('Sign in to send a message directly to admin.',
                      style: TextStyle(fontSize: 13)),
                ),
              ]),
            ),
          ],
        ]),
      ),
    );
  }
}

class _QuickButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickButton({required this.icon, required this.label,
      required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 6),
          Text(label,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ]),
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
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? scheme.primary : scheme.primary.withOpacity(0.07),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: selected ? Colors.white : scheme.primary)),
      ),
    );
  }
}
