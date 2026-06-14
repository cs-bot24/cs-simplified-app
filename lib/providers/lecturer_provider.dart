// lib/providers/lecturer_provider.dart
//
// State management for AI Lecturer — Structured Teaching Mode (Phase 4).
//
// Flow per chapter:
//   1. loadChapter(i)        → AI delivers the lesson (ends with a check question)
//   2. phase = awaitingQaChoice → "Do you have any questions about this chapter?"
//        - yes → answerQaChoice(true) → phase = awaitingQaQuestion
//                 submitQaQuestion(q) → AI answers → back to awaitingQaChoice
//        - no  → answerQaChoice(false) → phase = awaitingCheckAnswer
//   3. phase = awaitingCheckAnswer → check question shown
//        - student answers      → submitCheckAnswer(answer)
//        - student doesn't know → submitCheckAnswer('', knowsAnswer: false)
//   4. AI gives feedback/explanation → phase = feedbackShown → "Next Chapter"
//   5. advanceToNextChapter() → repeat from step 1, or (last chapter) → exam offer
//
// Course-level flow after the last chapter:
//   courseStage = examOffer → respondToExamOffer(true/false)
//     - true  → AI generates >=10 questions → courseStage = examInProgress
//                submitExam(answers) → AI grades → courseStage = examResult
//     - false → courseStage = completed
//
// Persistence:
//   Every state-changing step calls _saveState(), which serialises the
//   session and PATCHes it to /lecturer/courses/{id}. On re-entry, the
//   student picks a saved course from the resume list and resumeCourse(id)
//   rebuilds this exact state from the backend.

import 'dart:convert';
import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../models/lecturer_model.dart';

enum LecturerState {
  idle,
  loadingCourses,
  loadingCurriculum,
  loadingLesson,
  qaLoading,
  checking,
  examLoading,
  examGrading,
  error,
}

class LecturerProvider extends ChangeNotifier {

  // ── State ─────────────────────────────────────────────────────────────────
  LecturerState        _state      = LecturerState.idle;
  String?              _error;

  // Resume list / setup screen data
  List<LecturerCourseSummary> _savedCourses   = [];
  List<PopularCourse>         _popularCourses = [];
  bool                         _loadingHome    = false;

  // Active session
  int?                 _courseId;
  LecturerCurriculum?  _curriculum;
  int                  _currentChapterIndex = 0;
  CourseStage          _courseStage = CourseStage.teaching;
  final List<ChapterProgress> _chapters = [];
  final List<LecturerMessage> _messages = [];
  final List<Map<String, String>> _history = [];

  // Exam
  List<ExamQuestion> _examQuestions = [];
  ExamResult?         _examResult;

  // ── Session setup ─────────────────────────────────────────────────────────
  String  _courseName = '';
  String  _courseCode = '';
  String  _level      = 'intermediate';

  // ── Getters ───────────────────────────────────────────────────────────────
  LecturerState             get state           => _state;
  String?                   get error           => _error;
  LecturerCurriculum?       get curriculum      => _curriculum;
  List<ChapterProgress>     get chapters        => List.unmodifiable(_chapters);
  List<LecturerMessage>     get messages        => List.unmodifiable(_messages);
  int                       get currentIndex    => _currentChapterIndex;
  String                    get courseName      => _courseName;
  String                    get courseCode      => _courseCode;
  String                    get level           => _level;
  bool                      get hasSession      => _curriculum != null;
  CourseStage               get courseStage     => _courseStage;
  List<ExamQuestion>        get examQuestions   => List.unmodifiable(_examQuestions);
  ExamResult?               get examResult      => _examResult;
  bool                      get loadingHome     => _loadingHome;
  List<LecturerCourseSummary> get savedCourses  => List.unmodifiable(_savedCourses);
  List<PopularCourse>       get popularCourses  => List.unmodifiable(_popularCourses);

  ChapterProgress? get currentChapter =>
      _chapters.isNotEmpty && _currentChapterIndex < _chapters.length
          ? _chapters[_currentChapterIndex]
          : null;

  bool get isLastChapter =>
      _curriculum != null && _currentChapterIndex >= _chapters.length - 1;

  double get overallProgress {
    if (_chapters.isEmpty) return 0;
    final passed = _chapters.where((c) => c.isPassed).length;
    return passed / _chapters.length;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Resume list / setup screen
  // ══════════════════════════════════════════════════════════════════════════

  /// Loads the student's saved courses + popular-course suggestions.
  /// Called once when the AI Lecturer entry screen first appears.
  Future<void> loadHomeData() async {
    _loadingHome = true;
    notifyListeners();

    try {
      final coursesData = await ApiClient.getLecturerCourses();
      _savedCourses = coursesData
          .map((j) => LecturerCourseSummary.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (_) {
      _savedCourses = [];
    }

    try {
      final popularData = await ApiClient.getLecturerPopularCourses();
      _popularCourses = popularData
          .map((j) => PopularCourse.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (_) {
      _popularCourses = [];
    }

    _loadingHome = false;
    notifyListeners();
  }

  /// Removes a saved course permanently.
  Future<void> deleteSavedCourse(int courseId) async {
    try {
      await ApiClient.deleteLecturerCourse(courseId);
      _savedCourses.removeWhere((c) => c.id == courseId);
      notifyListeners();
    } catch (e) {
      _error = 'Could not delete this course. Please try again.';
      notifyListeners();
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Session setup
  // ══════════════════════════════════════════════════════════════════════════

  void setSession({
    required String courseName,
    required String courseCode,
    required String level,
  }) {
    _courseName = courseName;
    _courseCode = courseCode;
    _level      = level;
  }

  /// Starts a brand-new course: generates + persists the curriculum.
  Future<void> startNewCourse({List<String>? customTopics}) async {
    if (_courseName.isEmpty) return;

    _state = LecturerState.loadingCurriculum;
    _error = null;
    _resetSessionFields();
    notifyListeners();

    try {
      final data = await ApiClient.createLecturerCourse(
        courseName:   _courseName,
        courseCode:   _courseCode.isNotEmpty ? _courseCode : null,
        level:        _level,
        customTopics: (customTopics != null && customTopics.isNotEmpty)
            ? customTopics : null,
      );

      _courseId = data['id'] as int;
      _hydrateCurriculum(data['curriculum_json'] as String);
      _courseStage = CourseStage.teaching;

      for (int i = 0; i < _curriculum!.chapters.length; i++) {
        _chapters.add(ChapterProgress(chapter: _curriculum!.chapters[i]));
      }

      _messages.add(LecturerMessage(
        text: '📚 **${_curriculum!.courseName}** curriculum is ready!\n\n'
            'Your course has **${_curriculum!.totalChapters} chapters** '
            'over approximately **${_curriculum!.estimatedWeeks} weeks**.\n\n'
            'Tap **Chapter 1** to begin your first lesson.',
        type:      LecturerMessageType.system,
        timestamp: DateTime.now(),
      ));

      _state = LecturerState.idle;
      await _saveState();
    } catch (e) {
      _error = 'Could not generate curriculum. Please try again.';
      _state = LecturerState.error;
    }
    notifyListeners();
  }

  /// Resumes a previously saved course exactly where the student left off.
  Future<void> resumeCourse(int courseId) async {
    _state = LecturerState.loadingCurriculum;
    _error = null;
    _resetSessionFields();
    notifyListeners();

    try {
      final data = await ApiClient.getLecturerCourse(courseId);

      _courseId   = data['id'] as int;
      _courseName = data['course_name'] as String;
      _courseCode = data['course_code'] as String? ?? '';
      _level      = data['level'] as String? ?? 'intermediate';

      _hydrateCurriculum(data['curriculum_json'] as String);

      final state = jsonDecode(data['state_json'] as String) as Map<String, dynamic>;
      _currentChapterIndex = state['current_chapter_index'] as int? ?? 0;
      _courseStage = _stageFromJson(state['course_stage'] as String?);

      final chapterStates = (state['chapters'] as List?) ?? [];
      for (int i = 0; i < _curriculum!.chapters.length; i++) {
        final cj = i < chapterStates.length
            ? chapterStates[i] as Map<String, dynamic>
            : <String, dynamic>{};
        _chapters.add(ChapterProgress.fromJson(cj, _curriculum!.chapters[i]));
      }

      for (final m in (state['messages'] as List? ?? [])) {
        _messages.add(LecturerMessage.fromJson(m as Map<String, dynamic>));
      }

      for (final h in (state['history'] as List? ?? [])) {
        final map = h as Map<String, dynamic>;
        _history.add({
          'role':    map['role'] as String? ?? 'user',
          'content': map['content'] as String? ?? '',
        });
      }

      final examQ = state['exam_questions'] as List?;
      if (examQ != null) {
        _examQuestions = examQ
            .map((q) => ExamQuestion.fromJson(q as Map<String, dynamic>))
            .toList();
      }
      final examR = state['exam_result'] as Map<String, dynamic>?;
      if (examR != null) {
        _examResult = ExamResult.fromJson(examR);
      }

      if (_currentChapterIndex >= _chapters.length) {
        _currentChapterIndex = _chapters.isEmpty ? 0 : _chapters.length - 1;
      }

      _state = LecturerState.idle;
    } catch (e) {
      _error = 'Could not load this course. Please try again.';
      _state = LecturerState.error;
      _curriculum = null;
    }
    notifyListeners();
  }

  void _hydrateCurriculum(String curriculumJson) {
    final parsed = jsonDecode(curriculumJson) as Map<String, dynamic>;
    _curriculum  = LecturerCurriculum.fromJson(parsed);
  }

  CourseStage _stageFromJson(String? s) {
    switch (s) {
      case 'exam_offer':       return CourseStage.examOffer;
      case 'exam_in_progress': return CourseStage.examInProgress;
      case 'exam_result':      return CourseStage.examResult;
      case 'completed':        return CourseStage.completed;
      default:                 return CourseStage.teaching;
    }
  }

  String _stageToJson(CourseStage s) {
    switch (s) {
      case CourseStage.examOffer:      return 'exam_offer';
      case CourseStage.examInProgress: return 'exam_in_progress';
      case CourseStage.examResult:     return 'exam_result';
      case CourseStage.completed:      return 'completed';
      case CourseStage.teaching:       return 'teaching';
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Teaching loop
  // ══════════════════════════════════════════════════════════════════════════

  /// Load and deliver a chapter lesson.
  Future<void> loadChapter(int index) async {
    if (index >= _chapters.length) return;
    final chap = _chapters[index];
    if (chap.lessonText != null) {
      // Already loaded — just navigate to it (idempotent).
      _currentChapterIndex = index;
      notifyListeners();
      return;
    }

    _currentChapterIndex = index;
    _state = LecturerState.loadingLesson;
    _error = null;
    notifyListeners();

    try {
      final data = await ApiClient.teachChapter(
        courseName:          _courseName,
        courseCode:          _courseCode.isNotEmpty ? _courseCode : null,
        chapterIndex:        chap.chapter.index,
        chapterTitle:        chap.chapter.title,
        chapterTopics:       chap.chapter.topics,
        level:               _level,
        conversationHistory: _recentHistory(),
      );

      final lesson = data['lesson'] as String;
      chap.lessonText    = lesson;
      chap.checkQuestion = _extractCheckQuestion(lesson);
      chap.phase         = ChapterPhase.awaitingQaChoice;

      _messages.add(LecturerMessage(
        text:      lesson,
        type:      LecturerMessageType.lesson,
        timestamp: DateTime.now(),
      ));
      _history.add({'role': 'assistant', 'content': lesson});

      // Ask if the student has any questions about this chapter.
      _messages.add(LecturerMessage(
        text: '❓ Do you have any questions about **${chap.chapter.title}** '
            'before we continue?',
        type:      LecturerMessageType.system,
        timestamp: DateTime.now(),
      ));

      _state = LecturerState.idle;
      await _saveState();
    } catch (e) {
      _error = 'Could not load chapter. Please try again.';
      _state = LecturerState.error;
    }
    notifyListeners();
  }

  /// Student responds to "Do you have any questions?"
  Future<void> answerQaChoice(bool hasQuestion) async {
    final chap = currentChapter;
    if (chap == null || chap.phase != ChapterPhase.awaitingQaChoice) return;

    if (hasQuestion) {
      chap.phase = ChapterPhase.awaitingQaQuestion;
      _messages.add(const LecturerMessage(
        text: 'Yes, I have a question',
        type: LecturerMessageType.studentAnswer,
        timestamp: DateTime.now(),
      ));
    } else {
      chap.phase = ChapterPhase.awaitingCheckAnswer;
      _messages.add(const LecturerMessage(
        text: 'No, let\'s continue',
        type: LecturerMessageType.studentAnswer,
        timestamp: DateTime.now(),
      ));
      if (chap.checkQuestion != null) {
        _messages.add(LecturerMessage(
          text: '✅ **Check Your Understanding**\n\n${chap.checkQuestion}',
          type: LecturerMessageType.system,
          timestamp: DateTime.now(),
        ));
      }
    }
    await _saveState();
    notifyListeners();
  }

  /// Student asks a follow-up question about the current chapter.
  Future<void> submitQaQuestion(String question) async {
    final chap = currentChapter;
    if (chap == null || question.trim().isEmpty) return;

    _messages.add(LecturerMessage(
      text:      question,
      type:      LecturerMessageType.studentAnswer,
      timestamp: DateTime.now(),
    ));
    _history.add({'role': 'user', 'content': question});

    chap.phase = ChapterPhase.loadingQaAnswer;
    _state = LecturerState.qaLoading;
    _error = null;
    notifyListeners();

    try {
      final data = await ApiClient.askLecturerQuestion(
        courseName:          _courseName,
        courseCode:          _courseCode.isNotEmpty ? _courseCode : null,
        chapterTitle:        chap.chapter.title,
        chapterTopics:       chap.chapter.topics,
        studentQuestion:     question,
        level:               _level,
        conversationHistory: _recentHistory(),
      );

      final answer = data['answer'] as String;
      _messages.add(LecturerMessage(
        text:      answer,
        type:      LecturerMessageType.feedback,
        timestamp: DateTime.now(),
      ));
      _history.add({'role': 'assistant', 'content': answer});

      // Loop back to the Q&A gate.
      chap.phase = ChapterPhase.awaitingQaChoice;
      _state = LecturerState.idle;
      await _saveState();
    } catch (e) {
      _error = 'Could not answer your question. Please try again.';
      _state = LecturerState.error;
      chap.phase = ChapterPhase.awaitingQaQuestion;
    }
    notifyListeners();
  }

  /// Student answers the check question — or says "I don't know".
  Future<void> submitCheckAnswer(String answer, {bool knowsAnswer = true}) async {
    final chap = currentChapter;
    if (chap == null || chap.checkQuestion == null) return;
    if (knowsAnswer && answer.trim().isEmpty) return;

    _messages.add(LecturerMessage(
      text:      knowsAnswer ? answer : 'I don\'t know 🤔',
      type:      LecturerMessageType.studentAnswer,
      timestamp: DateTime.now(),
    ));
    if (knowsAnswer) {
      _history.add({'role': 'user', 'content': answer});
    }

    chap.phase = ChapterPhase.loadingCheckFeedback;
    _state = LecturerState.checking;
    _error = null;
    notifyListeners();

    try {
      final data = await ApiClient.evaluateCheckAnswer(
        chapterTitle:        chap.chapter.title,
        checkQuestion:       chap.checkQuestion!,
        studentAnswer:       answer,
        studentKnowsAnswer:  knowsAnswer,
        level:               _level,
        conversationHistory: _recentHistory(),
      );

      final feedback = data['feedback'] as String;
      _messages.add(LecturerMessage(
        text:      feedback,
        type:      LecturerMessageType.feedback,
        timestamp: DateTime.now(),
      ));
      _history.add({'role': 'assistant', 'content': feedback});

      chap.phase = ChapterPhase.feedbackShown;
      _state = LecturerState.idle;
      await _saveState();
    } catch (e) {
      _error = 'Could not evaluate your answer. Please try again.';
      _state = LecturerState.error;
      chap.phase = ChapterPhase.awaitingCheckAnswer;
    }
    notifyListeners();
  }

  /// Advance to the next chapter (or move to the exam offer if this was
  /// the last chapter).
  Future<void> advanceToNextChapter() async {
    final chap = currentChapter;
    if (chap == null) return;

    chap.phase = ChapterPhase.passed;

    final nextIndex = _currentChapterIndex + 1;
    if (nextIndex < _chapters.length) {
      _currentChapterIndex = nextIndex;

      _messages.add(LecturerMessage(
        text:      '🎉 Chapter ${chap.chapter.index} complete! '
            'Moving to **Chapter ${_chapters[nextIndex].chapter.index}: '
            '${_chapters[nextIndex].chapter.title}**.',
        type:      LecturerMessageType.system,
        timestamp: DateTime.now(),
      ));

      await _saveState();
      notifyListeners();
      await loadChapter(nextIndex);
    } else {
      // Course complete — offer the final exam.
      _courseStage = CourseStage.examOffer;
      _messages.add(LecturerMessage(
        text: '🎓 **Congratulations!** You have completed all chapters of '
            '**$_courseName**. Excellent work!\n\n'
            'Would you like to take a short exam to test what you\'ve learned?',
        type:      LecturerMessageType.system,
        timestamp: DateTime.now(),
      ));
      await _saveState();
      notifyListeners();
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Final exam
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> respondToExamOffer(bool wantsExam) async {
    if (_courseStage != CourseStage.examOffer) return;

    _messages.add(LecturerMessage(
      text:      wantsExam ? 'Yes, let\'s do the exam!' : 'No thanks, I\'m done.',
      type:      LecturerMessageType.studentAnswer,
      timestamp: DateTime.now(),
    ));

    if (!wantsExam) {
      _courseStage = CourseStage.completed;
      _messages.add(LecturerMessage(
        text: '🏁 **$_courseName** marked as complete. Great job — '
            'come back anytime to review chapters or start a new course!',
        type:      LecturerMessageType.system,
        timestamp: DateTime.now(),
      ));
      await _saveState();
      notifyListeners();
      return;
    }

    _state = LecturerState.examLoading;
    _error = null;
    notifyListeners();

    try {
      final data = await ApiClient.generateLecturerExam(
        courseName: _courseName,
        courseCode: _courseCode.isNotEmpty ? _courseCode : null,
        chapters:   _curriculum!.chapters.map((c) => c.toJson()).toList(),
        level:      _level,
      );

      final parsed = jsonDecode(data['exam_json'] as String) as Map<String, dynamic>;
      _examQuestions = (parsed['questions'] as List)
          .map((q) => ExamQuestion.fromJson(q as Map<String, dynamic>))
          .toList();

      _courseStage = CourseStage.examInProgress;
      _messages.add(LecturerMessage(
        text: '📝 **Final Exam — ${_examQuestions.length} Questions**\n\n'
            'Answer each question to the best of your ability, then submit '
            'to see your score.',
        type:      LecturerMessageType.system,
        timestamp: DateTime.now(),
      ));

      _state = LecturerState.idle;
      await _saveState();
    } catch (e) {
      _error = 'Could not generate the exam. Please try again.';
      _state = LecturerState.error;
      _courseStage = CourseStage.examOffer;
    }
    notifyListeners();
  }

  /// Submit all exam answers for grading. `answers` maps question id → text.
  Future<void> submitExam(Map<int, String> answers) async {
    if (_courseStage != CourseStage.examInProgress) return;

    _state = LecturerState.examGrading;
    _error = null;
    notifyListeners();

    try {
      final data = await ApiClient.gradeLecturerExam(
        courseName: _courseName,
        courseCode: _courseCode.isNotEmpty ? _courseCode : null,
        questions:  _examQuestions.map((q) => q.toJson()).toList(),
        answers:    answers.entries
            .map((e) => {'id': e.key, 'answer': e.value})
            .toList(),
        level: _level,
      );

      final parsed = jsonDecode(data['result_json'] as String) as Map<String, dynamic>;
      _examResult = ExamResult.fromJson(parsed);
      _courseStage = CourseStage.examResult;

      final pct = _examResult!.total > 0
          ? (_examResult!.score / _examResult!.total * 100).round()
          : 0;
      _messages.add(LecturerMessage(
        text: '🏆 **Exam Result: ${_examResult!.score.toStringAsFixed(1)} / '
            '${_examResult!.total} ($pct%)**\n\n${_examResult!.overallFeedback}',
        type:      LecturerMessageType.feedback,
        timestamp: DateTime.now(),
      ));

      _state = LecturerState.idle;
      await _saveState(forceCompleted: true);
    } catch (e) {
      _error = 'Could not grade the exam. Please try again.';
      _state = LecturerState.error;
    }
    notifyListeners();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Persistence
  // ══════════════════════════════════════════════════════════════════════════

  /// Last ~10 history turns — enough context for follow-up questions/answers
  /// without sending the entire course transcript on every request.
  List<Map<String, String>> _recentHistory() {
    if (_history.length <= 10) return List.of(_history);
    return _history.sublist(_history.length - 10);
  }

  Future<void> _saveState({bool forceCompleted = false}) async {
    if (_courseId == null) return;

    final stateMap = {
      'current_chapter_index': _currentChapterIndex,
      'course_stage':          _stageToJson(_courseStage),
      'chapters':              _chapters.map((c) => c.toJson()).toList(),
      'messages':              _messages.map((m) => m.toJson()).toList(),
      'history':               _history,
      if (_examQuestions.isNotEmpty)
        'exam_questions': _examQuestions.map((q) => q.toJson()).toList(),
      if (_examResult != null)
        'exam_result': _examResult!.toJson(),
    };

    final status = forceCompleted || _courseStage == CourseStage.completed ||
            _courseStage == CourseStage.examResult
        ? 'completed'
        : 'in_progress';
    final progress = status == 'completed' ? 100.0 : overallProgress * 100;

    try {
      await ApiClient.updateLecturerCourseState(
        courseId:        _courseId!,
        stateJson:       jsonEncode(stateMap),
        progressPercent: progress,
        status:          status,
        examJson: _examResult != null ? jsonEncode(_examResult!.toJson()) : null,
      );
    } catch (_) {
      // Non-fatal — progress will be saved on the next successful step.
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Reset / errors
  // ══════════════════════════════════════════════════════════════════════════

  void _resetSessionFields() {
    _courseId = null;
    _curriculum = null;
    _chapters.clear();
    _messages.clear();
    _history.clear();
    _currentChapterIndex = 0;
    _courseStage = CourseStage.teaching;
    _examQuestions = [];
    _examResult = null;
  }

  /// Returns to the resume list (does NOT delete the saved course).
  void reset() {
    _state = LecturerState.idle;
    _error = null;
    _resetSessionFields();
    _courseName = '';
    _courseCode = '';
    _level      = 'intermediate';
    notifyListeners();
    // Refresh the resume list so the just-exited course shows updated progress.
    loadHomeData();
  }

  void clearError() {
    _error = null;
    if (_state == LecturerState.error) _state = LecturerState.idle;
    notifyListeners();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Extract the check question text from the AI lesson.
  /// The AI is instructed to place it after "✅ Check Your Understanding".
  String? _extractCheckQuestion(String lesson) {
    const marker = 'Check Your Understanding';
    final idx = lesson.indexOf(marker);
    if (idx == -1) return null;

    final after = lesson.substring(idx + marker.length);
    final lines = after.split('\n');
    for (final line in lines) {
      final trimmed = line
          .replaceAll('**', '')
          .replaceAll('*', '')
          .replaceAll('#', '')
          .trim();
      if (trimmed.isNotEmpty &&
          !trimmed.startsWith('---') &&
          trimmed.length > 10) {
        return trimmed;
      }
    }
    return null;
  }
}
