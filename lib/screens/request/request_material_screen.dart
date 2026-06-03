import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/support_provider.dart';
import '../../widgets/app_button.dart';

/// Student form to request a material from admin.
/// Rebuilt on top of the SupportProvider / support_tickets infrastructure.
class RequestMaterialScreen extends StatefulWidget {
  const RequestMaterialScreen({super.key});
  @override State<RequestMaterialScreen> createState() =>
      _RequestMaterialScreenState();
}

class _RequestMaterialScreenState extends State<RequestMaterialScreen> {
  final _formKey     = GlobalKey<FormState>();
  final _titleCtrl   = TextEditingController();
  final _courseCtrl  = TextEditingController();
  final _detailsCtrl = TextEditingController();
  bool _submitting   = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _courseCtrl.dispose();
    _detailsCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    // Build a combined message: optionally include course code + details
    final course  = _courseCtrl.text.trim();
    final details = _detailsCtrl.text.trim();
    final parts   = <String>[];
    if (course.isNotEmpty)  parts.add('Course: $course');
    if (details.isNotEmpty) parts.add(details);
    final message = parts.join('\n');

    final err = await context.read<SupportProvider>().createMaterialRequest(
      title:   _titleCtrl.text.trim(),
      message: message,
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (err == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Row(children: [
          Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
          SizedBox(width: 8),
          Expanded(child: Text('Request submitted successfully.')),
        ]),
        backgroundColor: Colors.green[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ));
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.error_outline, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(err)),
        ]),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 5),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Column(children: [
        // ── Coloured header ────────────────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 56, 24, 28),
          decoration: BoxDecoration(
            color: scheme.primary,
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.arrow_back_rounded,
                    color: Colors.white, size: 20),
              ),
            ),
            const SizedBox(height: 16),
            const Text('📚', style: TextStyle(fontSize: 32)),
            const SizedBox(height: 8),
            const Text('Request a Material',
                style: TextStyle(color: Colors.white, fontSize: 22,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text("Can't find what you need? Let us know.",
                style: TextStyle(color: Colors.white70, fontSize: 13)),
          ]),
        ),

        // ── Form ───────────────────────────────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Material Title
                  _label('Material Title *'),
                  const SizedBox(height: 6),
                  _field(
                    ctrl: _titleCtrl,
                    hint: 'e.g. MTH 104 Past Questions',
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Title is required' : null,
                  ),
                  const SizedBox(height: 20),

                  // Course Code (optional)
                  _label('Course Code (optional)'),
                  const SizedBox(height: 6),
                  _field(
                    ctrl: _courseCtrl,
                    hint: 'e.g. CSC 201',
                  ),
                  const SizedBox(height: 20),

                  // Additional Details (optional)
                  _label('Additional Details (optional)'),
                  const SizedBox(height: 6),
                  _field(
                    ctrl: _detailsCtrl,
                    hint: 'e.g. Need past questions from 2021–2024.',
                    maxLines: 4,
                  ),
                  const SizedBox(height: 32),

                  AppButton(
                    label: 'Submit Request',
                    loading: _submitting,
                    onTap: _submit,
                    icon: Icons.send_rounded,
                  ),
                ],
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _label(String text) => Text(text,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600));

  Widget _field({
    required TextEditingController ctrl,
    required String hint,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) =>
      TextFormField(
        controller: ctrl,
        maxLines: maxLines,
        textCapitalization: TextCapitalization.sentences,
        validator: validator,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
          filled: true,
          fillColor: Theme.of(context).cardColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      );
}
