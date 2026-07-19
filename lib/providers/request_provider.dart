import 'package:flutter/foundation.dart';
import '../core/api_client.dart';

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
      debugPrint('[RequestProvider] calling POST /material-requests');
      await ApiClient.createMaterialRequest(
        title: '$courseName: $topic',
        message: message ?? '',
      );
      debugPrint('[RequestProvider] success');
      return true;
    } on ApiException catch (e) {
      // Show the full error including status code so we can diagnose
      _error = '${e.message} (status: ${e.statusCode})';
      debugPrint('[RequestProvider] ApiException: ${e.message} status=${e.statusCode}');
      return false;
    } catch (e, stack) {
      _error = 'Error: $e';
      debugPrint('[RequestProvider] unexpected: $e\n$stack');
      return false;
    } finally {
      _submitting = false;
      notifyListeners();
    }
  }
}
