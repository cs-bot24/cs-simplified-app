// lib/models/exam_prep_model.dart

import 'material_model.dart';

// ── Course group (hub entry) ──────────────────────────────────────────────────

class ExamCourse {
  final String             courseCode;
  final String             courseTitle;
  final int                materialCount;
  final List<MaterialModel> materials;

  const ExamCourse({
    required this.courseCode,
    required this.courseTitle,
    required this.materialCount,
    required this.materials,
  });

  factory ExamCourse.fromJson(Map<String, dynamic> j) => ExamCourse(
    courseCode:    j['course_code']    as String,
    courseTitle:   j['course_title']   as String,
    materialCount: (j['material_count'] as num).toInt(),
    materials: ((j['materials'] as List?) ?? [])
        .map((m) => MaterialModel.fromJson(m as Map<String, dynamic>))
        .toList(),
  );
}

// ── Quiz ─────────────────────────────────────────────────────────────────────

class QuizQuestion {
  final int         id;
  final String      question;
  final List<String> options;
  final int         correctIndex;
  final String      explanation;
  int?              selectedIndex;   // mutable — student's pick

  QuizQuestion({
    required this.id,
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.explanation,
    this.selectedIndex,
  });

  bool get isAnswered  => selectedIndex != null;
  bool get isCorrect   => selectedIndex == correctIndex;

  factory QuizQuestion.fromJson(Map<String, dynamic> j) => QuizQuestion(
    id:           (j['id'] as num).toInt(),
    question:     j['question'] as String,
    options:      List<String>.from(j['options'] as List),
    correctIndex: (j['correct_index'] as num).toInt(),
    explanation:  j['explanation'] as String? ?? '',
  );
}

class QuizData {
  final String            courseCode;
  final String            courseTitle;
  final int               total;
  final List<QuizQuestion> questions;

  const QuizData({
    required this.courseCode,
    required this.courseTitle,
    required this.total,
    required this.questions,
  });

  factory QuizData.fromJson(Map<String, dynamic> j) => QuizData(
    courseCode:  j['course_code']  as String,
    courseTitle: j['course_title'] as String,
    total:       (j['total'] as num).toInt(),
    questions: ((j['questions'] as List?) ?? [])
        .map((q) => QuizQuestion.fromJson(q as Map<String, dynamic>))
        .toList(),
  );

  int get answeredCount => questions.where((q) => q.isAnswered).length;
  int get correctCount  => questions.where((q) => q.isCorrect).length;
  double get scorePercent =>
      total > 0 ? (correctCount / total * 100) : 0;
}

// ── Focus areas ───────────────────────────────────────────────────────────────

class FocusArea {
  final int          rank;
  final String       topic;
  final String       why;
  final List<String> subtopics;
  final String       estimatedWeight;  // High / Medium / Low

  const FocusArea({
    required this.rank,
    required this.topic,
    required this.why,
    required this.subtopics,
    required this.estimatedWeight,
  });

  factory FocusArea.fromJson(Map<String, dynamic> j) => FocusArea(
    rank:            (j['rank'] as num).toInt(),
    topic:           j['topic'] as String,
    why:             j['why'] as String? ?? '',
    subtopics:       List<String>.from(j['subtopics'] as List? ?? []),
    estimatedWeight: j['estimated_weight'] as String? ?? 'Medium',
  );
}

class FocusAreasData {
  final String        courseCode;
  final String        courseTitle;
  final List<FocusArea> focusAreas;
  final String        studyAdvice;

  const FocusAreasData({
    required this.courseCode,
    required this.courseTitle,
    required this.focusAreas,
    required this.studyAdvice,
  });

  factory FocusAreasData.fromJson(Map<String, dynamic> j) => FocusAreasData(
    courseCode:  j['course_code']  as String,
    courseTitle: j['course_title'] as String,
    focusAreas: ((j['focus_areas'] as List?) ?? [])
        .map((f) => FocusArea.fromJson(f as Map<String, dynamic>))
        .toList(),
    studyAdvice: j['study_advice'] as String? ?? '',
  );
}

// ── Readiness tracker ─────────────────────────────────────────────────────────

class ReadinessData {
  final String   courseCode;
  final String   courseTitle;
  final double   readinessPercent;
  final int      materialsRead;
  final int      practiceSessions;
  final int      quizSessions;
  final int      revisionSessions;
  final bool     focusAreasViewed;
  final double?  avgQuizScore;
  final DateTime? examDate;
  final int?     daysUntilExam;

  const ReadinessData({
    required this.courseCode,
    required this.courseTitle,
    required this.readinessPercent,
    required this.materialsRead,
    required this.practiceSessions,
    required this.quizSessions,
    required this.revisionSessions,
    required this.focusAreasViewed,
    this.avgQuizScore,
    this.examDate,
    this.daysUntilExam,
  });

  factory ReadinessData.fromJson(Map<String, dynamic> j) => ReadinessData(
    courseCode:       j['course_code']       as String,
    courseTitle:      j['course_title']      as String,
    readinessPercent: (j['readiness_percent'] as num?)?.toDouble() ?? 0,
    materialsRead:    (j['materials_read']   as num?)?.toInt() ?? 0,
    practiceSessions: (j['practice_sessions'] as num?)?.toInt() ?? 0,
    quizSessions:     (j['quiz_sessions']    as num?)?.toInt() ?? 0,
    revisionSessions: (j['revision_sessions'] as num?)?.toInt() ?? 0,
    focusAreasViewed: j['focus_areas_viewed'] as bool? ?? false,
    avgQuizScore:     (j['avg_quiz_score']   as num?)?.toDouble(),
    examDate:         j['exam_date'] != null
        ? DateTime.tryParse(j['exam_date'] as String)
        : null,
    daysUntilExam:    (j['days_until_exam'] as num?)?.toInt(),
  );

  /// Label for urgency based on days remaining
  String get urgencyLabel {
    if (daysUntilExam == null) return '';
    if (daysUntilExam! <= 1)  return 'Critical';
    if (daysUntilExam! <= 3)  return 'High';
    if (daysUntilExam! <= 7)  return 'Medium';
    return 'Low';
  }
}

// ── Daily topics ──────────────────────────────────────────────────────────────

class DailyTopic {
  final String topic;
  final String why;
  final int    estimatedMinutes;

  const DailyTopic({
    required this.topic,
    required this.why,
    required this.estimatedMinutes,
  });

  factory DailyTopic.fromJson(Map<String, dynamic> j) => DailyTopic(
    topic:             j['topic'] as String,
    why:               j['why']   as String? ?? '',
    estimatedMinutes:  (j['estimated_minutes'] as num?)?.toInt() ?? 30,
  );
}

class DailyTopicsData {
  final int           daysUntilExam;
  final String        urgencyLabel;
  final int           estimatedStudyHours;
  final List<DailyTopic> todayTopics;
  final String        dailyTip;

  const DailyTopicsData({
    required this.daysUntilExam,
    required this.urgencyLabel,
    required this.estimatedStudyHours,
    required this.todayTopics,
    required this.dailyTip,
  });

  factory DailyTopicsData.fromJson(Map<String, dynamic> j) => DailyTopicsData(
    daysUntilExam:       (j['days_until_exam']       as num?)?.toInt() ?? 0,
    urgencyLabel:         j['urgency_label']          as String? ?? 'Medium',
    estimatedStudyHours: (j['estimated_study_hours'] as num?)?.toInt() ?? 2,
    todayTopics: ((j['today_topics'] as List?) ?? [])
        .map((t) => DailyTopic.fromJson(t as Map<String, dynamic>))
        .toList(),
    dailyTip: j['daily_tip'] as String? ?? '',
  );
}
