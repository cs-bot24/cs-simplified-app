// lib/widgets/premium_gate.dart
//
// Reusable widget shown when a feature is locked behind a premium plan.
//
// Usage:
//   if (entitlements.isLecturerChapterLocked(chapterIndex)) {
//     return PremiumGate(feature: PremiumFeature.lecturerChapters);
//   }
//
// When SUBSCRIPTIONS_ENFORCED = False (current state), entitlements always
// return permissive values so this widget is NEVER shown to anyone.
// It is purely infrastructure for when monetization is activated.

import 'package:flutter/material.dart';
import '../screens/payments/upgrade_screen.dart';

/// Which feature is locked — controls the copy shown in the gate widget.
enum PremiumFeature {
  lecturerChapters,
  lecturerExam,
  aiTutorUnlimited,
  aiImageSolving,
  examAiTools,
  offlineUnlimited,
}

class PremiumGate extends StatelessWidget {
  final PremiumFeature feature;
  final VoidCallback?  onUpgradeTap;   // null = show coming-soon snackbar

  const PremiumGate({
    super.key,
    required this.feature,
    this.onUpgradeTap,
  });

  // ── Copy per feature ─────────────────────────────────────────────────────

  String get _emoji {
    switch (feature) {
      case PremiumFeature.lecturerChapters:    return '🎓';
      case PremiumFeature.lecturerExam:        return '📝';
      case PremiumFeature.aiTutorUnlimited:    return '🤖';
      case PremiumFeature.aiImageSolving:      return '📷';
      case PremiumFeature.examAiTools:         return '🧠';
      case PremiumFeature.offlineUnlimited:    return '📥';
    }
  }

  String get _title {
    switch (feature) {
      case PremiumFeature.lecturerChapters:    return 'Unlock All Chapters';
      case PremiumFeature.lecturerExam:        return 'Unlock Final Exam';
      case PremiumFeature.aiTutorUnlimited:    return 'Unlimited AI Tutor';
      case PremiumFeature.aiImageSolving:      return 'AI Image Solver';
      case PremiumFeature.examAiTools:         return 'AI Exam Tools';
      case PremiumFeature.offlineUnlimited:    return 'Unlimited Offline';
    }
  }

  String get _description {
    switch (feature) {
      case PremiumFeature.lecturerChapters:
        return 'You\'ve completed your free chapters. Upgrade to Pro to '
            'continue learning and unlock the full course.';
      case PremiumFeature.lecturerExam:
        return 'The final exam is a Pro feature. Upgrade to test your '
            'knowledge and earn your course completion.';
      case PremiumFeature.aiTutorUnlimited:
        return 'You\'ve reached your daily question limit. Upgrade to Pro '
            'for unlimited AI Tutor access every day.';
      case PremiumFeature.aiImageSolving:
        return 'Snap a photo of any question and get an instant AI answer. '
            'Available on Pro and Premium plans.';
      case PremiumFeature.examAiTools:
        return 'Practice questions, quizzes, revision notes, and focus areas '
            'are Pro features. Upgrade before your exam.';
      case PremiumFeature.offlineUnlimited:
        return 'You\'ve reached your offline download limit. Upgrade to Pro '
            'for unlimited offline access — study anywhere.';
    }
  }

  String get _ctaLabel => 'Upgrade to Pro';

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final scheme  = Theme.of(context).colorScheme;
    const accent  = Color(0xFF6C63FF);   // consistent premium purple

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accent.withOpacity(isDark ? 0.20 : 0.08),
            accent.withOpacity(isDark ? 0.10 : 0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withOpacity(0.25)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Lock icon + emoji
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                width: 68, height: 68,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(_emoji,
                      style: const TextStyle(fontSize: 30)),
                ),
              ),
              Container(
                width: 24, height: 24,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_rounded,
                    color: Colors.white, size: 13),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Text(_title,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface)),

          const SizedBox(height: 8),

          Text(_description,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: isDark ? Colors.white60 : Colors.black54)),

          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: onUpgradeTap ?? () => _showComingSoon(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.star_rounded, size: 18),
              label: Text(_ctaLabel,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),

          const SizedBox(height: 10),

          Text('Tap above to see Pro plans',
              style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white38 : Colors.black38)),
        ],
      ),
    );
  }

  void _showComingSoon(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const UpgradeScreen()),
    );
  }
}


/// Inline version — shown as a small locked row inside a list,
/// e.g. for chapter lock indicators in the AI Lecturer drawer.
class PremiumChapterLockBadge extends StatelessWidget {
  final String message;
  const PremiumChapterLockBadge({super.key, this.message = 'Pro'});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF6C63FF).withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: const Color(0xFF6C63FF).withOpacity(0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.lock_rounded,
            size: 10, color: Color(0xFF6C63FF)),
        const SizedBox(width: 4),
        Text(message,
            style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Color(0xFF6C63FF))),
      ]),
    );
  }
}
