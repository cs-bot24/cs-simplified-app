import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';
import '../core/api_client.dart';

class AdminStatsProvider extends ChangeNotifier {
  Map<String, dynamic> _stats = {};
  bool    _loading = false;
  String? _error;

  Map<String, dynamic> get stats   => _stats;
  bool                 get loading => _loading;
  String?              get error   => _error;

  int get pendingRequests      => (_stats['pending_requests']      as num?)?.toInt() ?? 0;
  int get unreadFeedback       => (_stats['unread_feedback']       as num?)?.toInt() ?? 0;
  int get unreadMessages       => (_stats['unread_messages']       as num?)?.toInt() ?? 0;
  int get downloadsToday       => (_stats['downloads_today']       as num?)?.toInt() ?? 0;
  int get totalUsers           => (_stats['total_users']           as num?)?.toInt() ?? 0;
  int get activeUsers7d        => (_stats['active_users_7d']       as num?)?.toInt() ?? 0;
  int get totalMaterials       => (_stats['total_materials']       as num?)?.toInt() ?? 0;
  int get downloadsWeek        => (_stats['downloads_week']        as num?)?.toInt() ?? 0;
  /// Open support tickets — powered by the new support_tickets table.
  int get openSupportTickets   => (_stats['open_support_tickets']  as num?)?.toInt() ?? 0;

  // ── AI Tutor stats (Phase 2.0) ─────────────────────────────────────────────
  int  get totalAiQuestions  => (_stats['total_ai_questions']  as num?)?.toInt() ?? 0;
  int  get aiQuestionsToday  => (_stats['ai_questions_today']  as num?)?.toInt() ?? 0;
  int  get premiumAiUsers    => (_stats['premium_ai_users']    as num?)?.toInt() ?? 0;
  List get mostActiveAiUsers => (_stats['most_active_ai_users'] as List?) ?? [];

  List get topMaterials            => (_stats['top_materials']             as List?) ?? [];
  List get recentUploads           => (_stats['recent_uploads']            as List?) ?? [];
  List get pendingRequestsPreview  => (_stats['pending_requests_preview']  as List?) ?? [];

  Future<void> fetchStats() async {
    // Do NOT guard with _loading here — if a previous call silently failed,
    // a manual refresh must be allowed to retry immediately.
    _loading = true;
    _error   = null;
    notifyListeners();

    try {
      debugPrint('[AdminStats] calling GET /analytics...');
      final data = await ApiClient.getAdminStats();
      debugPrint('[AdminStats] response: $data');
      _stats = data;
      _error = null;
    } on ApiException catch (e) {
      _error = 'Dashboard error: ${e.message} (${e.statusCode})';
      debugPrint('[AdminStats] ApiException: ${e.message} status=${e.statusCode}');
      dev.log('[AdminStats] ApiException: ${e.message}', name: 'AdminStatsProvider');
    } catch (e, stack) {
      _error = 'Dashboard error: $e';
      debugPrint('[AdminStats] Unexpected error: $e\n$stack');
      dev.log('[AdminStats] Unexpected: $e', name: 'AdminStatsProvider',
          error: e, stackTrace: stack);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
