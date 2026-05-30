import 'package:flutter/material.dart';
import '../core/api_client.dart';

/// Manages material request form submission state.
/// Kept simple — students don't see their own request history
/// in this phase, so we only track submission status.
class RequestProvider extends ChangeNotifier {
  bool _submitting = false;
  String? _error;

  bool    get submitting => _submitting;
  String? get error      => _error;

  Future<bool> submit({
    required String courseName,
    required String topic,
    String? message,
  }) async {
    _submitting = true;
    _error = null;
    notifyListeners();

    try {
      await ApiClient.submitMaterialRequest(
        courseName: courseName,
        topic: topic,
        message: message,
      );
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      return false;
    } catch (_) {
      _error = 'Could not send request. Please try again.';
      return false;
    } finally {
      _submitting = false;
      notifyListeners();
    }
  }
}
