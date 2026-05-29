import 'package:flutter/material.dart';
import '../models/home_model.dart';

/// Displays the daily motivational quote with a subtle left border accent.
///
/// Intentionally understated — the quote should feel like a whisper on
/// the home screen, not a shout. It uses italic text, muted background,
/// and a thin primary-colored left border as its only visual identity.
class QuoteCard extends StatelessWidget {
  final QuoteModel quote;

  const QuoteCard({super.key, required this.quote});

  @override
  Widget build(BuildContext context) {
    final scheme      = Theme.of(context).colorScheme;
    final isDark      = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.04)
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border(
          left: BorderSide(color: scheme.primary, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '"${quote.quoteText}"',
            style: TextStyle(
              fontSize: 13,
              fontStyle: FontStyle.italic,
              height: 1.55,
              color: isDark ? Colors.white70 : Colors.grey[700],
            ),
          ),
          if (quote.author != null) ...[
            const SizedBox(height: 6),
            Text(
              '— ${quote.author}',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white38 : Colors.grey[500],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
