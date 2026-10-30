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
//
// Persistent chats (this release):
//   The general AI Tutor now works on saved server-side chats. The server is
//   the source of truth; this provider only mirrors the OPEN chat in memory.
//   - Every send carries a client_message_id that is kept (in memory and in
//     SharedPreferences, per user) until the server confirms the outcome, and
//     is re-used unchanged for every retry, so a timeout can never produce a
//     second AI answer or a second usage charge.
//   - A message is only shown as saved once the server confirmed it;
//     otherwise it is shown as "Not sent" with Retry.
//   - PDF tutoring and Exam Lessons are NOT chats: they send a context_type so
//     the server never mixes in history from other chats.
//   - All per-user state (open chat, pending send, session memory) is cleared
//     when the signed-in account changes (bindUser).

import 'dart:convert';
import 'dart:math' show Random;
import 'package:flutter/foundation.dart' show Uint8List, visibleForTesting;
import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../core/storage.dart';
import '../models/ai_model.dart';

import 'ai_provider_io.dart' if (dart.library.html) 'ai_provider_web.dart';

enum AiState { idle, loading, error }

// Rolling window: last 20 turns sent to the AI (10 exchanges).
// Keeps token usage reasonable while covering enough context.
const int _kMaxHistoryTurns = 20;

// Per-user SharedPreferences keys (suffix = user id).
const String _kLastChatKey = 'ai_last_chat_';
const String _kPendingKey  = 'ai_pending_send_';

/// A random (v4) UUID for client_message_id. No extra dependency needed.
@visibleForTesting
String newClientMessageId([Random? rng]) {
  final r = rng ?? Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  String h(int i) => b[i].toRadixString(16).padLeft(2, '0');
  return '${h(0)}${h(1)}${h(2)}${h(3)}-${h(4)}${h(5)}-${h(6)}${h(7)}-'
      '${h(8)}${h(9)}-${h(10)}${h(11)}${h(12)}${h(13)}${h(14)}${h(15)}';
}

/// A send whose outcome the server has not confirmed yet.
/// Kept until the server says "completed" (or the user dismisses it).
class _PendingSend {
  final String   cmid;       // client_message_id — NEVER regenerated on retry
  final int?     chatId;     // null => this send starts a new chat
  final bool     newChat;
  final String   question;
  final String   mode;       // 'normal' | 'exam_prep'
  final String   level;
  final bool     hasImage;   // image bytes are never persisted
  final DateTime createdAt;

  const _PendingSend({
    required this.cmid,
    required this.chatId,
    required this.newChat,
    required this.question,
    required this.mode,
    required this.level,
    required this.hasImage,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'cmid': cmid, 'chat_id': chatId, 'new_chat': newChat,
        'question': question, 'mode': mode, 'level': level,
        'has_image': hasImage, 'created_at': createdAt.toIso8601String(),
      };

  static _PendingSend? fromJson(Map<String, dynamic> j) {
    try {
      return _PendingSend(
        cmid:      j['cmid'] as String,
        chatId:    (j['chat_id'] as num?)?.toInt(),
        newChat:   j['new_chat'] == true,
        question:  j['question'] as String,
        mode:      (j['mode'] as String?) ?? 'normal',
        level:     (j['level'] as String?) ?? 'intermediate',
        hasImage:  j['has_image'] == true,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
    } catch (_) {
      return null;
    }
  }
}

/// The general chat that was open when an Exam Lesson took over the screen.
class _GeneralStash {
  final List<AiMessage> messages;
  final int?    chatId;
  final String? chatTitle;
  final bool    hasEarlier;
  final List<String> topics;
  final List<String> concepts;
  final String? summary;
  const _GeneralStash(this.messages, this.chatId, this.chatTitle,
      this.hasEarlier, this.topics, this.concepts, this.summary);
}

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

  // Guards against duplicate concurrent loads
  bool _loadingPlan  = false;
  bool _loadingUsage = false;

  // ── Persistent chats ──────────────────────────────────────────────────────
  int?    _userId;                 // signed-in account this state belongs to
  int     _userGen = 0;            // bumps when the account changes
  int     _viewGen = 0;            // bumps when the visible chat changes
  int?    _chatId;                 // open saved chat (null = blank / new chat)
  String? _chatTitle;
  bool    _hasEarlierMessages = false;
  bool    _loadingEarlier = false;
  bool    _opening = false;        // loading a saved chat from the server
  bool    _restoredForUser = false;
  bool    _savingDisabled = false; // server answered but did not save (feature off)
  bool    _chatsAvailable = true;

  final List<AiChatSummary> _chats = [];
  bool    _chatsHasMore = false;
  bool    _chatsLoading = false;
  bool    _chatsLoaded  = false;
  String? _chatsError;

  final List<AiEarlierQuestion> _earlier = [];
  bool    _earlierHasMore = false;
  bool    _earlierLoading = false;
  bool    _earlierLoaded  = false;
  String? _earlierError;

  _PendingSend? _pending;
  String?       _pendingImage;      // memory only
  String?       _pendingImageMime;
  _GeneralStash? _stash;

  // ── Phase 3: Session memory (topics / concepts for practice & notes) ─────
  final List<String> _sessionTopics   = [];
  final List<String> _sessionConcepts = [];
  String?            _sessionSummary;

  // ── Exam Prep -> AI Tutor "Exam Lesson" mode ──────────────────────────────
  // Populated by prepareExamLesson() when a Daily Topic card is tapped in
  // Exam Prep, BEFORE AiTutorScreen is pushed. The screen then calls
  // beginExamLessonIfNeeded() on its first frame to auto-start teaching —
  // the student never has to type anything.
  String? _examTopic;
  String? _examCourseCode;
  String? _examCourseTitle;
  int?    _examDaysUntil;
  bool    _examIsReview           = false;
  bool    _examLessonStarted      = false;
  bool    _examLessonMarkedComplete = false;
  bool    _completingExamLesson   = false;

  // ── Public getters ────────────────────────────────────────────────────────

  List<AiMessage>  get messages        => List.unmodifiable(_messages);
  List<AiMessage>  get pdfMessages     => List.unmodifiable(_pdfMessages);
  AiState          get state           => _state;
  String?          get error           => _error;
  bool             get loading         => _state == AiState.loading;
  AiMode           get mode            => _mode;
  ExplanationLevel get level           => _level;
  AiPlanInfo?      get plan            => _plan;
  /// Always returns a valid entitlements object — permissive defaults
  /// until the first /ai/plan call resolves, then the real plan values.
  AiPlanInfo       get entitlements    => _plan ?? AiPlanInfo.defaultPermissive();
  int              get questionsToday  => _questionsToday;
  int              get questionsMonth  => _questionsMonth;
  bool             get isExamPrep      => _mode == AiMode.examPrep;

  // ── Persistent chat getters ───────────────────────────────────────────────
  int?    get chatId              => _chatId;
  String? get chatTitle           => _chatTitle;
  bool    get hasEarlierMessages  => _hasEarlierMessages;
  bool    get loadingEarlier      => _loadingEarlier;
  bool    get opening             => _opening;
  bool    get chatsAvailable      => _chatsAvailable;
  /// True when the server answered but is not saving chats right now.
  bool    get savingUnavailable   => _savingDisabled;
  bool    get hasPending          => _pending != null;
  List<AiChatSummary> get chats   => List.unmodifiable(_chats);
  bool    get chatsHasMore        => _chatsHasMore;
  bool    get chatsLoading        => _chatsLoading;
  bool    get chatsLoaded         => _chatsLoaded;
  String? get chatsError          => _chatsError;
  List<AiEarlierQuestion> get earlierQuestions => List.unmodifiable(_earlier);
  bool    get earlierHasMore      => _earlierHasMore;
  bool    get earlierLoading      => _earlierLoading;
  bool    get earlierLoaded       => _earlierLoaded;
  String? get earlierError        => _earlierError;

  List<String>     get sessionTopics   => List.unmodifiable(_sessionTopics);
  List<String>     get sessionConcepts => List.unmodifiable(_sessionConcepts);
  bool             get hasSessionContext => _sessionTopics.isNotEmpty;

  // ── Exam Lesson getters ───────────────────────────────────────────────────
  bool    get isExamLesson       => _mode == AiMode.examLesson;
  String? get examTopic          => _examTopic;
  String? get examCourseTitle    => _examCourseTitle;
  bool    get examIsReview       => _examIsReview;
  bool    get examLessonMarkedComplete => _examLessonMarkedComplete;
  bool    get completingExamLesson     => _completingExamLesson;
  /// True once the lesson has produced its first response and is ready to
  /// show the "Mark this topic as completed?" action bar.
  bool    get examLessonAwaitingAction =>
      isExamLesson && _examLessonStarted && !_examLessonMarkedComplete &&
      !loading && _messages.isNotEmpty && !_messages.last.isUser;

  // ── Mode & Level ──────────────────────────────────────────────────────────

  void setMode(AiMode m) { _mode = m; notifyListeners(); }

  void toggleExamPrep() {
    _mode = _mode == AiMode.examPrep ? AiMode.normal : AiMode.examPrep;
    notifyListeners();
  }

  // ── Exam Lesson lifecycle ─────────────────────────────────────────────────

  /// Called by Exam Prep BEFORE pushing AiTutorScreen. Sets up the context
  /// for a self-starting Exam Lesson — does NOT make the network call yet
  /// (the screen isn't mounted). [isReview] is true when the student tapped
  /// a topic that's already marked complete.
  void prepareExamLesson({
    required String topic,
    required String courseCode,
    required String courseTitle,
    int? daysUntilExam,
    bool isReview = false,
  }) {
    _mode                       = AiMode.examLesson;
    _examTopic                  = topic;
    _examCourseCode             = courseCode;
    _examCourseTitle            = courseTitle;
    _examDaysUntil              = daysUntilExam;
    _examIsReview               = isReview;
    _examLessonStarted          = false;
    _examLessonMarkedComplete   = false;
    // The lesson is NOT a chat. Park the general chat that is open (if any) so
    // the lesson starts empty and the chat comes back untouched afterwards.
    _stashGeneralChat();
    _messages.clear();
    notifyListeners();
  }

  /// Called from AiTutorScreen's first frame. Auto-teaches the topic with
  /// no user input required. No-op if already started (e.g. hot-restart of
  /// the same screen instance) or if not actually in exam-lesson mode.
  Future<void> beginExamLessonIfNeeded() async {
    if (!isExamLesson || _examLessonStarted || _examTopic == null) return;
    _examLessonStarted = true;
    await _sendRequest(
      question: 'Begin today\'s exam lesson on $_examTopic.',
      announceOnly: true,
    );
  }

  /// Student tapped "Mark Complete" at the end of an Exam Lesson.
  /// Sends an explicit completion callback to Exam Prep's readiness tracker
  /// (never inferred from parsing the chat text).
  Future<bool> markExamTopicComplete() async {
    if (_examCourseCode == null || _examTopic == null) return false;
    _completingExamLesson = true;
    notifyListeners();
    try {
      await ApiClient.completeDailyTopic(
        courseCode:  _examCourseCode!,
        courseTitle: _examCourseTitle ?? _examCourseCode!,
        topic:       _examTopic!,
      );
      _examLessonMarkedComplete = true;
      return true;
    } catch (_) {
      _error = 'Could not save your progress. Please check your connection and try again.';
      _state = AiState.error;
      return false;
    } finally {
      _completingExamLesson = false;
      notifyListeners();
    }
  }

  /// Student tapped "Review Again" — dismiss the completion prompt for this
  /// session without marking it complete, so they can keep reading.
  void dismissExamLessonPrompt() {
    _examLessonStarted = false;
    notifyListeners();
  }

  /// Called when leaving AiTutorScreen after an Exam Lesson. Resets to
  /// normal AI Tutor mode and clears the lesson-specific chat + context so
  /// the general AI Tutor comes back clean next time it's opened.
  void endExamLesson() {
    _mode = AiMode.normal;
    _examTopic = null;
    _examCourseCode = null;
    _examCourseTitle = null;
    _examDaysUntil = null;
    _examIsReview = false;
    _examLessonStarted = false;
    _examLessonMarkedComplete = false;
    _messages.clear();
    _restoreGeneralChat();
    notifyListeners();
  }

  Future<void> setLevel(ExplanationLevel l) async {
    _level = l;
    notifyListeners();
    try { await ApiClient.updateAiPreferences(l.name); } catch (_) {}
  }

  // ── Load plan & preferences ───────────────────────────────────────────────

  Future<void> loadPlan() async {
    if (_loadingPlan) return;
    _loadingPlan = true;
    try {
      final data = await ApiClient.getAiPlan();
      _plan = AiPlanInfo.fromJson(data);
    } catch (e) {
      debugPrint('[AiProvider] loadPlan failed: $e');
      _plan = null;
    } finally {
      _loadingPlan = false;
      notifyListeners();
    }
  }

  /// Clears the cached plan immediately on logout so the next user
  /// starts with defaultPermissive() until their own /ai/plan resolves.
  void clearPlan() {
    _plan = null;
    notifyListeners();
  }

  Future<void> loadUsage() async {
    if (_loadingUsage) return;
    _loadingUsage = true;
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
    } catch (_) {
    } finally {
      _loadingUsage = false;
    }
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
    if (isExamLesson) {
      // Exam Lesson follow-ups are not saved chats.
      await _sendRequest(question: question);
    } else {
      await _sendInChat(question: question);
    }
  }

  // ── Ask with image — MOBILE path ─────────────────────────────────────────

  Future<void> askWithImage(dynamic imageFile, {String extraText = ''}) async {
    final bytes = await readImageBytes(imageFile);
    final b64   = base64Encode(bytes);
    final path  = getImagePath(imageFile);
    final mime  = path.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';
    if (isExamLesson) {
      await _sendRequest(
        question: extraText, imageBase64: b64, imageMimeType: mime, isImage: true,
      );
    } else {
      await _sendInChat(
        question: extraText, imageBase64: b64, imageMimeType: mime, isImage: true,
      );
    }
  }

  // ── Ask with image — WEB path ─────────────────────────────────────────────

  Future<void> askWithImageBytes(
    Uint8List bytes, {
    String extraText = '',
    String mimeType  = 'image/jpeg',
  }) async {
    final b64 = base64Encode(bytes);
    if (isExamLesson) {
      await _sendRequest(
        question: extraText, imageBase64: b64, imageMimeType: mimeType, isImage: true,
      );
    } else {
      await _sendInChat(
        question: extraText, imageBase64: b64, imageMimeType: mimeType, isImage: true,
      );
    }
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
        // PDF sessions never inherit history from saved chats.
        contextType:          'pdf',
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
    // True for the auto-triggered opening message of an Exam Lesson — the
    // question is synthesized internally, so no user bubble is shown for it.
    bool    announceOnly     = false,
  }) async {
    final trimmed = question.trim();
    if (trimmed.isEmpty && imageBase64 == null) return;

    // Add user message to the correct message list (skipped for the
    // system-triggered Exam Lesson opener — the student typed nothing).
    final messageList = isPdfRequest ? _pdfMessages : _messages;
    if (!announceOnly) {
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
    }

    _state = AiState.loading;
    _error = null;
    notifyListeners();

    // ── Phase 4: Build history from all messages BEFORE this new question ──
    // We exclude the user message we just added (it's the question being sent).
    // The history is everything before it — completed exchanges only.
    // (announceOnly never adds a user message, so there's nothing to exclude.)
    final historySource = announceOnly
        ? messageList
        : messageList.sublist(0, messageList.length - 1);
    final history = _buildConversationHistory(historySource);

    try {
      final data = await ApiClient.askAi(
        question:            trimmed,
        mode:                switch (_mode) {
          AiMode.examPrep   => 'exam_prep',
          AiMode.examLesson => 'exam_lesson',
          AiMode.normal     => 'normal',
        },
        level:               _level.name,
        imageBase64:         imageBase64,
        imageMimeType:       imageMimeType,
        pdfMaterialId:       pdfMaterialId,
        pdfMaterialTitle:    pdfMaterialTitle,
        pdfCourseCode:       pdfCourseCode,
        pdfLevelName:        pdfLevelName,
        pdfCategoryName:     pdfCategoryName,
        conversationHistory: history,
        examTopic:           isExamLesson ? _examTopic        : null,
        examCourseCode:      isExamLesson ? _examCourseCode    : null,
        examCourseTitle:     isExamLesson ? _examCourseTitle   : null,
        examDaysUntil:       isExamLesson ? _examDaysUntil     : null,
        examIsReview:        isExamLesson ? _examIsReview      : false,
        // Not a saved chat: the server must never mix in other chats' history.
        contextType:         isPdfRequest ? 'pdf' : (isExamLesson ? 'exam_lesson' : null),
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

  // ═══════════════════════════════════════════════════════════════════════════
  // Persistent chats
  // ═══════════════════════════════════════════════════════════════════════════

  // ── Account binding ───────────────────────────────────────────────────────

  /// Tell the provider which account is signed in. When the account CHANGES
  /// (logout, or another user logs in), everything that belongs to the
  /// previous user — open chat, messages, pending send, session memory, lists —
  /// is wiped from memory. Safe to call repeatedly with the same id.
  void bindUser(int? userId) {
    if (_userId == userId) return;
    final hadUser = _userId != null;
    _userId = userId;
    _userGen++;
    _viewGen++;
    // First binding (null -> id) adopts whatever is in memory (e.g. a lesson
    // prepared just before the screen opened); any other change is a different
    // account and must start clean.
    if (hadUser || userId == null) _resetAllUserState();
    _restoredForUser = false;
    notifyListeners();
  }

  void _resetAllUserState() {
    _messages.clear();
    _pdfMessages.clear();
    _sessionTopics.clear();
    _sessionConcepts.clear();
    _sessionSummary = null;
    _chatId = null;
    _chatTitle = null;
    _hasEarlierMessages = false;
    _loadingEarlier = false;
    _opening = false;
    _savingDisabled = false;
    _chatsAvailable = true;
    _chats.clear();
    _chatsHasMore = false;
    _chatsLoading = false;
    _chatsLoaded = false;
    _chatsError = null;
    _earlier.clear();
    _earlierHasMore = false;
    _earlierLoading = false;
    _earlierLoaded = false;
    _earlierError = null;
    _pending = null;          // in memory only; the persisted copy stays with ITS user
    _pendingImage = null;
    _pendingImageMime = null;
    _stash = null;
    _questionsToday = 0;
    _questionsMonth = 0;
    _mode = AiMode.normal;
    _examTopic = null;
    _examCourseCode = null;
    _examCourseTitle = null;
    _examDaysUntil = null;
    _examIsReview = false;
    _examLessonStarted = false;
    _examLessonMarkedComplete = false;
    _error = null;
    _state = AiState.idle;
  }

  // ── Per-user persisted pointers (SharedPreferences) ───────────────────────

  String? get _lastChatPrefKey => _userId == null ? null : '$_kLastChatKey$_userId';
  String? get _pendingPrefKey  => _userId == null ? null : '$_kPendingKey$_userId';

  int? _readLastChat() {
    final k = _lastChatPrefKey;
    if (k == null) return null;
    return int.tryParse(AppStorage.getString(k) ?? '');
  }

  Future<void> _saveLastChat(int? id) async {
    final k = _lastChatPrefKey;
    if (k == null) return;
    if (id == null) {
      await AppStorage.removeKey(k);
    } else {
      await AppStorage.setString(k, '$id');
    }
  }

  _PendingSend? _readPending() {
    final k = _pendingPrefKey;
    if (k == null) return null;
    final raw = AppStorage.getString(k);
    if (raw == null || raw.isEmpty) return null;
    try {
      return _PendingSend.fromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map));
    } catch (_) {
      return null;
    }
  }

  /// Writes (or removes) the persisted copy of the CURRENT pending send for
  /// the CURRENT user. Callers must have checked the account did not change.
  Future<void> _persistPending() async {
    final k = _pendingPrefKey;
    if (k == null) return;
    final p = _pending;
    if (p == null) {
      await AppStorage.removeKey(k);
    } else {
      await AppStorage.setString(k, jsonEncode(p.toJson()));
    }
  }

  // ── Opening / restoring a chat ────────────────────────────────────────────

  /// Called when the AI Tutor screen opens. For the same user it reopens the
  /// last active chat — after first resolving any send whose outcome the
  /// server never confirmed (app killed / timeout). No-op for Exam Lessons
  /// and when something is already open.
  Future<void> restoreSession() async {
    if (_restoredForUser || isExamLesson || _userId == null) return;
    _restoredForUser = true;
    if (_messages.isNotEmpty || _chatId != null || loading || _opening) return;

    final userGen = _userGen;
    _opening = true;
    notifyListeners();
    try {
      final stored = _readPending();
      if (stored != null) {
        await _restorePending(stored, userGen);
      } else {
        final last = _readLastChat();
        if (last != null) {
          await _loadChatInto(last, userGen: userGen, silent: true);
        }
      }
    } finally {
      if (userGen == _userGen) {
        _opening = false;
        notifyListeners();
      }
    }
  }

  /// Student picked a chat in the history list.
  Future<bool> openChat(int chatId) async {
    if (isExamLesson || loading || _opening) return false;
    final userGen = _userGen;
    _viewGen++;
    _pending = null;                 // leaving the current view abandons an unsent bubble
    _pendingImage = null;
    _pendingImageMime = null;
    await _persistPending();
    _opening = true;
    _error = null;
    notifyListeners();
    try {
      return await _loadChatInto(chatId, userGen: userGen, silent: false);
    } finally {
      if (userGen == _userGen) {
        _opening = false;
        notifyListeners();
      }
    }
  }

  /// Loads a chat from the server and shows it. Verifies ownership implicitly:
  /// the server answers 404 for chats that are missing or not this user's.
  Future<bool> _loadChatInto(int chatId, {required int userGen, required bool silent}) async {
    try {
      final data = await ApiClient.getAiChat(chatId);
      if (userGen != _userGen) return false;
      final d = AiChatDetail.fromJson(data);
      _messages
        ..clear()
        ..addAll(d.messages.expand((e) => e.toMessages()));
      _chatId = d.id;
      _chatTitle = d.title;
      _hasEarlierMessages = d.hasMoreBefore;
      _savingDisabled = false;
      _chatsAvailable = true;
      _rebuildSessionMemory();
      await _saveLastChat(d.id);
      return true;
    } on ApiException catch (e) {
      if (userGen != _userGen) return false;
      if (e.statusCode == 404) {
        // Deleted, or not this user's: forget the pointer, start blank.
        if (_readLastChat() == chatId) await _saveLastChat(null);
        if (!silent) _error = 'That chat no longer exists.';
      } else if (e.statusCode == 503) {
        _chatsAvailable = false;
        if (!silent) _error = 'Chat history is temporarily unavailable.';
      } else if (!silent) {
        _error = e.message;
      }
      return false;
    } catch (_) {
      if (userGen == _userGen && !silent) {
        _error = 'Could not open that chat. Please try again.';
      }
      return false;
    }
  }

  /// Shows older exchanges of the open chat (API pages the newest first).
  Future<void> loadEarlierMessages() async {
    final id = _chatId;
    if (id == null || !_hasEarlierMessages || _loadingEarlier) return;
    final firstId = _messages
        .where((m) => m.exchangeId != null)
        .map((m) => m.exchangeId!)
        .fold<int?>(null, (a, b) => a == null || b < a ? b : a);
    if (firstId == null) return;
    final userGen = _userGen, viewGen = _viewGen;
    _loadingEarlier = true;
    notifyListeners();
    try {
      final d = AiChatDetail.fromJson(await ApiClient.getAiChat(id, beforeId: firstId));
      if (userGen != _userGen || viewGen != _viewGen) return;
      _messages.insertAll(0, d.messages.expand((e) => e.toMessages()));
      _hasEarlierMessages = d.hasMoreBefore;
      _rebuildSessionMemory();
    } on ApiException catch (e) {
      if (userGen == _userGen && viewGen == _viewGen) _error = e.message;
    } finally {
      if (userGen == _userGen) {
        _loadingEarlier = false;
        notifyListeners();
      }
    }
  }

  void _rebuildSessionMemory() {
    _sessionTopics.clear();
    _sessionConcepts.clear();
    _sessionSummary = null;
    for (final m in _messages) {
      if (!m.isUser) {
        _updateSessionMemory(userQuestion: '', aiResponse: m.text, subject: m.subject);
      }
    }
  }

  // ── New chat ──────────────────────────────────────────────────────────────

  /// Starts a blank, independent chat. Existing chats are never touched.
  void newChat() {
    if (isExamLesson || loading || _opening) return;
    _viewGen++;
    _startBlankChat();
    _saveLastChat(null);
    _persistPendingAfterDrop();
    notifyListeners();
  }

  void _startBlankChat() {
    _messages.clear();
    _sessionTopics.clear();
    _sessionConcepts.clear();
    _sessionSummary = null;
    _chatId = null;
    _chatTitle = null;
    _hasEarlierMessages = false;
    _savingDisabled = false;
    _pending = null;
    _pendingImage = null;
    _pendingImageMime = null;
    _error = null;
    _state = AiState.idle;
  }

  void _persistPendingAfterDrop() {
    // fire-and-forget: remove the persisted copy of an abandoned unsent bubble
    _persistPending();
  }

  // ── Exam Lesson hand-off (the lesson is not a chat) ───────────────────────

  void _stashGeneralChat() {
    if (_stash != null) return;
    _stash = _GeneralStash(
      List<AiMessage>.of(_messages),
      _chatId, _chatTitle, _hasEarlierMessages,
      List<String>.of(_sessionTopics), List<String>.of(_sessionConcepts),
      _sessionSummary,
    );
    _chatId = null;
    _chatTitle = null;
    _hasEarlierMessages = false;
    _sessionTopics.clear();
    _sessionConcepts.clear();
    _sessionSummary = null;
  }

  void _restoreGeneralChat() {
    final st = _stash;
    _stash = null;
    _sessionTopics.clear();
    _sessionConcepts.clear();
    _sessionSummary = null;
    if (st == null) {
      _chatId = null;
      _chatTitle = null;
      _hasEarlierMessages = false;
      return;
    }
    _messages.addAll(st.messages);
    _chatId = st.chatId;
    _chatTitle = st.chatTitle;
    _hasEarlierMessages = st.hasEarlier;
    _sessionTopics.addAll(st.topics);
    _sessionConcepts.addAll(st.concepts);
    _sessionSummary = st.summary;
  }

  // ── Sending in a saved chat ───────────────────────────────────────────────

  Future<void> _sendInChat({
    required String question,
    String? imageBase64,
    String? imageMimeType,
    bool    isImage = false,
  }) async {
    final trimmed = question.trim();
    if (trimmed.isEmpty && imageBase64 == null) return;
    if (loading || _opening) return;          // hard guard against double submits
    if (_pending != null) {
      // An earlier message is still unsent. Sending another would orphan it.
      _error = 'Please tap Retry or Dismiss on your unsent message first.';
      _state = AiState.error;
      notifyListeners();
      return;
    }

    final p = _PendingSend(
      cmid:      newClientMessageId(),
      chatId:    _chatId,
      newChat:   _chatId == null,
      question:  trimmed,
      mode:      aiModeToName(_mode),
      level:     _level.name,
      hasImage:  imageBase64 != null,
      createdAt: DateTime.now(),
    );
    _pending = p;
    _pendingImage = imageBase64;
    _pendingImageMime = imageMimeType;
    // Persist BEFORE the request leaves the device: if the app is killed
    // mid-flight, the next launch can ask the server what happened.
    await _persistPending();

    _messages.add(AiMessage(
      text: isImage
          ? (trimmed.isEmpty ? '📷 Image question' : '📷 $trimmed')
          : trimmed,
      isUser: true,
      timestamp: DateTime.now(),
      isImage: isImage,
      mode: _mode,
      clientMessageId: p.cmid,
    ));
    await _attemptPending();
  }

  /// (Re)sends the pending message with its ORIGINAL client_message_id.
  Future<void> _attemptPending() async {
    final p = _pending;
    if (p == null) return;
    final userGen = _userGen, viewGen = _viewGen;
    _state = AiState.loading;
    _error = null;
    _setBubble(p.cmid, (m) => m.copyWith(failed: false));
    notifyListeners();

    // When the server is not saving chats, it also cannot rebuild context for
    // us, so send the in-memory history like before.
    final history = _savingDisabled
        ? _buildConversationHistory(
            _messages.where((m) => m.clientMessageId != p.cmid).toList())
        : null;

    try {
      final data = await ApiClient.askAi(
        question:            p.question,
        mode:                p.mode,
        level:               p.level,
        imageBase64:         _pendingImage,
        imageMimeType:       _pendingImageMime,
        conversationHistory: history,
        chatId:              p.chatId,
        newChat:             p.newChat,
        clientMessageId:     p.cmid,
        timeout:             const Duration(seconds: 100),
      );
      await _onChatAnswer(data, p, viewGen, userGen);
    } on ApiException catch (e) {
      await _onChatSendError(e, p, viewGen, userGen);
    } catch (_) {
      await _onChatSendError(
        ApiException('AI service is temporarily unavailable. Please try again later.'),
        p, viewGen, userGen,
      );
    }
  }

  Future<void> _onChatAnswer(
    Map<String, dynamic> data, _PendingSend p, int viewGen, int userGen,
  ) async {
    // Account changed while waiting: the server saved it for the right user;
    // there is nothing of this answer to show to the new one.
    if (userGen != _userGen) return;

    final replayed  = data['replayed'] == true;
    final newChatId = (data['chat_id'] as num?)?.toInt();
    final exchange  = (data['conversation_id'] as num?)?.toInt();

    // Confirmed by the server -> the pending record has done its job.
    if (_pending?.cmid == p.cmid) {
      _pending = null;
      _pendingImage = null;
      _pendingImageMime = null;
      await _persistPending();
    }
    if (userGen != _userGen) return;

    if (viewGen != _viewGen) {
      // The student moved to another chat while this one was answering. The
      // exchange is saved; just refresh the list next time it is opened.
      _state = AiState.idle;
      _chatsLoaded = false;
      notifyListeners();
      return;
    }

    _setBubble(p.cmid, (m) => m.copyWith(
          failed: false, exchangeId: exchange, clearClientMessageId: true));
    final aiMessage = AiMessage(
      text:       data['response'] as String,
      isUser:     false,
      timestamp:  DateTime.now(),
      subject:    data['subject'] as String?,
      mode:       aiModeFromName(p.mode),
      exchangeId: exchange,
    );
    _messages.add(aiMessage);

    if (newChatId != null) {
      _chatId = newChatId;
      _chatTitle = (data['chat_title'] as String?) ?? _chatTitle;
      _savingDisabled = false;
      _chatsAvailable = true;
      _chatsLoaded = false;
      await _saveLastChat(newChatId);
    } else {
      // Answer produced but NOT saved as a chat (feature off server-side).
      _savingDisabled = true;
    }

    if (replayed) {
      loadUsage();               // recovered answer: refresh counters from the server
    } else {
      _questionsToday++;
      _questionsMonth++;
    }
    _state = AiState.idle;
    _updateSessionMemory(
      userQuestion: p.question,
      aiResponse:   aiMessage.text,
      subject:      aiMessage.subject,
    );
    notifyListeners();
  }

  Future<void> _onChatSendError(
    ApiException e, _PendingSend p, int viewGen, int userGen,
  ) async {
    if (userGen != _userGen) return;
    final status = e.statusCode;

    if (status == 409) {
      // The server is still answering this very message (e.g. our earlier
      // attempt timed out). Wait for it; never start a second one.
      await _awaitOutcome(p, viewGen, userGen,
          attempts: 15, delay: const Duration(seconds: 3));
      return;
    }
    if (status == null) {
      // Network failure / timeout: the request MAY have reached the server.
      // Ask what happened instead of guessing or re-asking the AI.
      await _awaitOutcome(p, viewGen, userGen,
          attempts: 4, delay: const Duration(seconds: 2));
      return;
    }
    if (status == 404 && p.chatId != null) {
      // The chat was deleted (e.g. on another device). Nothing was sent.
      _pending = null;
      _pendingImage = null;
      _pendingImageMime = null;
      await _persistPending();
      if (userGen != _userGen) return;
      if (viewGen == _viewGen) {
        _startBlankChat();
        await _saveLastChat(null);
        _error = 'This chat no longer exists, so your message was not sent.';
        _state = AiState.error;
        notifyListeners();
      } else if (_state == AiState.loading) {
        _state = AiState.idle;
        notifyListeners();
      }
      return;
    }
    // Any other server answer (limit reached, AI down, validation…): the
    // message was NOT saved. Keep it pending so Retry re-uses the same id.
    _failPending(p, e.message);
  }

  /// Polls the server for the outcome of [p] (never re-asks the AI).
  Future<void> _awaitOutcome(
    _PendingSend p, int viewGen, int userGen, {
    required int attempts,
    required Duration delay,
  }) async {
    for (var i = 0; i < attempts; i++) {
      if (i > 0) await Future.delayed(delay);
      if (userGen != _userGen) return;
      try {
        final st = await ApiClient.getAiRequestStatus(p.cmid);
        if (userGen != _userGen) return;
        if (st == null) {
          _failPending(p, 'Message not sent. Check your connection and tap Retry.');
          return;
        }
        final status = st['status'];
        if (status == 'completed' && st['exchange'] is Map) {
          final ex = Map<String, dynamic>.from(st['exchange'] as Map)
            ..['replayed'] = true;
          await _onChatAnswer(ex, p, viewGen, userGen);
          return;
        }
        if (status == 'failed') {
          _failPending(p, 'The AI could not answer. Tap Retry — your message will not be duplicated.');
          return;
        }
        // in_progress: keep waiting
      } on ApiException {
        // still unreachable: keep trying until attempts run out
      }
    }
    _failPending(p,
        'Could not confirm whether your message was sent. Tap Retry — it will not be duplicated.');
  }

  void _failPending(_PendingSend p, String message) {
    if (_pending?.cmid != p.cmid) {
      // The unsent message was discarded meanwhile (e.g. its chat was deleted).
      if (_state == AiState.loading) {
        _state = AiState.idle;
        notifyListeners();
      }
      return;
    }
    _error = message;
    _state = AiState.error;
    _setBubble(p.cmid, (m) => m.copyWith(failed: true));
    notifyListeners();
  }

  void _setBubble(String cmid, AiMessage Function(AiMessage) change) {
    for (var i = _messages.length - 1; i >= 0; i--) {
      final m = _messages[i];
      if (m.isUser && m.clientMessageId == cmid) {
        _messages[i] = change(m);
        return;
      }
    }
  }

  /// Retry button on a "Not sent" bubble. Re-uses the ORIGINAL id, so if the
  /// first attempt actually completed, the saved answer comes back and
  /// nothing is asked or charged twice.
  Future<void> retryPending() async {
    final p = _pending;
    if (p == null || loading || _opening) return;
    if (p.hasImage && _pendingImage == null) {
      // Image bytes are never persisted, so after a restart we can only
      // find out what happened — not resend.
      final userGen = _userGen, viewGen = _viewGen;
      _state = AiState.loading;
      _error = null;
      notifyListeners();
      try {
        final st = await ApiClient.getAiRequestStatus(p.cmid);
        if (userGen != _userGen) return;
        if (st != null && st['status'] == 'completed' && st['exchange'] is Map) {
          final ex = Map<String, dynamic>.from(st['exchange'] as Map)..['replayed'] = true;
          await _onChatAnswer(ex, p, viewGen, userGen);
          return;
        }
      } on ApiException {
        _failPending(p, 'Could not reach the server. Please try again.');
        return;
      }
      await dismissPending();
      _error = 'Your image message was not sent. Please attach the image again.';
      _state = AiState.error;
      notifyListeners();
      return;
    }
    await _attemptPending();
  }

  /// Dismiss button on a "Not sent" bubble: discards the unsent message.
  Future<void> dismissPending() async {
    final p = _pending;
    if (p == null) return;
    final userGen = _userGen;
    _messages.removeWhere((m) => m.isUser && m.clientMessageId == p.cmid);
    _pending = null;
    _pendingImage = null;
    _pendingImageMime = null;
    _error = null;
    _state = AiState.idle;
    if (userGen == _userGen) await _persistPending();
    notifyListeners();
  }

  /// A send found in storage after a restart: ask the server what happened.
  Future<void> _restorePending(_PendingSend p, int userGen) async {
    Map<String, dynamic>? st;
    var unreachable = false;
    try {
      st = await ApiClient.getAiRequestStatus(p.cmid);
    } on ApiException {
      unreachable = true;
    }
    if (userGen != _userGen) return;
    final status = st?['status'] as String?;

    if (status == 'completed') {
      // It DID get saved. Show the chat it belongs to; nothing to resend.
      final ex = st?['exchange'];
      final cid = ((ex is Map ? ex['chat_id'] : null) ?? st?['chat_id']) as num?;
      _pending = null;
      await _persistPending();
      if (cid != null) {
        await _loadChatInto(cid.toInt(), userGen: userGen, silent: true);
      }
      loadUsage();
      return;
    }

    // Not saved (yet). Show the chat it was meant for, then the unsent bubble.
    if (p.chatId != null) {
      final ok = await _loadChatInto(p.chatId!, userGen: userGen, silent: true);
      if (userGen != _userGen) return;
      if (!ok && _chatId == null) {
        // That chat is gone; the message cannot be delivered anywhere.
        _pending = null;
        await _persistPending();
        return;
      }
    }
    _pending = p;
    _messages.add(AiMessage(
      text: p.hasImage
          ? (p.question.isEmpty ? '📷 Image question' : '📷 ${p.question}')
          : p.question,
      isUser: true,
      timestamp: p.createdAt,
      isImage: p.hasImage,
      mode: aiModeFromName(p.mode),
      clientMessageId: p.cmid,
      failed: status != 'in_progress',
    ));
    if (status == 'in_progress') {
      _state = AiState.loading;
      notifyListeners();
      await _awaitOutcome(p, _viewGen, userGen,
          attempts: 15, delay: const Duration(seconds: 3));
    } else {
      _error = unreachable
          ? 'Could not confirm whether your last message was sent. Tap Retry — it will not be duplicated.'
          : 'Your last message was not sent. Tap Retry to send it.';
      _state = AiState.error;
    }
  }

  // ── History list, rename, delete ──────────────────────────────────────────

  Future<void> loadChats() async {
    if (_chatsLoading || _userId == null) return;
    final userGen = _userGen;
    _chatsLoading = true;
    _chatsError = null;
    notifyListeners();
    try {
      final page = AiChatPage.fromJson(await ApiClient.getAiChats(skip: 0, limit: 20));
      if (userGen != _userGen) return;
      _chats
        ..clear()
        ..addAll(page.items);
      _chatsHasMore = page.hasMore;
      _chatsLoaded = true;
      _chatsAvailable = true;
    } on ApiException catch (e) {
      if (userGen != _userGen) return;
      if (e.statusCode == 404 || e.statusCode == 503) {
        _chatsAvailable = false;
        _chatsError = 'Chat history is unavailable right now.';
      } else {
        _chatsError = e.message;
      }
    } finally {
      if (userGen == _userGen) {
        _chatsLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadMoreChats() async {
    if (_chatsLoading || !_chatsHasMore || _userId == null) return;
    final userGen = _userGen;
    _chatsLoading = true;
    notifyListeners();
    try {
      final page = AiChatPage.fromJson(
          await ApiClient.getAiChats(skip: _chats.length, limit: 20));
      if (userGen != _userGen) return;
      final known = _chats.map((c) => c.id).toSet();
      _chats.addAll(page.items.where((c) => !known.contains(c.id)));
      _chatsHasMore = page.hasMore;
    } on ApiException catch (e) {
      if (userGen == _userGen) _chatsError = e.message;
    } finally {
      if (userGen == _userGen) {
        _chatsLoading = false;
        notifyListeners();
      }
    }
  }

  /// Returns null on success, or an error message.
  Future<String?> renameChat(int chatId, String title) async {
    final clean = title.trim();
    if (clean.isEmpty) return 'Title cannot be empty.';
    final userGen = _userGen;
    try {
      await ApiClient.renameAiChat(chatId, clean);
      if (userGen != _userGen) return null;
      final i = _chats.indexWhere((c) => c.id == chatId);
      if (i >= 0) _chats[i] = _chats[i].copyWith(title: clean);
      if (_chatId == chatId) _chatTitle = clean;
      notifyListeners();
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  /// Permanently deletes a chat and its messages. Returns null on success.
  Future<String?> deleteChat(int chatId) async {
    final userGen = _userGen;
    try {
      await ApiClient.deleteAiChat(chatId);
    } on ApiException catch (e) {
      if (e.statusCode != 404) return e.message;   // 404 = already gone
    }
    if (userGen != _userGen) return null;
    _chats.removeWhere((c) => c.id == chatId);
    if (_readLastChat() == chatId) await _saveLastChat(null);
    if (_pending?.chatId == chatId) {
      _pending = null;
      _pendingImage = null;
      _pendingImageMime = null;
      await _persistPending();
    }
    if (_chatId == chatId) {
      _viewGen++;
      _startBlankChat();
    }
    notifyListeners();
    return null;
  }

  // ── Earlier Questions (read-only, pre-chat history) ───────────────────────

  Future<void> loadEarlierQuestions({bool more = false}) async {
    if (_earlierLoading || _userId == null) return;
    if (more && !_earlierHasMore) return;
    final userGen = _userGen;
    _earlierLoading = true;
    _earlierError = null;
    notifyListeners();
    try {
      final page = AiEarlierPage.fromJson(await ApiClient.getAiEarlierQuestions(
          skip: more ? _earlier.length : 0, limit: 20));
      if (userGen != _userGen) return;
      if (!more) _earlier.clear();
      final known = _earlier.map((q) => q.id).toSet();
      _earlier.addAll(page.items.where((q) => !known.contains(q.id)));
      _earlierHasMore = page.hasMore;
      _earlierLoaded = true;
    } on ApiException catch (e) {
      if (userGen == _userGen) _earlierError = e.message;
    } finally {
      if (userGen == _userGen) {
        _earlierLoading = false;
        notifyListeners();
      }
    }
  }

  // ── Utility ───────────────────────────────────────────────────────────────

  void clearError() {
    _error = null;
    _state = AiState.idle;
    notifyListeners();
  }

  /// Starts a blank chat (kept for compatibility; saved chats are NOT deleted).
  void clearConversation() => newChat();

  /// Clears only the PDF tutoring session history.
  /// Call this when the student opens a different PDF material.
  void clearPdfSession() {
    _pdfMessages.clear();
    notifyListeners();
  }
}
