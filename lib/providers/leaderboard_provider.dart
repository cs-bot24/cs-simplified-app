import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';
import '../core/api_client.dart';
import '../models/leaderboard_model.dart';

class LeaderboardProvider extends ChangeNotifier {
  LeaderboardData? _data;
  bool    _loading = false;
  String? _error;
  String  _mode = 'all_time';

  LeaderboardData? get data    => _data;
  bool             get loading => _loading;
  String?          get error   => _error;
  String           get mode    => _mode;

  Future<void> fetchLeaderboard({String mode = 'all_time'}) async {
    if (_loading) return;
    _mode    = mode;
    _loading = true;
    _error   = null;
    notifyListeners();

    try {
      final raw = await ApiClient.getLeaderboard(mode: mode);
      _data = LeaderboardData.fromJson(raw as Map<String, dynamic>);
      dev.log('[Leaderboard] loaded mode=$mode top=${_data!.topUsers.length}',
          name: 'LeaderboardProvider');
    } on ApiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = 'Could not load leaderboard.';
      dev.log('[Leaderboard] error: $e', name: 'LeaderboardProvider');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> switchMode(String mode) => fetchLeaderboard(mode: mode);

  /// Called after study-ping returns — updates my stats without full refetch.
  void updateMyStreak(int current, int longest) {
    if (_data == null) return;
    final oldStats = _data!.myStats;
    _data = LeaderboardData(
      mode:     _data!.mode,
      topUsers: _data!.topUsers,
      myStats:  MyLeaderboardStats(
        rank:            oldStats.rank,
        currentStreak:   current,
        longestStreak:   longest,
        totalStudyDays:  oldStats.totalStudyDays,
        materialsOpened: oldStats.materialsOpened,
        score:           oldStats.score,
        mode:            oldStats.mode,
      ),
    );
    notifyListeners();
  }
}
