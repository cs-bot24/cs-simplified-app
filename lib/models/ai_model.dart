// lib/models/ai_model.dart — Phase 2 + Monetization Readiness
import 'package:flutter/foundation.dart';

enum ExplanationLevel { beginner, intermediate, advanced }

enum AiMode { normal, examPrep, examLesson }

class AiMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final String? subject;        // AI-detected subject (AI messages only)
  final bool isImage;           // true if this question used an image
  final AiMode mode;

  const AiMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.subject,
    this.isImage = false,
    this.mode = AiMode.normal,
  });
}

class AiConversationModel {
  final int id;
  final String question;
  final String response;
  final String? subject;
  final String? mode;
  final DateTime createdAt;

  const AiConversationModel({
    required this.id,
    required this.question,
    required this.response,
    this.subject,
    this.mode,
    required this.createdAt,
  });

  factory AiConversationModel.fromJson(Map<String, dynamic> j) =>
      AiConversationModel(
        id: j['id'],
        question: j['question'],
        response: j['response'],
        subject: j['subject'],
        mode: j['mode'],
        createdAt: DateTime.parse(j['created_at']),
      );
}

/// Full entitlements returned by GET /ai/plan.
///
/// All values default to permissive (true / null) when subscriptions are
/// not enforced, so the app continues working exactly as before.
///
/// When monetization is activated server-side, these values automatically
/// reflect each user's actual plan with no app update required.
class AiPlanInfo {
  // ── System flags ───────────────────────────────────────────────────────────
  final bool   subscriptionsLive;   // true once subscriptions are enforced
  final bool   paymentsLive;        // true once payment gateway is active
  final String effectivePlan;       // "free" | "pro" | "premium"

  // ── Admin override ─────────────────────────────────────────────────────────
  /// True when this user is an admin with lifetime premium override.
  /// Flutter uses this to hide upgrade prompts and show "Admin Premium Access".
  final bool   isAdminOverride;

  // ── AI Tutor ───────────────────────────────────────────────────────────────
  final int?   aiDailyLimit;        // null = unlimited
  final bool   canUseImage;         // image question solving
  final bool   canUseExamPrepMode;  // exam_prep mode in AI Tutor

  // ── AI Lecturer ────────────────────────────────────────────────────────────
  final bool   canUseLecturer;          // always true (chapter gate below)
  final int    freeLecturerChapters;    // chapters available on free plan
  final bool   lecturerChapterGated;    // true when chapter gate is active
  final bool   canTakeLecturerExam;     // final exam requires pro

  // ── Exam Prep AI ───────────────────────────────────────────────────────────
  final bool   canUseExamAiTools;   // practice q, quiz, revision, focus

  // ── Offline ────────────────────────────────────────────────────────────────
  final bool   canUseUnlimitedOffline;
  final int    freeOfflineLimit;

  const AiPlanInfo({
    required this.subscriptionsLive,
    required this.paymentsLive,
    required this.effectivePlan,
    required this.isAdminOverride,
    required this.aiDailyLimit,
    required this.canUseImage,
    required this.canUseExamPrepMode,
    required this.canUseLecturer,
    required this.freeLecturerChapters,
    required this.lecturerChapterGated,
    required this.canTakeLecturerExam,
    required this.canUseExamAiTools,
    required this.canUseUnlimitedOffline,
    required this.freeOfflineLimit,
  });

  /// Permissive defaults — used before the first /ai/plan call resolves,
  /// and as a safe fallback if the call fails.
  factory AiPlanInfo.defaultPermissive() => const AiPlanInfo(
    subscriptionsLive:      false,
    paymentsLive:           false,
    effectivePlan:          'premium',
    isAdminOverride:        false,
    aiDailyLimit:           null,
    canUseImage:            true,
    canUseExamPrepMode:     true,
    canUseLecturer:         true,
    freeLecturerChapters:   3,
    lecturerChapterGated:   false,
    canTakeLecturerExam:    true,
    canUseExamAiTools:      true,
    canUseUnlimitedOffline: true,
    freeOfflineLimit:       5,
  );

  factory AiPlanInfo.fromJson(Map<String, dynamic> j) {
    // Debug: print what the server returned so we can verify gates
    debugPrint('[AiPlanInfo] server response: $j');
    return AiPlanInfo(
      subscriptionsLive:      j['subscriptions_live']       as bool?  ?? false,
      paymentsLive:           j['payments_live']            as bool?  ?? false,
      effectivePlan:          j['effective_plan']           as String? ?? 'premium',
      isAdminOverride:        j['is_admin_override']        as bool?  ?? false,
      aiDailyLimit:           j['ai_daily_limit']           as int?,
      canUseImage:            j['can_use_image_solving']    as bool?  ?? true,
      canUseExamPrepMode:     j['can_use_exam_prep_mode']   as bool?  ?? true,
      canUseLecturer:         j['can_use_lecturer']         as bool?  ?? true,
      freeLecturerChapters:   j['free_lecturer_chapters']   as int?   ?? 3,
      lecturerChapterGated:   j['lecturer_chapter_gated']   as bool?  ?? false,
      canTakeLecturerExam:    j['can_take_lecturer_exam']   as bool?  ?? true,
      canUseExamAiTools:      j['can_use_exam_ai_tools']    as bool?  ?? true,
      canUseUnlimitedOffline: j['can_use_unlimited_offline'] as bool? ?? true,
      freeOfflineLimit:       j['free_offline_limit']       as int?   ?? 5,
    );
  }

  // ── Convenience helpers ────────────────────────────────────────────────────

  /// True when subscriptions are live AND this user is on the free plan.
  bool get isFreeUser =>
      subscriptionsLive && effectivePlan == 'free';

  /// True when subscriptions are live AND this user has a paid plan.
  bool get isPaidUser =>
      subscriptionsLive && effectivePlan != 'free';

  /// Whether chapter [index] (1-based) is locked for this user.
  bool isLecturerChapterLocked(int chapterIndex) {
    if (!lecturerChapterGated) return false;
    if (effectivePlan != 'free') return false;
    return chapterIndex > freeLecturerChapters;
  }
}

