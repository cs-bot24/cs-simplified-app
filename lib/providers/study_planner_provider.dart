// lib/providers/study_planner_provider.dart
//
// Lightweight, app-wide source of truth for "today's study sessions".
//
// Powers:
//   - The 🔴 badge on the Planner tab (bottom nav / nav rail)
//   - The "Study Reminders" card on the Home screen
//
// This provider is intentionally minimal — it only tracks today's
// sessions across all of the user's study plans. The full Study Planner
// screen continues to manage its own detailed state, but calls
// `refresh()` on this provider whenever plans/sessions change so the
// badge and home card stay in sync immediately.

import 'package:flutter/material.dart';
import '../core/api_client.dart';

/// A single study session scheduled for "today".
class TodayStudySession {
  final int      id;
  final int      planId;
  final String   title;        // topic/session title
  final String?  courseCode;
  final String   courseName;
  final DateTime start;
  final int      durationMins;
  final bool     isCompleted;

  TodayStudySession({
    required this.id,
    required this.planId,
    required this.title,
    this.courseCode,
    required this.courseName,
    required this.start,
    required this.durationMins,
    required this.isCompleted,
  });

  DateTime get end => start.add(Duration(minutes: durationMins));

  /// Display label for the course, e.g. "CSC 201" or falls back to name.
  String get courseLabel => (courseCode != null && courseCode!.isNotEmpty)
      ? courseCode!
      : courseName;
}

class StudyPlannerProvider extends ChangeNotifier {
  List<TodayStudySession> _today = [];
  bool   _loading = false;
  DateTime? _lastLoadedDay;

  List<TodayStudySession> get todaySessions => List.unmodifiable(_today);

  List<TodayStudySession> get unfinishedToday =>
      _today.where((s) => !s.isCompleted).toList();

  int get unfinishedCount => unfinishedToday.length;

  bool get hasUnfinishedToday => unfinishedCount > 0;

  bool get loading => _loading;

  /// Fetches all study plans and extracts today's sessions.
  /// Safe to call repeatedly (app start, resume, after edits).
  Future<void> refresh() async {
    _loading = true;
    notifyListeners();

    try {
      final data = await ApiClient.getStudyPlans();
      final now  = DateTime.now();
      final today = <TodayStudySession>[];

      for (final raw in data) {
        final plan = raw as Map<String, dynamic>;
        final courseCode = plan['course_code'] as String?;
        final courseName = plan['course_name'] as String? ?? 'Study';
        final sessions   = (plan['sessions'] as List?) ?? [];

        for (final s in sessions) {
          final session = s as Map<String, dynamic>;
          final scheduled = DateTime.tryParse(
              session['scheduled_date'] as String? ?? '');
          if (scheduled == null) continue;
          if (scheduled.year != now.year ||
              scheduled.month != now.month ||
              scheduled.day != now.day) {
            continue;
          }

          today.add(TodayStudySession(
            id:           session['id'] as int,
            planId:       plan['id'] as int,
            title:        session['title'] as String? ?? 'Study Session',
            courseCode:   courseCode,
            courseName:   courseName,
            start:        scheduled,
            durationMins: session['duration_mins'] as int? ?? 60,
            isCompleted:  session['is_completed'] as bool? ?? false,
          ));
        }
      }

      today.sort((a, b) => a.start.compareTo(b.start));
      _today = today;
      _lastLoadedDay = DateTime(now.year, now.month, now.day);
    } catch (_) {
      // Silently keep previous state — badge/card simply won't update
      // until the next successful refresh.
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Re-fetches if a new day has started since the last load
  /// (e.g. app resumed after midnight).
  Future<void> refreshIfNewDay() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (_lastLoadedDay == null || _lastLoadedDay != today) {
      await refresh();
    }
  }

  /// Optimistically marks a session complete locally (instant badge/card
  /// update) — call alongside the API request, then `refresh()` to
  /// reconcile with the server.
  void markCompletedLocally(int sessionId) {
    final idx = _today.indexWhere((s) => s.id == sessionId);
    if (idx == -1) return;
    final s = _today[idx];
    _today[idx] = TodayStudySession(
      id: s.id,
      planId: s.planId,
      title: s.title,
      courseCode: s.courseCode,
      courseName: s.courseName,
      start: s.start,
      durationMins: s.durationMins,
      isCompleted: true,
    );
    notifyListeners();
  }

  /// Clears cached state (e.g. on logout).
  void clear() {
    _today = [];
    _lastLoadedDay = null;
    notifyListeners();
  }
}
