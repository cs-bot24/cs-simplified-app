// lib/providers/ai_provider.dart
//
// Platform-adaptive AI provider — Phase 4: Conversation Memory
//
// Phase 4 changes:
//   Every AI request now sends the live in-memory conversation history
//   so the AI can answer follow-up questions correctly:
//     "explain again" / "make it simpler" / "write the code" /
//     "why?" / "continue" / "solve question 2"
//
//   _buildConversationHistory() serialises _messages into
//   [{role, content}] and caps at the last _kMaxHistoryTurns turns.
//
//   PDF AI uses a separate history list (_pdfMessages) so the
//   general chat and PDF tutoring session memories don't mix.
//
// Platform image handling (unchanged):
//   Mobile: askWithImage(File)          — dart:io shim
//   Web:    askWithImageBytes(Uint8List) — bytes from file_picker

import 'dart:convert';
import 'package:flutter/foundation.dart' show Uint8List;
import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../models/ai_model.dart';

import 'ai_provider_io.dart' if (dart.library.html) 'ai_provider_web.dart';

enum AiState { idle, loading, error }

// Rolling window: last 20 turns sent to the AI (10 exchanges).
// Keeps token usage reasonable while covering enough context.
const int _kMaxHistoryTurns = 20;

class AiProvider extends ChangeNotifier {

  // ── General AI chat messages ──────────────────────────────────────────────
  final List<AiMessage> _messages = [];

  // ── PDF AI chat messages (separate memory per PDF session) ───────────────
  // The PDF AI keeps its own conversation history so a student can ask
  // continuous follow-up questions while studying a specific material,
  // without mixing context with the general AI chat.
  final List<AiMessage> _pdfMessages = [];

  AiState          _state         = AiState.idle;
  String?          _error;
  AiMode           _mode          = AiMode.normal;
  ExplanationLevel _level         = ExplanationLevel.intermediate;
  AiPlanInfo?      _plan;
  int              _questionsToday = 0;
  int              _questionsMonth = 0;

  // ── Phase 3: Session memory (topics / concepts for practice & notes) ─────
  final List<String> _sessionTopics   = [];
  final List<String> _sessionConcepts = [];
  String?            _sessionSummary;

  // ── Public getters ────────────────────────────────────────────────────────

  List<AiMessage>  get messages        => List.unmodifiable(_messages);
  List<AiMessage>  get pdfMessages     => List.unmodifiable(_pdfMessages);
  AiState          get state           => _state;
  String?          get error           => _error;
  bool             get loading         => _state == AiState.loading;
  AiMode           get mode            => _mode;
  ExplanationLevel get level           => _level;
  AiPlanInfo?      get plan            => _plan;
  int              get questionsToday  => _questionsToday;
  int              get questionsMonth  => _questionsMonth;
  bool             get isExamPrep      => _mode == AiMode.examPrep;

  List<String>     get sessionTopics   => List.unmodifiable(_sessionTopics);
  List<String>     get sessionConcepts => List.unmodifiable(_sessionConcepts);
  bool             get hasSessionContext => _sessionTopics.isNotEmpty;

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
      final data        = await ApiClient.getAiUsage();
      _questionsToday   = (data['questions_today']      as num?)?.toInt() ?? 0;
      _questionsMonth   = (data['questions_this_month'] as num?)?.toInt() ?? 0;
      final savedLevel  = data['preferred_level'] as String?;
      if (savedLevel != null) {
        _level = ExplanationLevel.values.firstWhere(
          (e) => e.name == savedLevel,
          orElse: () => ExplanationLevel.intermediate,
        );
      }
      notifyListeners();
    } catch (_) {}
  }

  // ── Phase 4: Build conversation history ──────────────────────────────────
  //
  // Converts the in-memory AiMessage list into the [{role, content}] format
  // the backend expects.
  //
  // Rules:
  //   - Image messages are excluded (can't be replayed as text turns).
  //   - Capped at _kMaxHistoryTurns most recent turns.
  //   - Does NOT include the current message being sent (that's the question).

  List<Map<String, String>> _buildConversationHistory([
    List<AiMessage>? source,
  ]) {
    final src = source ?? _messages;
    // Exclude the last message if it's the user turn we're about to send
    // (it hasn't received a response yet, so we take all completed pairs).
    final completed = src.where((m) => !m.isImage).toList();

    // Take the last _kMaxHistoryTurns turns
    final window = completed.length > _kMaxHistoryTurns
        ? completed.sublist(completed.length - _kMaxHistoryTurns)
        : completed;

    return window.map((m) => {
      'role':    m.isUser ? 'user' : 'assistant',
      'content': m.text,
    }).toList();
  }

  // ── Ask (text only — General AI) ─────────────────────────────────────────

  Future<void> ask(String question) async {
    await _sendRequest(question: question);
  }

  // ── Ask with image — MOBILE path ─────────────────────────────────────────

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

  // ── Ask from PDF Reader ───────────────────────────────────────────────────
  // Uses _pdfMessages for its own conversation history so the PDF tutoring
  // session is independent from the general AI chat session.

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
      isPdfRequest:     true,
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
        question:             prompt,
        mode:                 'normal',
        level:                _level.name,
        pdfMaterialTitle:     materialTitle,
        pdfCourseCode:        courseCode,
        // Include PDF session history so the AI has context for quick actions
        conversationHistory:  _buildConversationHistory(_pdfMessages),
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

  // ── Practice questions (session-context aware) ────────────────────────────

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

  // ── Study notes (session-context aware) ──────────────────────────────────

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
    bool    isPdfRequest     = false,
    int?    pdfMaterialId,
    String? pdfMaterialTitle,
    String? pdfCourseCode,
    String? pdfLevelName,
    String? pdfCategoryName,
  }) async {
    final trimmed = question.trim();
    if (trimmed.isEmpty && imageBase64 == null) return;

    // Add user message to the correct message list
    final messageList = isPdfRequest ? _pdfMessages : _messages;
    final userMsg = AiMessage(
      text:      isImage
          ? (trimmed.isEmpty ? '📷 Image question' : '📷 $trimmed')
          : trimmed,
      isUser:    true,
      timestamp: DateTime.now(),
      isImage:   isImage,
      mode:      _mode,
    );
    messageList.add(userMsg);

    _state = AiState.loading;
    _error = null;
    notifyListeners();

    // ── Phase 4: Build history from all messages BEFORE this new question ──
    // We exclude the user message we just added (it's the question being sent).
    // The history is everything before it — completed exchanges only.
    final historySource = messageList.sublist(0, messageList.length - 1);
    final history = _buildConversationHistory(historySource);

    try {
      final data = await ApiClient.askAi(
        question:            trimmed,
        mode:                _mode == AiMode.examPrep ? 'exam_prep' : 'normal',
        level:               _level.name,
        imageBase64:         imageBase64,
        imageMimeType:       imageMimeType,
        pdfMaterialId:       pdfMaterialId,
        pdfMaterialTitle:    pdfMaterialTitle,
        pdfCourseCode:       pdfCourseCode,
        pdfLevelName:        pdfLevelName,
        pdfCategoryName:     pdfCategoryName,
        conversationHistory: history,
      );

      final aiMessage = AiMessage(
        text:      data['response'] as String,
        isUser:    false,
        timestamp: DateTime.now(),
        subject:   data['subject'] as String?,
        mode:      _mode,
      );

      messageList.add(aiMessage);
      _questionsToday++;
      _questionsMonth++;
      _state = AiState.idle;

      // Update session memory (general chat only — not PDF sessions)
      if (!isPdfRequest) {
        _updateSessionMemory(
          userQuestion: trimmed,
          aiResponse:   aiMessage.text,
          subject:      aiMessage.subject,
        );
      }

    } on ApiException catch (e) {
      _error = e.message;
      _state = AiState.error;
      if (messageList.isNotEmpty && messageList.last.isUser) messageList.removeLast();
    } catch (_) {
      _error = 'AI service is temporarily unavailable. Please try again later.';
      _state = AiState.error;
      if (messageList.isNotEmpty && messageList.last.isUser) messageList.removeLast();
    }
    notifyListeners();
  }

  // ── Session memory update ─────────────────────────────────────────────────

  void _updateSessionMemory({
    required String userQuestion,
    required String aiResponse,
    String?         subject,
  }) {
    // Track unique subjects
    if (subject != null && subject.isNotEmpty && !_sessionTopics.contains(subject)) {
      _sessionTopics.add(subject);
    }

    // Extract labelled concepts from the AI's structured response
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

    // Rolling summary of last 5 non-image user questions
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

  /// Clears the general AI chat and all session memory.
  void clearConversation() {
    _messages.clear();
    _sessionTopics.clear();
    _sessionConcepts.clear();
    _sessionSummary = null;
    _error = null;
    _state = AiState.idle;
    notifyListeners();
  }

  /// Clears only the PDF tutoring session history.
  /// Call this when the student opens a different PDF material.
  void clearPdfSession() {
    _pdfMessages.clear();
    notifyListeners();
  }
}
