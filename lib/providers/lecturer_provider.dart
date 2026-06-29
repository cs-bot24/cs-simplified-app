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
      _messages.add(LecturerMessage(
        text: 'Yes, I have a question',
        type: LecturerMessageType.studentAnswer,
        timestamp: DateTime.now(),
      ));
    } else {
      chap.phase = ChapterPhase.awaitingCheckAnswer;
      _messages.add(LecturerMessage(
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
    // Guard 1: must have an active chapter with a check question.
    if (chap == null || chap.checkQuestion == null) return;
    // Guard 2: must be in the correct phase — never route to AI while teaching
    // or in Q&A, even if checkQuestion happens to be set from a previous chapter.
    if (chap.phase != ChapterPhase.awaitingCheckAnswer) return;
    // Guard 3: politely ask for an answer if the field is empty (and student
    // claims to know). Do NOT call the AI or trigger the offline fallback.
    if (knowsAnswer && answer.trim().isEmpty) {
      _messages.add(LecturerMessage(
        text: 'Please type your answer in the box above, then tap Submit.',
        type: LecturerMessageType.system,
        timestamp: DateTime.now(),
      ));
      notifyListeners();
      return;
    }

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
      // Send only the last 2 history turns for answer evaluation.
      // The API prompt already contains full context (chapter title, question,
      // student answer). Sending a large history here causes provider token
      // limits to be hit, which triggers the offline emergency responder and
      // returns a Study Note instead of AI feedback.
      final data = await ApiClient.evaluateCheckAnswer(
        chapterTitle:        chap.chapter.title,
        checkQuestion:       chap.checkQuestion!,
        studentAnswer:       answer,
        studentKnowsAnswer:  knowsAnswer,
        level:               _level,
        conversationHistory: _checkHistory(),
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

  /// Focused history for check-answer evaluation: last 2 turns only.
  ///
  /// The check-answer API prompt already contains the chapter title, the exact
  /// question, and the student's answer — everything the AI needs to evaluate.
  /// Sending a full lesson history on top pushes many requests past provider
  /// token limits (each lesson is 2000-4000 chars × 10 turns = 40 KB+), which
  /// exhausts all providers and causes the emergency responder to fire, returning
  /// an offline "Study Note" instead of AI feedback.
  List<Map<String, String>> _checkHistory() {
    if (_history.isEmpty) return [];
    // Keep at most the last assistant turn (the lesson) so the AI knows the
    // context, but no more.
    return _history.length >= 2
        ? _history.sublist(_history.length - 2)
        : List.of(_history);
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
  ///
  /// In JSON mode, lesson is a blocks JSON string. The question lives in the
  /// last [exercise] block. The json_validator normalises the field to
  /// "content", but if the AI emits both "content": "" and "text": "...",
  /// the validator may leave content blank — so we check both fields.
  ///
  /// In legacy markdown mode, scan the plain text for the marker heading.
  String? _extractCheckQuestion(String lesson) {
    // ── Attempt 1: Parse as JSON blocks (JSON / _JSON_MODE path) ─────────
    try {
      String src = lesson.trim();
      // Strip ```json fences if present
      src = src.replaceAll(RegExp(r'''```(?:json)?\s*'''), '').trim();
      final braceStart = src.indexOf('{');
      if (braceStart >= 0) {
        if (braceStart > 0) src = src.substring(braceStart);
        final decoded = jsonDecode(src) as Map<String, dynamic>?;
        if (decoded != null && decoded['blocks'] is List) {
          final blocks = decoded['blocks'] as List;

          // Priority 1: last exercise block = the check question.
          // Check both "content" and "text" fields — the AI sometimes returns
          // one or the other, and edge cases can leave "content" blank while
          // "text" holds the actual question.
          for (int i = blocks.length - 1; i >= 0; i--) {
            final b = blocks[i] as Map<String, dynamic>?;
            if (b == null) continue;
            if (b['type'] == 'exercise') {
              final q = ((b['content'] as String? ?? '').isNotEmpty
                      ? b['content']
                      : b['text'] as String? ?? '')
                  .trim();
              if (q.isNotEmpty) return q;
            }
          }

          // Priority 2: first content block after a "Check Your Understanding" heading
          bool afterCheck = false;
          for (final b in blocks) {
            final block = b as Map<String, dynamic>?;
            if (block == null) continue;
            final blockText = ((block['text'] ?? block['content']) as String? ?? '');
            if (!afterCheck) {
              if (blockText.toLowerCase().contains('check your understanding')) {
                afterCheck = true;
              }
            } else {
              final c = blockText.trim();
              if (c.isNotEmpty && c.length > 10) return c;
            }
          }
        }
      }
    } catch (_) {
      // JSON parse failed — fall through to legacy text extraction
    }

    // ── Attempt 2: Legacy plain-text marker scan (markdown / legacy mode) ─
    const marker = 'Check Your Understanding';
    final idx = lesson.indexOf(marker);
    if (idx == -1) return null;

    final after = lesson.substring(idx + marker.length);
    for (final line in after.split('\n')) {
      final trimmed = line
          .replaceAll('**', '')
          .replaceAll('*', '')
          .replaceAll('#', '')
          .trim();
      // Skip JSON artifacts that leak into the raw string
      if (trimmed.isNotEmpty &&
          !trimmed.startsWith('---') &&
          !trimmed.startsWith('"') &&
          !trimmed.startsWith('{') &&
          trimmed.length > 10) {
        return trimmed;
      }
    }
    return null;
  }
}
