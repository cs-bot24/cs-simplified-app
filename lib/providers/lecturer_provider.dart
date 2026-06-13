// lib/providers/lecturer_provider.dart
//
// State management for AI Lecturer — Structured Teaching Mode.
//
// Flow:
//   1. Student sets course name + code + level → loadCurriculum()
//   2. Curriculum loads → chapter list shown
//   3. Student taps first chapter → loadChapter(0)
//   4. AI delivers lesson → state = checking
//   5. Student types answer → submitCheckAnswer(answer)
//   6. AI gives feedback → student taps Next Chapter
//   7. Repeat from step 3 for each chapter

import 'dart:convert';
import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../models/lecturer_model.dart';

enum LecturerState { idle, loadingCurriculum, loadingLesson, checking, error }

class LecturerProvider extends ChangeNotifier {

  // ── State ─────────────────────────────────────────────────────────────────
  LecturerState        _state      = LecturerState.idle;
  String?              _error;
  LecturerCurriculum?  _curriculum;
  int                  _currentChapterIndex = 0;
  final List<ChapterProgress> _chapters = [];
  final List<LecturerMessage> _messages = [];
  final List<Map<String, String>> _history = [];  // sent to backend

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

  ChapterProgress? get currentChapter =>
      _chapters.isNotEmpty && _currentChapterIndex < _chapters.length
          ? _chapters[_currentChapterIndex]
          : null;

  bool get isLastChapter =>
      _curriculum != null && _currentChapterIndex >= _chapters.length - 1;

  double get overallProgress {
    if (_chapters.isEmpty) return 0;
    final passed = _chapters.where((c) => c.state == ChapterState.passed).length;
    return passed / _chapters.length;
  }

  // ── Session setup ─────────────────────────────────────────────────────────

  void setSession({
    required String courseName,
    required String courseCode,
    required String level,
  }) {
    _courseName = courseName;
    _courseCode = courseCode;
    _level      = level;
  }

  // ── Load curriculum ───────────────────────────────────────────────────────

  Future<void> loadCurriculum() async {
    if (_courseName.isEmpty) return;

    _state = LecturerState.loadingCurriculum;
    _error = null;
    _chapters.clear();
    _messages.clear();
    _history.clear();
    _currentChapterIndex = 0;
    notifyListeners();

    try {
      final data = await ApiClient.getLecturerCurriculum(
        courseName: _courseName,
        courseCode: _courseCode.isNotEmpty ? _courseCode : null,
        level:      _level,
      );

      final jsonStr = data['curriculum_json'] as String;
      final parsed  = jsonDecode(jsonStr) as Map<String, dynamic>;
      _curriculum   = LecturerCurriculum.fromJson(parsed);

      // Build chapter progress list
      for (int i = 0; i < _curriculum!.chapters.length; i++) {
        _chapters.add(ChapterProgress(
          chapter: _curriculum!.chapters[i],
          state:   i == 0 ? ChapterState.current : ChapterState.locked,
        ));
      }

      // Welcome message
      _messages.add(LecturerMessage(
        text: '📚 **${_curriculum!.courseName}** curriculum is ready!\n\n'
            'Your course has **${_curriculum!.totalChapters} chapters** '
            'over approximately **${_curriculum!.estimatedWeeks} weeks**.\n\n'
            'Tap **Chapter 1** to begin your first lesson.',
        type:      LecturerMessageType.system,
        timestamp: DateTime.now(),
      ));

      _state = LecturerState.idle;
    } catch (e) {
      _error = 'Could not generate curriculum. Please try again.';
      _state = LecturerState.error;
    }
    notifyListeners();
  }

  // ── Load and deliver a chapter lesson ─────────────────────────────────────

  Future<void> loadChapter(int index) async {
    if (index >= _chapters.length) return;
    final chap = _chapters[index];
    if (chap.state == ChapterState.locked) return;

    // If already loaded, just scroll to it (idempotent)
    if (chap.lessonText != null && chap.state == ChapterState.checking) return;

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
        conversationHistory: _history,
      );

      final lesson = data['lesson'] as String;
      chap.lessonText = lesson;
      chap.state      = ChapterState.checking;

      // Extract the check question from the lesson text
      chap.checkQuestion = _extractCheckQuestion(lesson);

      // Add to display messages
      _messages.add(LecturerMessage(
        text:      lesson,
        type:      LecturerMessageType.lesson,
        timestamp: DateTime.now(),
      ));

      // Add to history for context in future chapters
      _history.add({'role': 'assistant', 'content': lesson});

      _state = LecturerState.idle;
    } catch (e) {
      _error = 'Could not load chapter. Please try again.';
      _state = LecturerState.error;
    }
    notifyListeners();
  }

  // ── Submit answer to check question ───────────────────────────────────────

  Future<void> submitCheckAnswer(String answer) async {
    final chap = currentChapter;
    if (chap == null || chap.checkQuestion == null) return;
    if (answer.trim().isEmpty) return;

    // Add student's answer to display
    _messages.add(LecturerMessage(
      text:      answer,
      type:      LecturerMessageType.studentAnswer,
      timestamp: DateTime.now(),
    ));

    // Add to history
    _history.add({'role': 'user', 'content': answer});

    _state = LecturerState.checking;
    _error = null;
    notifyListeners();

    try {
      final data = await ApiClient.evaluateCheckAnswer(
        chapterTitle:        chap.chapter.title,
        checkQuestion:       chap.checkQuestion!,
        studentAnswer:       answer,
        level:               _level,
        conversationHistory: _history,
      );

      final feedback = data['feedback'] as String;
      chap.checkFeedback = feedback;

      _messages.add(LecturerMessage(
        text:      feedback,
        type:      LecturerMessageType.feedback,
        timestamp: DateTime.now(),
      ));

      _history.add({'role': 'assistant', 'content': feedback});

      _state = LecturerState.idle;
    } catch (e) {
      _error = 'Could not evaluate your answer. Please try again.';
      _state = LecturerState.error;
    }
    notifyListeners();
  }

  // ── Advance to next chapter ───────────────────────────────────────────────

  Future<void> advanceToNextChapter() async {
    final chap = currentChapter;
    if (chap == null) return;

    // Mark current chapter as passed
    chap.state = ChapterState.passed;

    final nextIndex = _currentChapterIndex + 1;
    if (nextIndex < _chapters.length) {
      // Unlock next chapter
      _chapters[nextIndex].state = ChapterState.current;
      _currentChapterIndex = nextIndex;

      // System message
      _messages.add(LecturerMessage(
        text:      '🎉 Chapter ${chap.chapter.index} complete! '
            'Moving to **Chapter ${_chapters[nextIndex].chapter.index}: '
            '${_chapters[nextIndex].chapter.title}**.',
        type:      LecturerMessageType.system,
        timestamp: DateTime.now(),
      ));

      notifyListeners();

      // Auto-load the next chapter
      await loadChapter(nextIndex);
    } else {
      // Course complete
      _messages.add(LecturerMessage(
        text: '🎓 **Congratulations!** You have completed all chapters of '
            '**$_courseName**. Excellent work!',
        type:      LecturerMessageType.system,
        timestamp: DateTime.now(),
      ));
      notifyListeners();
    }
  }

  // ── Reset (start a new course) ────────────────────────────────────────────

  void reset() {
    _state      = LecturerState.idle;
    _error      = null;
    _curriculum = null;
    _chapters.clear();
    _messages.clear();
    _history.clear();
    _currentChapterIndex = 0;
    _courseName = '';
    _courseCode = '';
    _level      = 'intermediate';
    notifyListeners();
  }

  void clearError() {
    _error = null;
    _state = LecturerState.idle;
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
    // Find the next paragraph/line that isn't empty or a heading marker
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
