import 'package:flutter/material.dart';
import '../models/home_model.dart';

/// A compact pill-shaped badge that shows the user's current study streak.
///
/// Shown inline in the home screen header row, next to the notification bell.
/// Uses orange tones to reinforce the fire/energy metaphor without clashing
/// with the blue primary header.
///
/// Zero-streak state shows a neutral "Start today" prompt rather than
/// "🔥 0 Days" which would feel discouraging.
class StreakBadge extends StatelessWidget {
  final StreakModel streak;

  const StreakBadge({super.key, required this.streak});

  @override
  Widget build(BuildContext context) {
    if (streak.currentStreak == 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white12,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text(
          '🔥 Start today',
          style: TextStyle(color: Colors.white70, fontSize: 11),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.25),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orange.withOpacity(0.5), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🔥', style: TextStyle(fontSize: 13)),
          const SizedBox(width: 4),
          Text(
            '${streak.currentStreak} Day${streak.currentStreak == 1 ? '' : 's'}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
