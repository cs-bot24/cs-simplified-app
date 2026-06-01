import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../models/notification_model.dart';
import '../models/announcement_model.dart';

/// Unified notification feed provider.
///
/// Sources:
///   /notifications  → in-app records including global announcements
///                     (each announcement POST now writes a Notification row
///                      with the correct category field)
///   /announcements  → announcement archive (deduplicated by negative ID)
///
/// unreadCount = items where isRead == false.
/// The badge in home_screen reads this getter via Consumer<>.
/// It updates the moment fetchNotifications() completes — no page
/// open required.
class NotificationProvider extends ChangeNotifier {
  List<NotificationModel> _notifications = [];
  bool    _loading = false;
  String? _error;

  List<NotificationModel> get notifications => _notifications;
  bool    get loading    => _loading;
  String? get error      => _error;

  /// Badge count — simply how many items are unread.
  /// Updates immediately when fetchNotifications() completes.
  int get unreadCount =>
      _notifications.where((n) => !n.isRead).length;

  /// Fetches /notifications and /announcements in parallel, merges,
  /// deduplicates (announcements also appear in /notifications now),
  /// and sorts newest first.
  Future<void> fetchNotifications() async {
    _loading = true;
    _error   = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _fetchInAppNotifications(),
        _fetchAnnouncements(),
      ]);

      final inApp         = results[0]; // positive IDs
      final announcements = results[1]; // negative IDs (archive only)

      // Collect positive IDs from in-app notifications so we can
      // skip any announcement that's already represented there.
      // (The announcements endpoint and notifications endpoint now
      //  both contain the same announcement data — we prefer the
      //  /notifications version because it has the correct is_read state.)
      final inAppIds = inApp.map((n) => n.id).toSet();

      // Only include archive announcements that are NOT already in /notifications.
      // Since announcements are now written to notifications table too,
      // the /announcements list is mostly redundant — but kept as fallback.
      final archiveOnly = announcements
          .where((a) => !inAppIds.contains(-a.id))
          .toList();

      _notifications = [...inApp, ...archiveOnly]
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      _error = null;
      dev.log(
        '[NotificationProvider] loaded ${_notifications.length} items '
        '(${inApp.length} in-app, ${archiveOnly.length} archive), '
        'unread=${unreadCount}',
        name: 'NotificationProvider',
      );
    } catch (e) {
      _error = 'Could not load notifications.';
      dev.log('[NotificationProvider] fetch error: $e',
          name: 'NotificationProvider');
    } finally {
      _loading = false;
      notifyListeners();  // ← badge rebuilds here
    }
  }

  /// Mark a single item read. For in-app notifications (positive ID)
  /// the backend is updated. For archive announcements (negative ID)
  /// local state only.
  Future<void> markRead(int id) async {
    final idx = _notifications.indexWhere((n) => n.id == id);
    if (idx == -1) return;
    if (id > 0) {
      try { await ApiClient.markNotificationRead(id); } catch (_) {}
    }
    _notifications[idx] = _notifications[idx].copyWith(isRead: true);
    notifyListeners();
  }

  /// Mark all items read and refresh from server.
  Future<void> markAllRead() async {
    // Mark positive-ID items on backend
    for (final n in _notifications.where((n) => !n.isRead && n.id > 0)) {
      try { await ApiClient.markNotificationRead(n.id); } catch (_) {}
    }
    _notifications = _notifications
        .map((n) => n.copyWith(isRead: true))
        .toList();
    notifyListeners();
  }

  /// Called when user opens the notifications page.
  /// Refreshes the list so the badge reflects current server state.
  Future<void> markPageOpened() async {
    await fetchNotifications();
  }

  Future<void> deleteNotification(int id) async {
    if (id > 0) {
      try { await ApiClient.deleteNotification(id); } catch (_) {}
    }
    _notifications.removeWhere((n) => n.id == id);
    notifyListeners();
  }

  /// Insert a foreground FCM message directly — badge updates immediately
  /// without a network round-trip.
  void addLocal(NotificationModel n) {
    // Avoid duplicates from the next fetch
    _notifications.removeWhere((x) => x.id == n.id);
    _notifications.insert(0, n);
    notifyListeners();
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  Future<List<NotificationModel>> _fetchInAppNotifications() async {
    try {
      final data = await ApiClient.getNotifications();
      return (data as List)
          .map((j) => NotificationModel.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (e) {
      dev.log('[NotificationProvider] /notifications failed: $e',
          name: 'NotificationProvider');
      return [];
    }
  }

  /// Fetches /announcements as a fallback archive.
  /// Uses negative IDs to avoid collision with /notifications positive IDs.
  Future<List<NotificationModel>> _fetchAnnouncements() async {
    try {
      final data = await ApiClient.getAnnouncements();
      return (data as List).map((j) {
        final ann = AnnouncementModel.fromJson(j as Map<String, dynamic>);
        return NotificationModel(
          id:        -ann.id,
          title:     ann.title,
          body:      ann.message,
          category:  ann.category,
          isRead:    false,
          createdAt: DateTime.tryParse(ann.createdAt) ?? DateTime.now(),
        );
      }).toList();
    } catch (e) {
      dev.log('[NotificationProvider] /announcements failed: $e',
          name: 'NotificationProvider');
      return [];
    }
  }
}
