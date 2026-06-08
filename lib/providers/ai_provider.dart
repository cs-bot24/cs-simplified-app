import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../models/ai_model.dart';

enum AiState { idle, loading, error }

class AiProvider extends ChangeNotifier {
  final List<AiMessage> _messages = [];
  AiState _state = AiState.idle;
  String? _error;

  List<AiMessage> get messages => List.unmodifiable(_messages);
  AiState get state   => _state;
  String? get error   => _error;
  bool    get loading => _state == AiState.loading;

  Future<void> ask(String question) async {
    final trimmed = question.trim();
    if (trimmed.isEmpty) return;

    // Add user message immediately for responsive feel
    _messages.add(AiMessage(
      text: trimmed,
      isUser: true,
      timestamp: DateTime.now(),
    ));
    _state = AiState.loading;
    _error = null;
    notifyListeners();

    try {
      final data = await ApiClient.askAi(trimmed);
      _messages.add(AiMessage(
        text: data['response'] as String,
        isUser: false,
        timestamp: DateTime.now(),
      ));
      _state = AiState.idle;
    } on ApiException catch (e) {
      _error = e.message;
      _state = AiState.error;
      // Remove the pending user message so they can retry
      if (_messages.isNotEmpty && _messages.last.isUser) {
        _messages.removeLast();
      }
    } catch (_) {
      _error = 'AI service is currently unavailable. Please try again later.';
      _state = AiState.error;
      if (_messages.isNotEmpty && _messages.last.isUser) {
        _messages.removeLast();
      }
    }

    notifyListeners();
  }

  void clearError() {
    _error = null;
    _state = AiState.idle;
    notifyListeners();
  }

  void clearConversation() {
    _messages.clear();
    _state = AiState.idle;
    _error = null;
    notifyListeners();
  }
}
