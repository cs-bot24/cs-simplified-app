import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';
import '../core/api_client.dart';
import '../models/achievement_model.dart';

class AchievementProvider extends ChangeNotifier {
  List<AchievementModel> _achievements = [];
  bool    _loading = false;
  String? _error;

  List<AchievementModel> get achievements => _achievements;
  bool    get loading    => _loading;
  String? get error      => _error;

  List<AchievementModel> get unlocked =>
      _achievements.where((a) => a.isUnlocked).toList();

  List<AchievementModel> get locked =>
      _achievements.where((a) => !a.isUnlocked).toList();

  int get unlockedCount => unlocked.length;
  int get totalCount    => _achievements.length;

  Future<void> fetchAchievements() async {
    if (_loading) return;
    _loading = true;
    _error   = null;
    notifyListeners();

    try {
      final data = await ApiClient.getAchievements();
      _achievements = (data as List)
          .map((j) => AchievementModel.fromJson(j as Map<String, dynamic>))
          .toList();
      dev.log('[Achievements] loaded ${_achievements.length} '
          '(${unlockedCount} unlocked)', name: 'AchievementProvider');
    } on ApiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = 'Could not load achievements.';
      dev.log('[Achievements] error: $e', name: 'AchievementProvider');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Called from PDF viewer after study-ping returns new_achievements list.
  /// Refreshes the full list so newly unlocked items render immediately.
  Future<void> refreshAfterUnlock() => fetchAchievements();
}
