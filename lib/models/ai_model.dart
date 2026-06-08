// lib/models/ai_model.dart — Phase 2

enum ExplanationLevel { beginner, intermediate, advanced }

enum AiMode { normal, examPrep }

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

class AiPlanInfo {
  final String planName;
  final bool subscriptionsLive;
  final bool canUseImage;
  final bool canUseExamPrep;
  final int? dailyLimit;

  const AiPlanInfo({
    required this.planName,
    required this.subscriptionsLive,
    required this.canUseImage,
    required this.canUseExamPrep,
    this.dailyLimit,
  });

  factory AiPlanInfo.fromJson(Map<String, dynamic> j) => AiPlanInfo(
        planName: j['plan_name'] ?? 'premium',
        subscriptionsLive: j['subscriptions_live'] ?? false,
        canUseImage: j['can_use_image'] ?? true,
        canUseExamPrep: j['can_use_exam_prep'] ?? true,
        dailyLimit: j['daily_limit'],
      );
}
