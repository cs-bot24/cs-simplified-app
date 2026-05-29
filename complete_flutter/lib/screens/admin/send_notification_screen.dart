import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../widgets/app_button.dart';

class SendNotificationScreen extends StatefulWidget {
  const SendNotificationScreen({super.key});
  @override State<SendNotificationScreen> createState() => _SendNotificationScreenState();
}

class _SendNotificationScreenState extends State<SendNotificationScreen> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl  = TextEditingController();
  final _formKey   = GlobalKey<FormState>();
  String _category = 'announcement';
  bool _sending    = false;

  static const _presets = [
    {'title': '📚 New Material Uploaded', 'body': 'A new study material has been added. Check it out!', 'cat': 'material'},
    {'title': '📢 Important Announcement', 'body': 'Please read the latest announcement from admin.', 'cat': 'announcement'},
    {'title': '🔧 Server Maintenance', 'body': 'Brief maintenance scheduled. The app may be slow.', 'cat': 'system'},
    {'title': '⏰ Exam Reminder', 'body': 'Exams are coming up soon. Start preparing now!', 'cat': 'announcement'},
  ];

  @override
  void dispose() { _titleCtrl.dispose(); _bodyCtrl.dispose(); super.dispose(); }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _sending = true);
    try {
      await ApiClient.sendAdminNotification(
        title: _titleCtrl.text.trim(),
        body: _bodyCtrl.text.trim(),
        category: _category,
      );
      if (!mounted) return;
      _titleCtrl.clear(); _bodyCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(children: [
            Icon(Icons.check_circle, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Notification sent to all users!'),
          ]),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'),
            backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Send Notification')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Preset messages
            const Text('Quick Templates',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 10),
            ...List.generate(_presets.length, (i) {
              final p = _presets[i];
              return GestureDetector(
                onTap: () => setState(() {
                  _titleCtrl.text = p['title']!;
                  _bodyCtrl.text  = p['body']!;
                  _category       = p['cat']!;
                }),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: scheme.primary.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: scheme.primary.withOpacity(0.15)),
                  ),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(p['title']!,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        const SizedBox(height: 2),
                        Text(p['body']!, style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ]),
                    ),
                    Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey[400]),
                  ]),
                ),
              );
            }),

            const SizedBox(height: 24),
            const Text('Custom Notification',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 12),

            // Category
            Row(
              children: [
                _CatChip(label: '📢 Announcement', value: 'announcement',
                    selected: _category == 'announcement',
                    onTap: () => setState(() => _category = 'announcement')),
                const SizedBox(width: 8),
                _CatChip(label: '📚 Material', value: 'material',
                    selected: _category == 'material',
                    onTap: () => setState(() => _category = 'material')),
                const SizedBox(width: 8),
                _CatChip(label: '⚙️ System', value: 'system',
                    selected: _category == 'system',
                    onTap: () => setState(() => _category = 'system')),
              ],
            ),
            const SizedBox(height: 14),

            Form(
              key: _formKey,
              child: Column(children: [
                TextFormField(
                  controller: _titleCtrl,
                  decoration: InputDecoration(
                    labelText: 'Notification Title',
                    prefixIcon: const Icon(Icons.title_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (v) => v!.trim().isEmpty ? 'Enter a title' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _bodyCtrl,
                  maxLines: 4,
                  maxLength: 300,
                  decoration: InputDecoration(
                    labelText: 'Message Body',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (v) => v!.trim().isEmpty ? 'Enter a message' : null,
                ),
                const SizedBox(height: 20),
                AppButton(
                  label: 'Send to All Users',
                  loading: _sending,
                  onTap: _send,
                  icon: Icons.campaign_rounded,
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _CatChip extends StatelessWidget {
  final String label, value;
  final bool selected;
  final VoidCallback onTap;
  const _CatChip({required this.label, required this.value,
      required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? scheme.primary : scheme.primary.withOpacity(0.07),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w500,
                color: selected ? Colors.white : scheme.primary)),
      ),
    );
  }
}
