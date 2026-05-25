import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_button.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});
  @override State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _msgCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  int _rating    = 0;
  String _type   = 'general';
  bool _sending  = false;

  @override
  void dispose() { _msgCtrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a rating'),
            behavior: SnackBarBehavior.floating),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    setState(() => _sending = true);
    try {
      await ApiClient.submitFeedback(
        rating: _rating,
        message: _msgCtrl.text.trim(),
        type: _type,
      );
      if (!mounted) return;
      _msgCtrl.clear();
      setState(() { _rating = 0; _type = 'general'; });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(children: [
            Icon(Icons.favorite_rounded, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Thank you for your feedback!'),
          ]),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth   = context.watch<AuthProvider>();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Feedback')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [scheme.primary, scheme.primary.withOpacity(0.7)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.rate_review_rounded, color: Colors.white, size: 32),
                  SizedBox(height: 10),
                  Text('Share Your Thoughts',
                      style: TextStyle(color: Colors.white, fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  Text('Your feedback helps us improve CS Simplified for everyone.',
                      style: TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Star rating
            const Text('How would you rate the app?',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final star = i + 1;
                return GestureDetector(
                  onTap: () => setState(() => _rating = star),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: AnimatedScale(
                      scale: _rating >= star ? 1.2 : 1.0,
                      duration: const Duration(milliseconds: 150),
                      child: Icon(
                        _rating >= star ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: _rating >= star ? Colors.amber : Colors.grey[400],
                        size: 40,
                      ),
                    ),
                  ),
                );
              }),
            ),
            if (_rating > 0) ...[
              const SizedBox(height: 8),
              Center(
                child: Text(
                  ['', 'Poor', 'Fair', 'Good', 'Great', 'Excellent!'][_rating],
                  style: TextStyle(
                      color: _rating >= 4 ? Colors.green : Colors.orange,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Type
            const Text('Feedback Type',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: [
                _TypeChip(label: '💬 General', value: 'general',
                    selected: _type == 'general',
                    onTap: () => setState(() => _type = 'general')),
                _TypeChip(label: '✨ Feature Request', value: 'feature',
                    selected: _type == 'feature',
                    onTap: () => setState(() => _type = 'feature')),
                _TypeChip(label: '🐛 Bug Report', value: 'bug',
                    selected: _type == 'bug',
                    onTap: () => setState(() => _type = 'bug')),
                _TypeChip(label: '❤️ Appreciation', value: 'appreciation',
                    selected: _type == 'appreciation',
                    onTap: () => setState(() => _type = 'appreciation')),
              ],
            ),

            const SizedBox(height: 20),

            Form(
              key: _formKey,
              child: TextFormField(
                controller: _msgCtrl,
                maxLines: 5,
                maxLength: 1000,
                decoration: InputDecoration(
                  labelText: 'Your message',
                  hintText: 'Tell us what you think, suggest features, or report issues...',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) => v!.trim().length < 5 ? 'Please write at least 5 characters' : null,
              ),
            ),

            const SizedBox(height: 20),

            if (auth.isLoggedIn)
              AppButton(
                label: 'Submit Feedback',
                loading: _sending,
                onTap: _submit,
                icon: Icons.send_rounded,
              )
            else
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withOpacity(0.2)),
                ),
                child: const Row(children: [
                  Icon(Icons.info_outline, color: Colors.orange),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text('Sign in to submit feedback',
                        style: TextStyle(fontSize: 13)),
                  ),
                ]),
              ),
          ],
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
        duration: const Duration(milliseconds: 180),
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
