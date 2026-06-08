import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../models/ai_model.dart';

enum AiState { idle, loading, error }

class AiProvider extends ChangeNotifier {
  final List<AiMessage> _messages = [];
  AiState       _state            = AiState.idle;
  String?       _error;
  AiMode        _mode             = AiMode.normal;
  ExplanationLevel _level         = ExplanationLevel.intermediate;
  AiPlanInfo?   _plan;
  int           _questionsToday   = 0;
  int           _questionsMonth   = 0;

  List<AiMessage>  get messages         => List.unmodifiable(_messages);
  AiState          get state            => _state;
  String?          get error            => _error;
  bool             get loading          => _state == AiState.loading;
  AiMode           get mode             => _mode;
  ExplanationLevel get level            => _level;
  AiPlanInfo?      get plan             => _plan;
  int              get questionsToday   => _questionsToday;
  int              get questionsMonth   => _questionsMonth;
  bool             get isExamPrep       => _mode == AiMode.examPrep;

  // ── Mode & Level ─────────────────────────────────────────────────────────

  void setMode(AiMode m) {
    _mode = m;
    notifyListeners();
  }

  void toggleExamPrep() {
    _mode = _mode == AiMode.examPrep ? AiMode.normal : AiMode.examPrep;
    notifyListeners();
  }

  Future<void> setLevel(ExplanationLevel l) async {
    _level = l;
    notifyListeners();
    try {
      await ApiClient.updateAiPreferences(l.name);
    } catch (_) {}
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
      _questionsToday = (data['questions_today'] as num?)?.toInt() ?? 0;
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

  // ── Ask (text) ────────────────────────────────────────────────────────────

  Future<void> ask(String question) async {
    await _sendRequest(question: question);
  }

  // ── Ask with image ────────────────────────────────────────────────────────

  Future<void> askWithImage(File imageFile, {String extraText = ''}) async {
    final bytes    = await imageFile.readAsBytes();
    final b64      = base64Encode(bytes);
    final mime     = imageFile.path.toLowerCase().endsWith('.png')
        ? 'image/png'
        : 'image/jpeg';
    await _sendRequest(
      question:      extraText,
      imageBase64:   b64,
      imageMimeType: mime,
      isImage:       true,
    );
  }

  // ── Practice questions ────────────────────────────────────────────────────

  Future<String?> generatePracticeQuestions(String topic) async {
    _state = AiState.loading;
    _error = null;
    notifyListeners();
    try {
      final data = await ApiClient.generatePracticeQuestions(
        topic: topic,
        level: _level.name,
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

  // ── Study notes ───────────────────────────────────────────────────────────

  Future<String?> generateStudyNotes(String topic) async {
    _state = AiState.loading;
    _error = null;
    notifyListeners();
    try {
      final data = await ApiClient.generateStudyNotes(
        topic: topic,
        level: _level.name,
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
    bool isImage = false,
  }) async {
    final trimmed = question.trim();
    if (trimmed.isEmpty && imageBase64 == null) return;

    _messages.add(AiMessage(
      text: isImage
          ? (trimmed.isEmpty ? '📷 Image question' : '📷 $trimmed')
          : trimmed,
      isUser: true,
      timestamp: DateTime.now(),
      isImage: isImage,
      mode: _mode,
    ));
    _state = AiState.loading;
    _error = null;
    notifyListeners();

    try {
      final data = await ApiClient.askAi(
        question:      trimmed,
        mode:          _mode == AiMode.examPrep ? 'exam_prep' : 'normal',
        level:         _level.name,
        imageBase64:   imageBase64,
        imageMimeType: imageMimeType,
      );
      _messages.add(AiMessage(
        text:      data['response'] as String,
        isUser:    false,
        timestamp: DateTime.now(),
        subject:   data['subject'] as String?,
        mode:      _mode,
      ));
      _questionsToday++;
      _questionsMonth++;
      _state = AiState.idle;
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

  // ── Utility ───────────────────────────────────────────────────────────────

  void clearError()        { _error = null; _state = AiState.idle; notifyListeners(); }
  void clearConversation() { _messages.clear(); _error = null; _state = AiState.idle; notifyListeners(); }
}
