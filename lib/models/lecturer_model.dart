// lib/models/lecturer_model.dart
//
// Data models for the AI Lecturer — Structured Teaching Mode.
//
// Phase 4: persistent progress, post-lesson Q&A, "I don't know" handling,
// and a final exam. Everything below `state_json`'s shape is owned by this
// file's toJson/fromJson — the backend just stores/returns it verbatim.

// ── Course Chapter ────────────────────────────────────────────────────────────

class LecturerChapter {
  final int          index;
  final String       title;
  final List<String> topics;
  final String       durationEstimate;

  const LecturerChapter({
    required this.index,
    required this.title,
    required this.topics,
    required this.durationEstimate,
  });

  factory LecturerChapter.fromJson(Map<String, dynamic> j) => LecturerChapter(
    index:            (j['index'] as num).toInt(),
    title:            j['title'] as String,
    topics:           List<String>.from(j['topics'] as List),
    durationEstimate: j['duration_estimate'] as String? ?? '1 week',
  );

  Map<String, dynamic> toJson() => {
    'index': index,
    'title': title,
    'topics': topics,
    'duration_estimate': durationEstimate,
  };
}

// ── Full Curriculum ───────────────────────────────────────────────────────────

class LecturerCurriculum {
  final String                courseName;
  final String                courseCode;
  final String                level;
  final int                   totalChapters;
  final int                   estimatedWeeks;
  final List<LecturerChapter> chapters;

  const LecturerCurriculum({
    required this.courseName,
    required this.courseCode,
    required this.level,
    required this.totalChapters,
    required this.estimatedWeeks,
    required this.chapters,
  });

  factory LecturerCurriculum.fromJson(Map<String, dynamic> j) => LecturerCurriculum(
    courseName:     j['course_name']     as String,
    courseCode:     j['course_code']     as String? ?? '',
    level:          j['level']           as String? ?? 'intermediate',
    totalChapters:  (j['total_chapters'] as num).toInt(),
    estimatedWeeks: (j['estimated_weeks'] as num).toInt(),
    chapters: (j['chapters'] as List)
        .map((c) => LecturerChapter.fromJson(c as Map<String, dynamic>))
        .toList(),
  );
}

// ── Chapter phase (fine-grained progress within a chapter) ────────────────────

enum ChapterPhase {
  notStarted,          // chapter not yet reached / lesson not loaded
  awaitingQaChoice,     // lesson delivered — "Do you have any questions?"
  awaitingQaQuestion,   // student said yes — waiting for their question
  loadingQaAnswer,      // AI is answering the student's question
  awaitingCheckAnswer,  // check question shown — waiting for answer / "I don't know"
  loadingCheckFeedback, // AI is evaluating / explaining
  feedbackShown,        // feedback shown — "Next Chapter" button visible
  passed,               // chapter fully complete
}

ChapterPhase _phaseFromString(String? s) {
  switch (s) {
    case 'awaiting_qa_choice':     return ChapterPhase.awaitingQaChoice;
    case 'awaiting_qa_question':   return ChapterPhase.awaitingQaQuestion;
    case 'loading_qa_answer':      return ChapterPhase.loadingQaAnswer;
    case 'awaiting_check_answer':  return ChapterPhase.awaitingCheckAnswer;
    case 'loading_check_feedback': return ChapterPhase.loadingCheckFeedback;
    case 'feedback_shown':         return ChapterPhase.feedbackShown;
    case 'passed':                 return ChapterPhase.passed;
    default:                       return ChapterPhase.notStarted;
  }
}

String _phaseToString(ChapterPhase p) {
  switch (p) {
    case ChapterPhase.awaitingQaChoice:     return 'awaiting_qa_choice';
    case ChapterPhase.awaitingQaQuestion:   return 'awaiting_qa_question';
    case ChapterPhase.loadingQaAnswer:      return 'loading_qa_answer';
    case ChapterPhase.awaitingCheckAnswer:  return 'awaiting_check_answer';
    case ChapterPhase.loadingCheckFeedback: return 'loading_check_feedback';
    case ChapterPhase.feedbackShown:        return 'feedback_shown';
    case ChapterPhase.passed:               return 'passed';
    case ChapterPhase.notStarted:           return 'not_started';
  }
}

class ChapterProgress {
  final LecturerChapter chapter;
  ChapterPhase phase;
  String?      lessonText;      // AI-generated lesson content
  String?      checkQuestion;   // Extracted from lesson text

  ChapterProgress({
    required this.chapter,
    this.phase = ChapterPhase.notStarted,
    this.lessonText,
    this.checkQuestion,
  });

  /// Legacy-style state used purely for the chapter-list drawer UI.
  bool get isLocked  => phase == ChapterPhase.notStarted && lessonText == null;
  bool get isPassed  => phase == ChapterPhase.passed;
  bool get isCurrent => !isLocked && !isPassed;

  Map<String, dynamic> toJson() => {
    'phase':          _phaseToString(phase),
    'lesson_text':    lessonText,
    'check_question': checkQuestion,
  };

  static ChapterProgress fromJson(
      Map<String, dynamic> j, LecturerChapter chapter) {
    return ChapterProgress(
      chapter:       chapter,
      phase:         _phaseFromString(j['phase'] as String?),
      lessonText:    j['lesson_text'] as String?,
      checkQuestion: j['check_question'] as String?,
    );
  }
}

// ── Session Message (for conversation display) ────────────────────────────────

enum LecturerMessageType { lesson, studentAnswer, feedback, system }

LecturerMessageType _msgTypeFromString(String s) {
  switch (s) {
    case 'lesson':        return LecturerMessageType.lesson;
    case 'studentAnswer': return LecturerMessageType.studentAnswer;
    case 'feedback':      return LecturerMessageType.feedback;
    default:              return LecturerMessageType.system;
  }
}

class LecturerMessage {
  final String              text;
  final LecturerMessageType type;
  final DateTime            timestamp;

  LecturerMessage({
    required this.text,
    required this.type,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'text': text,
    'type': type.name,
    'timestamp': timestamp.toIso8601String(),
  };

  factory LecturerMessage.fromJson(Map<String, dynamic> j) => LecturerMessage(
    text:      j['text'] as String,
    type:      _msgTypeFromString(j['type'] as String? ?? 'system'),
    timestamp: DateTime.tryParse(j['timestamp'] as String? ?? '') ?? DateTime.now(),
  );
}

// ── Course stage (overall session stage) ───────────────────────────────────────

enum CourseStage {
  teaching,        // working through chapters
  examOffer,       // all chapters done — "Would you like to take the exam?"
  examInProgress,  // exam questions shown, student answering
  examResult,      // graded — score shown
  completed,       // course finished (exam declined or exam done)
}

CourseStage _stageFromString(String? s) {
  switch (s) {
    case 'exam_offer':      return CourseStage.examOffer;
    case 'exam_in_progress': return CourseStage.examInProgress;
    case 'exam_result':     return CourseStage.examResult;
    case 'completed':       return CourseStage.completed;
    default:                return CourseStage.teaching;
  }
}

String _stageToString(CourseStage s) {
  switch (s) {
    case CourseStage.examOffer:      return 'exam_offer';
    case CourseStage.examInProgress: return 'exam_in_progress';
    case CourseStage.examResult:     return 'exam_result';
    case CourseStage.completed:      return 'completed';
    case CourseStage.teaching:       return 'teaching';
  }
}

// ── Exam ─────────────────────────────────────────────────────────────────────

class ExamQuestion {
  final int    id;
  final String question;
  const ExamQuestion({required this.id, required this.question});

  factory ExamQuestion.fromJson(Map<String, dynamic> j) => ExamQuestion(
    id:       (j['id'] as num).toInt(),
    question: j['question'] as String,
  );

  Map<String, dynamic> toJson() => {'id': id, 'question': question};
}

class ExamQuestionResult {
  final int    id;
  final String verdict;   // correct | partial | incorrect
  final String feedback;

  const ExamQuestionResult({
    required this.id,
    required this.verdict,
    required this.feedback,
  });

  factory ExamQuestionResult.fromJson(Map<String, dynamic> j) => ExamQuestionResult(
    id:       (j['id'] as num).toInt(),
    verdict:  j['verdict'] as String? ?? 'partial',
    feedback: j['feedback'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'verdict': verdict, 'feedback': feedback,
  };
}

class ExamResult {
  final List<ExamQuestionResult> results;
  final double score;
  final int    total;
  final String overallFeedback;

  const ExamResult({
    required this.results,
    required this.score,
    required this.total,
    required this.overallFeedback,
  });

  factory ExamResult.fromJson(Map<String, dynamic> j) => ExamResult(
    results: ((j['results'] as List?) ?? [])
        .map((r) => ExamQuestionResult.fromJson(r as Map<String, dynamic>))
        .toList(),
    score:           (j['score'] as num?)?.toDouble() ?? 0,
    total:           (j['total'] as num?)?.toInt() ?? 0,
    overallFeedback: j['overall_feedback'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'results': results.map((r) => r.toJson()).toList(),
    'score': score,
    'total': total,
    'overall_feedback': overallFeedback,
  };
}

// ── Resume-list summary (one of the student's saved lecturer courses) ────────

class LecturerCourseSummary {
  final int      id;
  final String   courseName;
  final String?  courseCode;
  final String   level;
  final String   status;            // in_progress | completed
  final double   progressPercent;
  final DateTime createdAt;
  final DateTime updatedAt;

  const LecturerCourseSummary({
    required this.id,
    required this.courseName,
    required this.courseCode,
    required this.level,
    required this.status,
    required this.progressPercent,
    required this.createdAt,
    required this.updatedAt,
  });

  factory LecturerCourseSummary.fromJson(Map<String, dynamic> j) => LecturerCourseSummary(
    id:              (j['id'] as num).toInt(),
    courseName:      j['course_name'] as String,
    courseCode:      j['course_code'] as String?,
    level:           j['level'] as String? ?? 'intermediate',
    status:          j['status'] as String? ?? 'in_progress',
    progressPercent: (j['progress_percent'] as num?)?.toDouble() ?? 0,
    createdAt:       DateTime.tryParse(j['created_at'] as String? ?? '') ?? DateTime.now(),
    updatedAt:       DateTime.tryParse(j['updated_at'] as String? ?? '') ?? DateTime.now(),
  );
}

// ── Popular course (trending-materials → course mapping) ─────────────────────

class PopularCourse {
  final String  courseName;
  final String? courseCode;
  const PopularCourse({required this.courseName, this.courseCode});

  factory PopularCourse.fromJson(Map<String, dynamic> j) => PopularCourse(
    courseName: j['course_name'] as String,
    courseCode: j['course_code'] as String?,
  );
}
