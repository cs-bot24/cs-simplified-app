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

  MockExamQuestion({
    required this.id,
    required this.type,
    required this.question,
    required this.options,
    required this.correctAnswer,
    required this.topic,
    required this.difficulty,
    this.selectedAnswer,
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
  );
}

enum QuestionStatus { notVisited, visited, answered, flagged }

class MockExamAttempt {
  final int                     attemptId;
  final String                  courseCode;
  final String                  courseTitle;
  final String                  difficulty;
  final int                     questionCount;
  final int                     durationSeconds;
  int                            secondsRemaining;
  String                        status;   // in_progress | submitted | abandoned
  final List<MockExamQuestion>  questions;
  final Set<int>                visited;
  final Set<int>                flagged;
  final bool                    usedCachedExam;
  final DateTime                startedAt;
  double?                       scorePercent;
  int?                          correctCount;
  Map<String, dynamic>?         perTopic;

  MockExamAttempt({
    required this.attemptId,
    required this.courseCode,
    required this.courseTitle,
    required this.difficulty,
    required this.questionCount,
    required this.durationSeconds,
    required this.secondsRemaining,
    required this.status,
    required this.questions,
    required this.visited,
    required this.flagged,
    required this.usedCachedExam,
    required this.startedAt,
    this.scorePercent,
    this.correctCount,
    this.perTopic,
  });

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
      questionCount:    (j['question_count'] as num).toInt(),
      durationSeconds:  (j['duration_seconds'] as num).toInt(),
      secondsRemaining: (j['seconds_remaining'] as num).toInt(),
      status:           j['status'] as String,
      questions:        questions,
      visited:          Set<int>.from(List<num>.from(j['visited'] as List? ?? [])
          .map((n) => n.toInt())),
      flagged:          Set<int>.from(List<num>.from(j['flagged'] as List? ?? [])
          .map((n) => n.toInt())),
      usedCachedExam:   j['used_cached_exam'] as bool? ?? false,
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
  final List<WeakTopic>       weakTopics;
  List<GradedQuestion>        questions;
  final bool                  autoSubmitted;

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
    required this.weakTopics,
    required this.questions,
    this.autoSubmitted = false,
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
    weakTopics: ((j['weak_topics'] as List?) ?? [])
        .map((t) => WeakTopic.fromJson(t as Map<String, dynamic>))
        .toList(),
    questions: ((j['questions'] as List?) ?? [])
        .map((q) => GradedQuestion.fromJson(q as Map<String, dynamic>))
        .toList(),
    autoSubmitted: j['auto_submitted'] as bool? ?? false,
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
