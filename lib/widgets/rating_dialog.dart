import 'package:flutter/material.dart';

/// Bottom sheet that asks the student to rate a material after reading it.
///
/// Behaviour:
///   • If existingRating is null  → shows "Rate this material" with empty stars
///   • If existingRating is 1–5  → shows "Update your rating" with pre-filled stars
///
/// The student can dismiss with "Maybe later" — no rating is submitted
/// and the PDF closes normally. Dismissal is never punished with a nag
/// on every subsequent open: the rating prompt only shows when the PDF
/// is open for at least 10 seconds, so it stays respectful.
class RatingDialog extends StatefulWidget {
  final int? existingRating;
  final Future<void> Function(int rating) onSubmit;

  const RatingDialog({
    super.key,
    this.existingRating,
    required this.onSubmit,
  });

  @override
  State<RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<RatingDialog> {
  late int? _selected;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.existingRating;
  }

  Future<void> _submit() async {
    if (_selected == null || _submitting) return;
    setState(() => _submitting = true);
    try {
      await widget.onSubmit(_selected!);
      if (mounted) Navigator.of(context).pop(true); // true = submitted
    } catch (_) {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme  = Theme.of(context).colorScheme;
    final isUpdate = widget.existingRating != null;

    return Padding(
      // Ensures the sheet sits above the system gesture bar
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),

            // Heading
            Text(
              isUpdate ? 'Update your rating' : 'How helpful was this?',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isUpdate
                  ? 'You previously rated this material ${widget.existingRating} star${widget.existingRating == 1 ? '' : 's'}.'
                  : 'Your rating helps other students find the best materials.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(height: 28),

            // Star row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final star = i + 1;
                final filled = _selected != null && star <= _selected!;
                return GestureDetector(
                  onTap: () => setState(() => _selected = star),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 150),
                      child: Icon(
                        filled ? Icons.star_rounded : Icons.star_outline_rounded,
                        key: ValueKey(filled),
                        size: 44,
                        color: filled ? Colors.amber[600] : Colors.grey[300],
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 8),

            // Star label
            Text(
              _selected == null
                  ? 'Tap a star to rate'
                  : _starLabel(_selected!),
              style: TextStyle(
                fontSize: 12,
                color: _selected == null
                    ? Colors.grey[400]
                    : Colors.amber[700],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 28),

            // Submit button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _selected == null || _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: scheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        isUpdate ? 'Update Rating' : 'Submit Rating',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 12),

            // Dismiss link
            GestureDetector(
              onTap: () => Navigator.of(context).pop(false),
              child: Text(
                'Maybe later',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[500],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _starLabel(int stars) {
    switch (stars) {
      case 1: return '⭐  Not helpful';
      case 2: return '⭐⭐  Slightly helpful';
      case 3: return '⭐⭐⭐  Helpful';
      case 4: return '⭐⭐⭐⭐  Very helpful';
      case 5: return '⭐⭐⭐⭐⭐  Extremely helpful';
      default: return '';
    }
  }
}
