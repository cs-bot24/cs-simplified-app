// lib/models/ai_model.dart — Phase 2 + Monetization Readiness
import 'package:flutter/foundation.dart';
import 'ai_block.dart';

enum ExplanationLevel { beginner, intermediate, advanced }

enum AiMode { normal, examPrep, examLesson }

class AiMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final String? subject;        // AI-detected subject (AI messages only)
  final bool isImage;           // true if this question used an image
  final AiMode mode;

  /// Server id of the saved exchange this message belongs to. Null until the
  /// server has confirmed it saved the exchange.
  final int? exchangeId;

  /// Set only on a user message that is still being sent or was NOT saved.
  /// Removed once the server confirms the exchange.
  final String? clientMessageId;

  /// True when the server has NOT saved this message (failed / unreachable).
  /// The UI shows "Not sent" with Retry — never "saved".
  final bool failed;

  const AiMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.subject,
    this.isImage = false,
    this.mode = AiMode.normal,
    this.exchangeId,
    this.clientMessageId,
    this.failed = false,
  });

  AiMessage copyWith({
    bool? failed,
    int? exchangeId,
    String? clientMessageId,
    bool clearClientMessageId = false,
  }) =>
      AiMessage(
        text: text,
        isUser: isUser,
        timestamp: timestamp,
        subject: subject,
        isImage: isImage,
        mode: mode,
        exchangeId: exchangeId ?? this.exchangeId,
        clientMessageId:
            clearClientMessageId ? null : (clientMessageId ?? this.clientMessageId),
        failed: failed ?? this.failed,
      );
}

// ── Persistent chats ────────────────────────────────────────────────────────

DateTime _parseServerTime(dynamic v) =>
    DateTime.parse(v as String).toLocal();

AiMode aiModeFromName(String? name) => switch (name) {
      'exam_prep'   => AiMode.examPrep,
      'exam_lesson' => AiMode.examLesson,
      _             => AiMode.normal,
    };

String aiModeToName(AiMode m) => switch (m) {
      AiMode.examPrep   => 'exam_prep',
      AiMode.examLesson => 'exam_lesson',
      AiMode.normal     => 'normal',
    };

/// One row of the history list (GET /ai/chats).
class AiChatSummary {
  final int id;
  final String title;
  final String? lastPreview;
  final int messageCount;
  final DateTime updatedAt;

  const AiChatSummary({
    required this.id,
    required this.title,
    required this.lastPreview,
    required this.messageCount,
    required this.updatedAt,
  });

  AiChatSummary copyWith({String? title}) => AiChatSummary(
        id: id,
        title: title ?? this.title,
        lastPreview: lastPreview,
        messageCount: messageCount,
        updatedAt: updatedAt,
      );

  factory AiChatSummary.fromJson(Map<String, dynamic> j) => AiChatSummary(
        id: (j['id'] as num).toInt(),
        title: (j['title'] as String?) ?? 'New chat',
        lastPreview: j['last_preview'] as String?,
        messageCount: (j['message_count'] as num?)?.toInt() ?? 0,
        updatedAt: _parseServerTime(j['updated_at']),
      );
}

class AiChatPage {
  final List<AiChatSummary> items;
  final bool hasMore;
  const AiChatPage({required this.items, required this.hasMore});

  factory AiChatPage.fromJson(Map<String, dynamic> j) => AiChatPage(
        items: ((j['items'] as List?) ?? const [])
            .map((e) => AiChatSummary.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        hasMore: j['has_more'] == true,
      );
}

/// One saved question + answer pair from the server.
class AiSavedExchange {
  final int id;
  final String question;
  final String response;
  final String? subject;
  final String? mode;
  final bool imageUsed;
  final DateTime createdAt;

  const AiSavedExchange({
    required this.id,
    required this.question,
    required this.response,
    required this.subject,
    required this.mode,
    required this.imageUsed,
    required this.createdAt,
  });

  factory AiSavedExchange.fromJson(Map<String, dynamic> j) => AiSavedExchange(
        id: (j['id'] as num).toInt(),
        question: j['question'] as String,
        response: j['response'] as String,
        subject: j['subject'] as String?,
        mode: j['mode'] as String?,
        imageUsed: j['image_used'] == true,
        createdAt: _parseServerTime(j['created_at']),
      );

  /// The two chat bubbles this exchange is shown as (question, then answer).
  List<AiMessage> toMessages() {
    final m = aiModeFromName(mode);
    final qText = imageUsed
        ? (question == '[image question]' ? '📷 Image question' : '📷 $question')
        : question;
    return [
      AiMessage(
        text: qText,
        isUser: true,
        // 1 ms earlier than the answer so the two bubbles never share a key.
        timestamp: createdAt.subtract(const Duration(milliseconds: 1)),
        isImage: imageUsed,
        mode: m,
        exchangeId: id,
      ),
      AiMessage(
        text: response,
        isUser: false,
        timestamp: createdAt,
        subject: subject,
        mode: m,
        exchangeId: id,
      ),
    ];
  }
}

class AiChatDetail {
  final int id;
  final String title;
  final bool hasMoreBefore;
  final List<AiSavedExchange> messages; // oldest -> newest

  const AiChatDetail({
    required this.id,
    required this.title,
    required this.hasMoreBefore,
    required this.messages,
  });

  factory AiChatDetail.fromJson(Map<String, dynamic> j) => AiChatDetail(
        id: (j['id'] as num).toInt(),
        title: (j['title'] as String?) ?? 'New chat',
        hasMoreBefore: j['has_more_before'] == true,
        messages: ((j['messages'] as List?) ?? const [])
            .map((e) => AiSavedExchange.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

/// A pre-chat Q&A row ("Earlier Questions"): read-only, never a conversation.
class AiEarlierQuestion {
  final int id;
  final String question;
  final String response;
  final DateTime createdAt;

  const AiEarlierQuestion({
    required this.id,
    required this.question,
    required this.response,
    required this.createdAt,
  });

  factory AiEarlierQuestion.fromJson(Map<String, dynamic> j) => AiEarlierQuestion(
        id: (j['id'] as num).toInt(),
        question: j['question'] as String,
        response: j['response'] as String,
        createdAt: _parseServerTime(j['created_at']),
      );
}

class AiEarlierPage {
  final List<AiEarlierQuestion> items;
  final bool hasMore;
  const AiEarlierPage({required this.items, required this.hasMore});

  factory AiEarlierPage.fromJson(Map<String, dynamic> j) => AiEarlierPage(
        items: ((j['items'] as List?) ?? const [])
            .map((e) => AiEarlierQuestion.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        hasMore: j['has_more'] == true,
      );
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

/// Plain-text preview for the history list. Saved answers are JSON "blocks";
/// showing them raw looks broken, so pull out the readable text. Also copes
/// with a preview that was cut off mid-JSON by the server's length limit.
String aiPreviewText(String? raw) {
  final r = (raw ?? '').trim();
  if (r.isEmpty) return '';
  final looksJson = r.startsWith('{') || r.startsWith('```');
  if (!looksJson) return r;

  final parts = <String>[];
  final parsed = AiJsonResponse.tryParse(r);
  if (parsed != null && !parsed.isEmpty) {
    for (final b in parsed.blocks) {
      if (b.type == AiBlockType.heading || b.type == AiBlockType.text) {
        final t = b.text.trim();
        if (t.isNotEmpty) parts.add(t);
      }
    }
  } else {
    final re = RegExp(r'"(?:text|content)"\s*:\s*"((?:[^"\\]|\\.)*)');
    for (final m in re.allMatches(r)) {
      final t = (m.group(1) ?? '')
          .replaceAll(r'\n', ' ')
          .replaceAll(r'\"', '"')
          .replaceAll(r'\\', r'\')
          .trim();
      if (t.isNotEmpty) parts.add(t);
    }
  }
  return parts.join(' - ').replaceAll(RegExp(r'\s+'), ' ').trim();
}
