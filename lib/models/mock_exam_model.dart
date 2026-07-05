// lib/models/mock_exam_model.dart
//
// AI Mock Exam System — Phase 1: CBT Engine models.

class MockExamConfig {
  final String       courseCode;
  final String       courseTitle;
  final bool         hasMaterial;
  final int          sourceCount;
  final List<int>    questionCountOptions;
  final List<String> difficultyOptions;
  final Map<String, int> estimatedMinutes;   // "10" -> 15, "20" -> 30, "50" -> 75
  final bool         hasActiveAttempt;
  final int?         activeAttemptId;

  // Phase 4/5 — Premium tier
  final bool  isPremium;
  final bool  untimedPractice;   // Phase 5 — Practice Mode (no timer + hints)
  final bool  challengeMode;
  final bool  lecturerStyle;
  final bool  aiExplanations;
  final bool  readinessPrediction;
  final bool  advancedAnalytics;
  final bool  unlimitedHistory;
  final int?  monthlyLimit;
  final int   monthlyUsed;
  final int?  monthlyRemaining;

  const MockExamConfig({
    required this.courseCode,
    required this.courseTitle,
    required this.hasMaterial,
    required this.sourceCount,
    required this.questionCountOptions,
    required this.difficultyOptions,
    required this.estimatedMinutes,
    this.hasActiveAttempt = false,
    this.activeAttemptId,
    this.isPremium = true,
    this.untimedPractice = true,
    this.challengeMode = true,
    this.lecturerStyle = true,
    this.aiExplanations = true,
    this.readinessPrediction = true,
    this.advancedAnalytics = true,
    this.unlimitedHistory = true,
    this.monthlyLimit,
    this.monthlyUsed = 0,
    this.monthlyRemaining,
  });

  factory MockExamConfig.fromJson(Map<String, dynamic> j) => MockExamConfig(
    courseCode:  j['course_code']  as String,
    courseTitle: j['course_title'] as String,
    hasMaterial: j['has_material'] as bool? ?? false,
    sourceCount: (j['source_count'] as num?)?.toInt() ?? 0,
    questionCountOptions: List<num>.from(j['question_count_options'] as List? ?? [10, 20, 50])
        .map((n) => n.toInt()).toList(),
    difficultyOptions: List<String>.from(
        j['difficulty_options'] as List? ?? ['easy', 'medium', 'hard']),
    estimatedMinutes: Map<String, int>.from(
        (j['estimated_minutes'] as Map? ?? {}).map(
            (k, v) => MapEntry(k.toString(), (v as num).toInt()))),
    hasActiveAttempt: j['has_active_attempt'] as bool? ?? false,
    isPremium:            j['is_premium'] as bool? ?? true,
    untimedPractice:      j['untimed_practice'] as bool? ?? true,
    challengeMode:        j['challenge_mode'] as bool? ?? true,
    lecturerStyle:        j['lecturer_style'] as bool? ?? true,
    aiExplanations:       j['ai_explanations'] as bool? ?? true,
    readinessPrediction:  j['readiness_prediction'] as bool? ?? true,
    advancedAnalytics:    j['advanced_analytics'] as bool? ?? true,
    unlimitedHistory:     j['unlimited_history'] as bool? ?? true,
    monthlyLimit:         (j['monthly_limit'] as num?)?.toInt(),
    monthlyUsed:          (j['monthly_used'] as num?)?.toInt() ?? 0,
    monthlyRemaining:     (j['monthly_remaining'] as num?)?.toInt(),
    activeAttemptId:  (j['active_attempt_id'] as num?)?.toInt(),
  );
}

class MockExamQuestion {
  final int          id;
  final String       type;          // mcq | true_false | fill_blank
  final String       question;
  final List<String> options;
  final dynamic      correctAnswer; // int (mcq/true_false) or String (fill_blank)
  final String       topic;
  final String       difficulty;

  dynamic selectedAnswer;   // mutable — student's current pick
  String? hint;             // mutable — Phase 5, fetched on demand (Practice Mode)

  MockExamQuestion({
    required this.id,
    required this.type,
    required this.question,
    required this.options,
    required this.correctAnswer,
    required this.topic,
    required this.difficulty,
    this.selectedAnswer,
    this.hint,
  });

  bool get isAnswered => selectedAnswer != null;

  bool get isCorrect {
    if (selectedAnswer == null) return false;
    if (type == 'fill_blank') {
      return selectedAnswer.toString().trim().toLowerCase() ==
          correctAnswer.toString().trim().toLowerCase();
    }
    return selectedAnswer == correctAnswer;
  }

  factory MockExamQuestion.fromJson(Map<String, dynamic> j) => MockExamQuestion(
    id:            (j['id'] as num).toInt(),
    type:          j['type'] as String? ?? 'mcq',
    question:      j['question'] as String,
    options:       List<String>.from(j['options'] as List),
    correctAnswer: j['correct_answer'],
    topic:         j['topic'] as String? ?? '',
    difficulty:    j['difficulty'] as String? ?? 'medium',
    hint:          j['hint'] as String?,
  );
}

enum QuestionStatus { notVisited, visited, answered, flagged }

class MockExamAttempt {
  final int                     attemptId;
  final String                  courseCode;
  final String                  courseTitle;
  final String                  difficulty;
  final String                  mode;   // practice | exam | challenge (Phase 5)
  final bool                    timerEnabled;
  final int                     questionCount;    // full planned count
  int                            generatedCount;   // how many questions actually exist so far
  final int                     durationSeconds;
  int                            secondsRemaining;
  String                        status;   // in_progress | submitted | abandoned
  final List<MockExamQuestion>  questions;
  final Set<int>                visited;
  final Set<int>                flagged;
  final bool                    usedCachedExam;
  final bool                    lecturerStyleUsed;
  final DateTime                startedAt;
  double?                       scorePercent;
  int?                          correctCount;
  Map<String, dynamic>?         perTopic;

  MockExamAttempt({
    required this.attemptId,
    required this.courseCode,
    required this.courseTitle,
    required this.difficulty,
    this.mode = 'exam',
    this.timerEnabled = true,
    required this.questionCount,
    int? generatedCount,
    required this.durationSeconds,
    required this.secondsRemaining,
    required this.status,
    required this.questions,
    required this.visited,
    required this.flagged,
    required this.usedCachedExam,
    this.lecturerStyleUsed = false,
    required this.startedAt,
    this.scorePercent,
    this.correctCount,
    this.perTopic,
  }) : generatedCount = generatedCount ?? questions.length;

  bool get isChallengeMode => mode == 'challenge';
  bool get isPracticeMode  => mode == 'practice';   // untimed + hints + immediate feedback
  bool get isExamMode      => mode == 'exam';       // timed, no hints, feedback after submit

  /// Phase 4 — Challenge Mode generates the second half of questions
  /// adaptively; true once every planned question has been generated.
  bool get hasMoreToGenerate => generatedCount < questionCount;

  factory MockExamAttempt.fromJson(Map<String, dynamic> j) {
    final questions = ((j['questions'] as List?) ?? [])
        .map((q) => MockExamQuestion.fromJson(q as Map<String, dynamic>))
        .toList();
    final answers = Map<String, dynamic>.from(j['answers'] as Map? ?? {});
    for (final q in questions) {
      if (answers.containsKey(q.id.toString())) {
        q.selectedAnswer = answers[q.id.toString()];
      }
    }
    return MockExamAttempt(
      attemptId:        (j['attempt_id'] as num).toInt(),
      courseCode:       j['course_code'] as String,
      courseTitle:      j['course_title'] as String,
      difficulty:       j['difficulty'] as String,
      mode:             j['mode'] as String? ?? 'exam',
      timerEnabled:     j['timer_enabled'] as bool? ?? true,
      questionCount:    (j['question_count'] as num).toInt(),
      generatedCount:   (j['generated_count'] as num?)?.toInt() ?? questions.length,
      durationSeconds:  (j['duration_seconds'] as num).toInt(),
      secondsRemaining: (j['seconds_remaining'] as num).toInt(),
      status:           j['status'] as String,
      questions:        questions,
      visited:          Set<int>.from(List<num>.from(j['visited'] as List? ?? [])
          .map((n) => n.toInt())),
      flagged:          Set<int>.from(List<num>.from(j['flagged'] as List? ?? [])
          .map((n) => n.toInt())),
      usedCachedExam:   j['used_cached_exam'] as bool? ?? false,
      lecturerStyleUsed: j['lecturer_style_used'] as bool? ?? false,
      startedAt:        DateTime.tryParse(j['started_at'] as String? ?? '') ?? DateTime.now(),
      scorePercent:     (j['score_percent'] as num?)?.toDouble(),
      correctCount:     (j['correct_count'] as num?)?.toInt(),
      perTopic:         j['per_topic'] as Map<String, dynamic>?,
    );
  }

  int get answeredCount => questions.where((q) => q.isAnswered).length;

  QuestionStatus statusFor(int questionId) {
    if (flagged.contains(questionId)) return QuestionStatus.flagged;
    final q = questions.firstWhere((q) => q.id == questionId);
    if (q.isAnswered) return QuestionStatus.answered;
    if (visited.contains(questionId)) return QuestionStatus.visited;
    return QuestionStatus.notVisited;
  }
}

class MockExamExplanation {
  final String correctAnswer;
  final String simpleExplanation;
  final String whyIncorrect;
  final String keyConcept;

  const MockExamExplanation({
    required this.correctAnswer,
    required this.simpleExplanation,
    required this.whyIncorrect,
    required this.keyConcept,
  });

  factory MockExamExplanation.fromJson(Map<String, dynamic> j) => MockExamExplanation(
    correctAnswer:     j['correct_answer'] as String? ?? '',
    simpleExplanation: j['simple_explanation'] as String? ?? '',
    whyIncorrect:      j['why_incorrect'] as String? ?? '',
    keyConcept:        j['key_concept'] as String? ?? '',
  );
}

/// Per-question grading outcome shown in the Phase 2 results review.
class GradedQuestion {
  final int                    id;
  final String                 topic;
  final String                 type;
  final String                 difficulty;
  final String                 question;
  final List<String>           options;
  final dynamic                selectedAnswer;
  final dynamic                correctAnswer;
  final String                 status;   // correct | wrong | partially_correct | skipped
  final MockExamExplanation?   explanation;

  const GradedQuestion({
    required this.id,
    required this.topic,
    required this.type,
    this.difficulty = 'medium',
    required this.question,
    required this.options,
    required this.selectedAnswer,
    required this.correctAnswer,
    required this.status,
    this.explanation,
  });

  factory GradedQuestion.fromJson(Map<String, dynamic> j) => GradedQuestion(
    id:             (j['id'] as num).toInt(),
    topic:          j['topic'] as String? ?? 'General',
    type:           j['type'] as String? ?? 'mcq',
    difficulty:     j['difficulty'] as String? ?? 'medium',
    question:       j['question'] as String? ?? '',
    options:        List<String>.from(j['options'] as List? ?? []),
    selectedAnswer: j['selected_answer'],
    correctAnswer:  j['correct_answer'],
    status:         j['status'] as String? ?? 'wrong',
    explanation:    j['explanation'] != null
        ? MockExamExplanation.fromJson(j['explanation'] as Map<String, dynamic>)
        : null,
  );
}

class WeakTopic {
  final String topic;
  final double correct;
  final int    total;
  final double percent;
  final bool   isWeak;

  const WeakTopic({
    required this.topic,
    required this.correct,
    required this.total,
    required this.percent,
    required this.isWeak,
  });

  factory WeakTopic.fromJson(Map<String, dynamic> j) => WeakTopic(
    topic:   j['topic'] as String,
    correct: (j['correct'] as num).toDouble(),
    total:   (j['total'] as num).toInt(),
    percent: (j['percent'] as num).toDouble(),
    isWeak:  j['is_weak'] as bool? ?? false,
  );
}

/// Full Phase 2 AI-graded review — returned by both the /submit call and the
/// /review re-fetch call, so the results screen can render from either.
class Achievement {
  final String code;
  final String title;
  final String emoji;
  final String description;
  final bool   unlocked;
  final DateTime? unlockedAt;
  final int    progress;
  final int    target;

  const Achievement({
    required this.code,
    required this.title,
    required this.emoji,
    required this.description,
    required this.unlocked,
    this.unlockedAt,
    required this.progress,
    required this.target,
  });

  factory Achievement.fromJson(Map<String, dynamic> j) => Achievement(
    code:        j['code'] as String,
    title:       j['title'] as String,
    emoji:       j['emoji'] as String? ?? '🏅',
    description: j['description'] as String? ?? '',
    unlocked:    j['unlocked'] as bool? ?? false,
    unlockedAt:  j['unlocked_at'] != null ? DateTime.tryParse(j['unlocked_at'] as String) : null,
    progress:    (j['progress'] as num?)?.toInt() ?? 0,
    target:      (j['target'] as num?)?.toInt() ?? 1,
  );
}

class Celebration {
  final bool celebrate;
  final String? reason;   // ninety_plus | big_improvement | null
  const Celebration({this.celebrate = false, this.reason});

  factory Celebration.fromJson(Map<String, dynamic> j) => Celebration(
    celebrate: j['celebrate'] as bool? ?? false,
    reason:    j['reason'] as String?,
  );
}

class MockExamReview {
  final int                  attemptId;
  final String                courseCode;
  final String                courseTitle;
  final String                status;
  final String                grade;
  final double                scorePercent;
  final int                   correctCount;
  final int                   wrongCount;
  final int                   partiallyCorrectCount;
  final int                   skippedCount;
  final int                   total;
  final int                   timeUsedSeconds;
  final double                avgTimePerQuestionSeconds;
  bool                        explanationsReady;
  final bool                  aiExplanationsLocked;   // Phase 4 — free tier
  final List<WeakTopic>       weakTopics;
  List<GradedQuestion>        questions;
  final bool                  autoSubmitted;
  final List<Achievement>     newlyUnlocked;   // Phase 5
  final Celebration           celebration;     // Phase 5

  MockExamReview({
    required this.attemptId,
    required this.courseCode,
    required this.courseTitle,
    required this.status,
    required this.grade,
    required this.scorePercent,
    required this.correctCount,
    required this.wrongCount,
    required this.partiallyCorrectCount,
    required this.skippedCount,
    required this.total,
    required this.timeUsedSeconds,
    required this.avgTimePerQuestionSeconds,
    required this.explanationsReady,
    this.aiExplanationsLocked = false,
    required this.weakTopics,
    required this.questions,
    this.autoSubmitted = false,
    this.newlyUnlocked = const [],
    this.celebration = const Celebration(),
  });

  factory MockExamReview.fromJson(Map<String, dynamic> j) => MockExamReview(
    attemptId:    (j['attempt_id'] as num).toInt(),
    courseCode:   j['course_code'] as String,
    courseTitle:  j['course_title'] as String,
    status:       j['status'] as String,
    grade:        j['grade'] as String? ?? 'F',
    scorePercent: (j['score_percent'] as num).toDouble(),
    correctCount: (j['correct_count'] as num).toInt(),
    wrongCount:   (j['wrong_count'] as num?)?.toInt() ?? 0,
    partiallyCorrectCount: (j['partially_correct_count'] as num?)?.toInt() ?? 0,
    skippedCount: (j['skipped_count'] as num?)?.toInt() ?? 0,
    total:        (j['total'] as num).toInt(),
    timeUsedSeconds: (j['time_used_seconds'] as num?)?.toInt() ?? 0,
    avgTimePerQuestionSeconds: (j['avg_time_per_question_seconds'] as num?)?.toDouble() ?? 0.0,
    explanationsReady: j['explanations_ready'] as bool? ?? true,
    aiExplanationsLocked: j['ai_explanations_locked'] as bool? ?? false,
    weakTopics: ((j['weak_topics'] as List?) ?? [])
        .map((t) => WeakTopic.fromJson(t as Map<String, dynamic>))
        .toList(),
    questions: ((j['questions'] as List?) ?? [])
        .map((q) => GradedQuestion.fromJson(q as Map<String, dynamic>))
        .toList(),
    autoSubmitted: j['auto_submitted'] as bool? ?? false,
    newlyUnlocked: ((j['newly_unlocked'] as List?) ?? [])
        .map((a) => Achievement.fromJson(a as Map<String, dynamic>))
        .toList(),
    celebration: j['celebration'] != null
        ? Celebration.fromJson(j['celebration'] as Map<String, dynamic>)
        : const Celebration(),
  );

  String get timeUsedLabel {
    final m = timeUsedSeconds ~/ 60;
    final s = timeUsedSeconds % 60;
    return '${m}m ${s.toString().padLeft(2, '0')}s';
  }

  String get avgTimeLabel {
    final secs = avgTimePerQuestionSeconds.round();
    if (secs < 60) return '${secs}s';
    return '${secs ~/ 60}m ${(secs % 60).toString().padLeft(2, '0')}s';
  }
}

// ── Phase 3 — Mock Exam Dashboard (history, statistics, weak topics) ─────────

class MockExamHistoryItem {
  final int      attemptId;
  final String   courseCode;
  final String   courseTitle;
  final String   difficulty;
  final String   mode;
  final int      questionCount;
  final String?  grade;
  final double?  scorePercent;
  final int?     timeUsedSeconds;
  final DateTime? submittedAt;
  final DateTime startedAt;

  const MockExamHistoryItem({
    required this.attemptId,
    required this.courseCode,
    required this.courseTitle,
    this.mode = 'practice',
    required this.difficulty,
    required this.questionCount,
    this.grade,
    this.scorePercent,
    this.timeUsedSeconds,
    this.submittedAt,
    required this.startedAt,
  });

  factory MockExamHistoryItem.fromJson(Map<String, dynamic> j) => MockExamHistoryItem(
    attemptId:    (j['attempt_id'] as num).toInt(),
    courseCode:   j['course_code'] as String,
    courseTitle:  j['course_title'] as String,
    difficulty:   j['difficulty'] as String,
    mode:         j['mode'] as String? ?? 'practice',
    questionCount: (j['question_count'] as num).toInt(),
    grade:        j['grade'] as String?,
    scorePercent: (j['score_percent'] as num?)?.toDouble(),
    timeUsedSeconds: (j['time_used_seconds'] as num?)?.toInt(),
    submittedAt:  j['submitted_at'] != null ? DateTime.tryParse(j['submitted_at'] as String) : null,
    startedAt:    DateTime.tryParse(j['started_at'] as String? ?? '') ?? DateTime.now(),
  );

  String get timeUsedLabel {
    final s = timeUsedSeconds;
    if (s == null) return '—';
    final m = s ~/ 60;
    final sec = s % 60;
    return '${m}m ${sec.toString().padLeft(2, '0')}s';
  }
}

class MockExamStatistics {
  final int     totalExams;
  final double? highestScore;
  final double? lowestScore;
  final double? averageScore;
  final int     totalStudyTimeSeconds;
  final double? averageCompletionTimeSeconds;
  final bool    historyCapped;
  final int?    historyLimit;

  const MockExamStatistics({
    required this.totalExams,
    this.highestScore,
    this.lowestScore,
    this.averageScore,
    this.totalStudyTimeSeconds = 0,
    this.averageCompletionTimeSeconds,
    this.historyCapped = false,
    this.historyLimit,
  });

  factory MockExamStatistics.fromJson(Map<String, dynamic> j) => MockExamStatistics(
    totalExams:   (j['total_exams'] as num?)?.toInt() ?? 0,
    highestScore: (j['highest_score'] as num?)?.toDouble(),
    lowestScore:  (j['lowest_score'] as num?)?.toDouble(),
    averageScore: (j['average_score'] as num?)?.toDouble(),
    totalStudyTimeSeconds: (j['total_study_time_seconds'] as num?)?.toInt() ?? 0,
    averageCompletionTimeSeconds: (j['average_completion_time_seconds'] as num?)?.toDouble(),
    historyCapped: j['history_capped'] as bool? ?? false,
    historyLimit:  (j['history_limit'] as num?)?.toInt(),
  );

  String get totalStudyTimeLabel {
    final h = totalStudyTimeSeconds ~/ 3600;
    final m = (totalStudyTimeSeconds % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  String get averageCompletionTimeLabel {
    final s = averageCompletionTimeSeconds;
    if (s == null) return '—';
    final secs = s.round();
    final m = secs ~/ 60;
    final sec = secs % 60;
    return '${m}m ${sec.toString().padLeft(2, '0')}s';
  }
}

// ── Phase 4 — Premium: AI Readiness Prediction & Advanced Analytics ──────────

class ReadinessPrediction {
  final String courseCode;
  final int    expectedScoreLow;
  final int    expectedScoreHigh;
  final String confidence;   // Low | Medium | High
  final double studyProgressPercent;
  final int    mockExamsTaken;
  final int    dailyTopicsCompleted;
  final int    weakAreasCount;

  const ReadinessPrediction({
    required this.courseCode,
    required this.expectedScoreLow,
    required this.expectedScoreHigh,
    required this.confidence,
    required this.studyProgressPercent,
    required this.mockExamsTaken,
    required this.dailyTopicsCompleted,
    required this.weakAreasCount,
  });

  factory ReadinessPrediction.fromJson(Map<String, dynamic> j) => ReadinessPrediction(
    courseCode:            j['course_code'] as String,
    expectedScoreLow:      (j['expected_score_low'] as num).toInt(),
    expectedScoreHigh:     (j['expected_score_high'] as num).toInt(),
    confidence:            j['confidence'] as String? ?? 'Low',
    studyProgressPercent:  (j['study_progress_percent'] as num?)?.toDouble() ?? 0,
    mockExamsTaken:        (j['mock_exams_taken'] as num?)?.toInt() ?? 0,
    dailyTopicsCompleted:  (j['daily_topics_completed'] as num?)?.toInt() ?? 0,
    weakAreasCount:        (j['weak_areas_count'] as num?)?.toInt() ?? 0,
  );
}

class TopicMastery {
  final String topic;
  final double correct;
  final int    total;
  final double masteryPercent;

  const TopicMastery({
    required this.topic, required this.correct, required this.total, required this.masteryPercent,
  });

  factory TopicMastery.fromJson(Map<String, dynamic> j) => TopicMastery(
    topic:          j['topic'] as String,
    correct:        (j['correct'] as num).toDouble(),
    total:          (j['total'] as num).toInt(),
    masteryPercent: (j['mastery_percent'] as num).toDouble(),
  );
}

class DifficultyTrend {
  final String difficulty;
  final double correct;
  final int    total;
  final double avgPercent;

  const DifficultyTrend({
    required this.difficulty, required this.correct, required this.total, required this.avgPercent,
  });

  factory DifficultyTrend.fromJson(Map<String, dynamic> j) => DifficultyTrend(
    difficulty: j['difficulty'] as String,
    correct:    (j['correct'] as num).toDouble(),
    total:      (j['total'] as num).toInt(),
    avgPercent: (j['avg_percent'] as num).toDouble(),
  );
}

class HeatmapCell {
  final String topic;
  final String difficulty;
  final double correct;
  final int    total;
  final double percent;

  const HeatmapCell({
    required this.topic, required this.difficulty,
    required this.correct, required this.total, required this.percent,
  });

  factory HeatmapCell.fromJson(Map<String, dynamic> j) => HeatmapCell(
    topic:      j['topic'] as String,
    difficulty: j['difficulty'] as String,
    correct:    (j['correct'] as num).toDouble(),
    total:      (j['total'] as num).toInt(),
    percent:    (j['percent'] as num).toDouble(),
  );
}

class MockExamAnalytics {
  final int totalExamsAnalyzed;
  final List<TopicMastery> topicMastery;
  final List<DifficultyTrend> difficultyTrend;
  final List<HeatmapCell> heatmap;

  const MockExamAnalytics({
    required this.totalExamsAnalyzed,
    required this.topicMastery,
    required this.difficultyTrend,
    required this.heatmap,
  });

  factory MockExamAnalytics.fromJson(Map<String, dynamic> j) => MockExamAnalytics(
    totalExamsAnalyzed: (j['total_exams_analyzed'] as num?)?.toInt() ?? 0,
    topicMastery: ((j['topic_mastery'] as List?) ?? [])
        .map((e) => TopicMastery.fromJson(e as Map<String, dynamic>)).toList(),
    difficultyTrend: ((j['difficulty_trend'] as List?) ?? [])
        .map((e) => DifficultyTrend.fromJson(e as Map<String, dynamic>)).toList(),
    heatmap: ((j['heatmap'] as List?) ?? [])
        .map((e) => HeatmapCell.fromJson(e as Map<String, dynamic>)).toList(),
  );
}
