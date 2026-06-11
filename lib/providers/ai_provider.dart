// lib/providers/ai_provider.dart
//
// Platform-adaptive AI provider.
//
// The only platform-specific code in this file is image handling:
//
//   Mobile: askWithImage(File)       — reads bytes from dart:io File
//   Web:    askWithImageBytes(Uint8List) — bytes already in memory
//           from file_picker or image_picker web result
//
// Everything else (text chat, PDF context, practice questions,
// study notes, session memory) is identical on all platforms.

import 'dart:convert';
import 'package:flutter/foundation.dart' show Uint8List;
import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../models/ai_model.dart';

// dart:io is not available on web — conditional import
import 'ai_provider_io.dart' if (dart.library.html) 'ai_provider_web.dart';

enum AiState { idle, loading, error }

class AiProvider extends ChangeNotifier {
  final List<AiMessage> _messages = [];
  AiState          _state          = AiState.idle;
  String?          _error;
  AiMode           _mode           = AiMode.normal;
  ExplanationLevel _level          = ExplanationLevel.intermediate;
  AiPlanInfo?      _plan;
  int              _questionsToday  = 0;
  int              _questionsMonth  = 0;

  // ── Phase 3: Session memory ───────────────────────────────────────────────
  // Tracks topics and concepts discussed in this session so that
  // Practice Questions and Study Notes are generated from actual session
  // content rather than random topics.
  final List<String> _sessionTopics   = [];  // subjects detected (e.g. "Computer Science")
  final List<String> _sessionConcepts = [];  // key terms extracted from AI responses
  String?            _sessionSummary;        // running plain-text summary of recent questions

  List<AiMessage>  get messages        => List.unmodifiable(_messages);
  AiState          get state           => _state;
  String?          get error           => _error;
  bool             get loading         => _state == AiState.loading;
  AiMode           get mode            => _mode;
  ExplanationLevel get level           => _level;
  AiPlanInfo?      get plan            => _plan;
  int              get questionsToday  => _questionsToday;
  int              get questionsMonth  => _questionsMonth;
  bool             get isExamPrep      => _mode == AiMode.examPrep;

  // Session memory — exposed so UI can show "X topics studied" and
  // so dialogs know whether to show the "From this session" badge.
  List<String> get sessionTopics    => List.unmodifiable(_sessionTopics);
  List<String> get sessionConcepts  => List.unmodifiable(_sessionConcepts);
  bool         get hasSessionContext => _sessionTopics.isNotEmpty;

  // ── Mode & Level ──────────────────────────────────────────────────────────

  void setMode(AiMode m) { _mode = m; notifyListeners(); }

  void toggleExamPrep() {
    _mode = _mode == AiMode.examPrep ? AiMode.normal : AiMode.examPrep;
    notifyListeners();
  }

  Future<void> setLevel(ExplanationLevel l) async {
    _level = l;
    notifyListeners();
    try { await ApiClient.updateAiPreferences(l.name); } catch (_) {}
  }

  // ── Load plan & preferences ───────────────────────────────────────────────

  Future<void> loadPlan() async {
    try {
      final data = await ApiClient.getAiPlan();
      _plan = AiPlanInfo.fromJson(data);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> loadUsage() async {
    try {
      final data = await ApiClient.getAiUsage();
      _questionsToday = (data['questions_today']      as num?)?.toInt() ?? 0;
      _questionsMonth = (data['questions_this_month'] as num?)?.toInt() ?? 0;
      final savedLevel = data['preferred_level'] as String?;
      if (savedLevel != null) {
        _level = ExplanationLevel.values.firstWhere(
          (e) => e.name == savedLevel,
          orElse: () => ExplanationLevel.intermediate,
        );
      }
      notifyListeners();
    } catch (_) {}
  }

  // ── Ask (text only) ───────────────────────────────────────────────────────

  Future<void> ask(String question) async {
    await _sendRequest(question: question);
  }

  // ── Ask with image — MOBILE path ─────────────────────────────────────────
  // Uses dart:io File via the conditional import shim.
  // Not called on web — use askWithImageBytes() instead.

  Future<void> askWithImage(dynamic imageFile, {String extraText = ''}) async {
    final bytes = await readImageBytes(imageFile);
    final b64   = base64Encode(bytes);
    final path  = getImagePath(imageFile);
    final mime  = path.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';
    await _sendRequest(
      question:      extraText,
      imageBase64:   b64,
      imageMimeType: mime,
      isImage:       true,
    );
  }

  // ── Ask with image — WEB path ─────────────────────────────────────────────
  // file_picker and image_picker return Uint8List on web.
  // Called from ai_tutor_screen.dart when kIsWeb is true.

  Future<void> askWithImageBytes(
    Uint8List bytes, {
    String extraText = '',
    String mimeType  = 'image/jpeg',
  }) async {
    final b64 = base64Encode(bytes);
    await _sendRequest(
      question:      extraText,
      imageBase64:   b64,
      imageMimeType: mimeType,
      isImage:       true,
    );
  }

  // ── Ask from PDF Reader (Phase 2C) ────────────────────────────────────────

  Future<void> askFromPdf({
    required String question,
    int?    materialId,
    String? materialTitle,
    String? courseCode,
    String? levelName,
    String? categoryName,
  }) async {
    await _sendRequest(
      question:         question,
      pdfMaterialId:    materialId,
      pdfMaterialTitle: materialTitle,
      pdfCourseCode:    courseCode,
      pdfLevelName:     levelName,
      pdfCategoryName:  categoryName,
    );
  }

  // ── Generate from page text (PDF quick actions) ───────────────────────────

  Future<String?> generateFromPageText({
    required String pageText,
    required String action,
    String? materialTitle,
    String? courseCode,
  }) async {
    _state = AiState.loading;
    _error = null;
    notifyListeners();

    final prompt = switch (action) {
      'explain' => 'Summarise and explain the following course material. '
          'Extract key concepts, definitions, and anything important for exams:\n\n$pageText',
      'notes'   => 'Generate structured study notes from the following course material. '
          'Include: Key Concepts, Definitions, Important Points, and Exam Tips:\n\n$pageText',
      'quiz'    => 'Generate 5 exam-style questions (mix of multiple choice and short answer) '
          'based on the following course material. Include correct answers:\n\n$pageText',
      _         => pageText,
    };

    try {
      final data = await ApiClient.askAi(
        question:         prompt,
        mode:             'normal',
        level:            _level.name,
        pdfMaterialTitle: materialTitle,
        pdfCourseCode:    courseCode,
      );
      _state = AiState.idle;
      notifyListeners();
      return data['response'] as String?;
    } on ApiException catch (e) {
      _error = e.message; _state = AiState.error; notifyListeners();
    } catch (_) {
      _error = 'Could not process request. Please try again.';
      _state = AiState.error; notifyListeners();
    }
    return null;
  }

  // ── Practice questions (Phase 3: session-context aware) ──────────────────
  // Priority 1: session topics + concepts from this session.
  // Priority 2: falls back to the plain topic string.

  Future<String?> generatePracticeQuestions(String topic) async {
    _state = AiState.loading;
    _error = null;
    notifyListeners();
    try {
      final data = await ApiClient.generatePracticeQuestions(
        topic:           topic,
        level:           _level.name,
        sessionTopics:   _sessionTopics.isNotEmpty   ? _sessionTopics   : null,
        sessionConcepts: _sessionConcepts.isNotEmpty ? _sessionConcepts : null,
      );
      _state = AiState.idle;
      notifyListeners();
      return data['questions'] as String?;
    } on ApiException catch (e) {
      _error = e.message; _state = AiState.error; notifyListeners();
    } catch (_) {
      _error = 'Could not generate practice questions. Please try again.';
      _state = AiState.error; notifyListeners();
    }
    return null;
  }

  // ── Study notes (Phase 3: session-context aware) ─────────────────────────
  // When session topics exist, notes summarise the actual session content.

  Future<String?> generateStudyNotes(String topic) async {
    _state = AiState.loading;
    _error = null;
    notifyListeners();
    try {
      final data = await ApiClient.generateStudyNotes(
        topic:          topic,
        level:          _level.name,
        sessionTopics:  _sessionTopics.isNotEmpty ? _sessionTopics : null,
        sessionSummary: _sessionSummary,
      );
      _state = AiState.idle;
      notifyListeners();
      return data['notes'] as String?;
    } on ApiException catch (e) {
      _error = e.message; _state = AiState.error; notifyListeners();
    } catch (_) {
      _error = 'Could not generate study notes. Please try again.';
      _state = AiState.error; notifyListeners();
    }
    return null;
  }

  // ── Core request ──────────────────────────────────────────────────────────

  Future<void> _sendRequest({
    required String question,
    String? imageBase64,
    String? imageMimeType,
    bool    isImage          = false,
    int?    pdfMaterialId,
    String? pdfMaterialTitle,
    String? pdfCourseCode,
    String? pdfLevelName,
    String? pdfCategoryName,
  }) async {
    final trimmed = question.trim();
    if (trimmed.isEmpty && imageBase64 == null) return;

    _messages.add(AiMessage(
      text: isImage
          ? (trimmed.isEmpty ? '📷 Image question' : '📷 $trimmed')
          : trimmed,
      isUser:    true,
      timestamp: DateTime.now(),
      isImage:   isImage,
      mode:      _mode,
    ));
    _state = AiState.loading;
    _error = null;
    notifyListeners();

    try {
      final data = await ApiClient.askAi(
        question:         trimmed,
        mode:             _mode == AiMode.examPrep ? 'exam_prep' : 'normal',
        level:            _level.name,
        imageBase64:      imageBase64,
        imageMimeType:    imageMimeType,
        pdfMaterialId:    pdfMaterialId,
        pdfMaterialTitle: pdfMaterialTitle,
        pdfCourseCode:    pdfCourseCode,
        pdfLevelName:     pdfLevelName,
        pdfCategoryName:  pdfCategoryName,
      );

      final aiMessage = AiMessage(
        text:      data['response'] as String,
        isUser:    false,
        timestamp: DateTime.now(),
        subject:   data['subject'] as String?,
        mode:      _mode,
      );

      _messages.add(aiMessage);
      _questionsToday++;
      _questionsMonth++;
      _state = AiState.idle;

      // ── Phase 3: Update session memory after every successful response ──
      _updateSessionMemory(
        userQuestion: trimmed,
        aiResponse:   aiMessage.text,
        subject:      aiMessage.subject,
      );

    } on ApiException catch (e) {
      _error = e.message;
      _state = AiState.error;
      if (_messages.isNotEmpty && _messages.last.isUser) _messages.removeLast();
    } catch (_) {
      _error = 'AI service is temporarily unavailable. Please try again later.';
      _state = AiState.error;
      if (_messages.isNotEmpty && _messages.last.isUser) _messages.removeLast();
    }
    notifyListeners();
  }

  // ── Phase 3: Session memory update ───────────────────────────────────────
  // Called after each successful AI response.
  // Records the subject, extracts key term labels from the structured
  // markdown response, and keeps a rolling summary of recent questions.

  void _updateSessionMemory({
    required String  userQuestion,
    required String  aiResponse,
    String?          subject,
  }) {
    // 1. Track unique subjects / topics
    if (subject != null &&
        subject.isNotEmpty &&
        !_sessionTopics.contains(subject)) {
      _sessionTopics.add(subject);
    }

    // 2. Extract labelled concepts from the AI's structured response.
    //    Looks for lines like "**Term**:" or "Term:" that appear in the
    //    teaching format the AI uses (Definition, Key Point, etc.).
    final conceptPattern = RegExp(
      r'(?:^|\n)\*{0,2}([A-Z][A-Za-z\s]{2,30})\*{0,2}:(?!\s*/)',
      multiLine: true,
    );
    for (final match in conceptPattern.allMatches(aiResponse)) {
      final concept = match.group(1)?.trim();
      if (concept != null &&
          concept.length > 2 &&
          concept.length < 40 &&
          !_sessionConcepts.contains(concept) &&
          _sessionConcepts.length < 30) {
        _sessionConcepts.add(concept);
      }
    }

    // 3. Rolling summary — last 5 non-image user questions
    final recentQuestions = _messages
        .where((m) => m.isUser && m.text.isNotEmpty && !m.isImage)
        .map((m) => m.text)
        .toList();
    if (recentQuestions.length > 5) {
      recentQuestions.removeRange(0, recentQuestions.length - 5);
    }
    if (recentQuestions.isNotEmpty) {
      _sessionSummary = 'Topics asked: ${recentQuestions.join('; ')}';
    }
  }

  // ── Utility ───────────────────────────────────────────────────────────────

  void clearError() {
    _error = null;
    _state = AiState.idle;
    notifyListeners();
  }

  void clearConversation() {
    _messages.clear();
    _error = null;
    _state = AiState.idle;
    // Clear session memory alongside the conversation
    _sessionTopics.clear();
    _sessionConcepts.clear();
    _sessionSummary = null;
    notifyListeners();
  }
}
