import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import '../core/api_client.dart';

/// Fetches and exposes all admin dashboard statistics.
/// Registered at root level so the admin dashboard, badge indicators,
/// and any other admin screen can all share the same data.
class AdminStatsProvider extends ChangeNotifier {
  Map<String, dynamic> _stats = {};
  bool    _loading = false;
  String? _error;

  Map<String, dynamic> get stats   => _stats;
  bool                 get loading => _loading;
  String?              get error   => _error;

  // Convenience getters used by badge indicators
  int get pendingRequests => _stats['pending_requests'] as int? ?? 0;
  int get unreadFeedback  => _stats['unread_feedback']  as int? ?? 0;
  int get unreadMessages  => _stats['unread_messages']  as int? ?? 0;
  int get downloadsToday  => _stats['downloads_today']  as int? ?? 0;
  int get totalUsers      => _stats['total_users']      as int? ?? 0;
  int get activeUsers7d   => _stats['active_users_7d']  as int? ?? 0;
  int get totalMaterials  => _stats['total_materials']  as int? ?? 0;
  int get downloadsWeek   => _stats['downloads_week']   as int? ?? 0;

  List get topMaterials   =>
      (_stats['top_materials']  as List?) ?? [];
  List get recentUploads  =>
      (_stats['recent_uploads'] as List?) ?? [];

  Future<void> fetchStats() async {
    if (_loading) return;
    _loading = true;
    notifyListeners();

    try {
      final data = await ApiClient.getAdminStats();
      _stats = data;
      _error = null;
    } on ApiException catch (e) {
      _error = e.message;
      dev.log('[AdminStats] Error: ${e.message}', name: 'AdminStatsProvider');
    } catch (e) {
      _error = 'Could not load stats.';
      dev.log('[AdminStats] Unexpected: $e', name: 'AdminStatsProvider');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
