import 'package:flutter/material.dart';

/// A prominent banner card on the home screen promoting exam preparation.
///
/// The warm amber gradient contrasts with the blue primary header, making
/// the banner visually distinct and giving it a sense of urgency without
/// being alarming. The brain emoji and count give students an immediate
/// sense of what's available.
///
/// Tapping it navigates to SearchScreen with "exam" pre-filled so students
/// immediately see all exam-related materials. This uses Navigator.push
/// rather than switching the bottom nav tab — the pushed SearchScreen is
/// an independent instance with a pre-filled query.
class ExamPrepBanner extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const ExamPrepBanner({
    super.key,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFB45309), Color(0xFFD97706)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFD97706).withOpacity(0.30),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            // Left: icon in a translucent circle
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text('🧠', style: TextStyle(fontSize: 26)),
              ),
            ),
            const SizedBox(width: 14),

            // Middle: text block
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Exam Prep',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    count == 1
                        ? '1 resource ready for you'
                        : '$count resources ready for you',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            // Right: arrow
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
