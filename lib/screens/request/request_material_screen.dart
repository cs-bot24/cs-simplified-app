import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/request_provider.dart';

/// Simple form screen for students to request missing materials.
/// Accessible from the Browse screen FAB and from Profile screen.
class RequestMaterialScreen extends StatefulWidget {
  const RequestMaterialScreen({super.key});

  @override
  State<RequestMaterialScreen> createState() => _RequestMaterialScreenState();
}

class _RequestMaterialScreenState extends State<RequestMaterialScreen> {
  final _formKey     = GlobalKey<FormState>();
  final _courseCtrl  = TextEditingController();
  final _topicCtrl   = TextEditingController();
  final _messageCtrl = TextEditingController();

  @override
  void dispose() {
    _courseCtrl.dispose();
    _topicCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    debugPrint('[RequestMaterial] submitting...');
    debugPrint('[RequestMaterial] course=${_courseCtrl.text.trim()} topic=${_topicCtrl.text.trim()}');

    final success = await context.read<RequestProvider>().submit(
      courseName: _courseCtrl.text.trim(),
      topic: _topicCtrl.text.trim(),
      message: _messageCtrl.text.trim().isEmpty
          ? null
          : _messageCtrl.text.trim(),
    );

    debugPrint('[RequestMaterial] result: success=$success error=${context.read<RequestProvider>().error}');

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(children: [
            Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Request submitted! We\'ll upload it soon.'),
          ]),
          backgroundColor: Colors.green[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RequestProvider>();
    final scheme   = Theme.of(context).colorScheme;

    return Scaffold(
      body: Column(children: [
        // Header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 56, 24, 28),
          decoration: BoxDecoration(
            color: scheme.primary,
            borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(28)),
          ),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
            const Text('📋', style: TextStyle(fontSize: 32)),
            const SizedBox(height: 8),
            const Text('Request a Material',
                style: TextStyle(color: Colors.white, fontSize: 22,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text(
                'Can\'t find what you need? Let us know.',
                style: TextStyle(color: Colors.white70, fontSize: 13)),
          ]),
        ),

        // Form
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('Course Name *'),
                  const SizedBox(height: 6),
                  _field(
                    ctrl: _courseCtrl,
                    hint: 'e.g. Data Structures, COSC301',
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Please enter a course name'
                        : null,
                  ),
                  const SizedBox(height: 20),

                  _label('Topic / Material Needed *'),
                  const SizedBox(height: 6),
                  _field(
                    ctrl: _topicCtrl,
                    hint: 'e.g. Past questions, Lecture notes, Tutorials',
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Please describe what you need'
                        : null,
                  ),
                  const SizedBox(height: 20),

                  _label('Additional Message (optional)'),
                  const SizedBox(height: 6),
                  _field(
                    ctrl: _messageCtrl,
                    hint: 'Any extra context that might help...',
                    maxLines: 4,
                  ),
                  const SizedBox(height: 32),

                  if (provider.error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(provider.error!,
                          style: const TextStyle(
                              color: Colors.red, fontSize: 13)),
                    ),
                    const SizedBox(height: 16),
                  ],

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: provider.submitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: scheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: provider.submitting
                          ? const SizedBox(width: 20, height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Text('Submit Request',
                              style: TextStyle(fontSize: 15,
                                  fontWeight: FontWeight.w600)),
                    ),
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
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 14),
        ),
      );
}
