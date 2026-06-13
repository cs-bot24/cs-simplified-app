// lib/models/lecturer_model.dart
//
// Data models for the AI Lecturer — Structured Teaching Mode.

// ── Course Chapter ────────────────────────────────────────────────────────────

class LecturerChapter {
  final int         index;
  final String      title;
  final List<String> topics;
  final String      durationEstimate;

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
}

// ── Full Curriculum ───────────────────────────────────────────────────────────

class LecturerCurriculum {
  final String             courseName;
  final String             courseCode;
  final String             level;
  final int                totalChapters;
  final int                estimatedWeeks;
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

// ── Chapter State (progress tracking) ────────────────────────────────────────

enum ChapterState {
  locked,     // not yet reached
  current,    // being taught right now
  checking,   // lesson done, waiting for check answer
  passed,     // check question answered correctly / student advanced
}

class ChapterProgress {
  final LecturerChapter chapter;
  ChapterState state;
  String?      lessonText;      // AI-generated lesson content
  String?      checkQuestion;   // Extracted from lesson text
  String?      checkFeedback;   // AI feedback on student's answer

  ChapterProgress({
    required this.chapter,
    this.state       = ChapterState.locked,
    this.lessonText,
    this.checkQuestion,
    this.checkFeedback,
  });
}

// ── Session Message (for conversation display) ────────────────────────────────

enum LecturerMessageType { lesson, studentAnswer, feedback, system }

class LecturerMessage {
  final String             text;
  final LecturerMessageType type;
  final DateTime           timestamp;

  const LecturerMessage({
    required this.text,
    required this.type,
    required this.timestamp,
  });
}
