import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../models/notification_model.dart';
import '../models/announcement_model.dart';

/// Unified notification feed provider.
///
/// Merges two sources:
///   1. /notifications  — in-app notification records (server-generated)
///   2. /announcements  — admin-authored announcements (Phase 1.5C)
///
/// Both sources are mapped to [NotificationModel] so the UI works with
/// a single list type. Announcements are marked "unread" by default since
/// we have no per-user read-state table for announcements yet — each fetch
/// resets them. This is intentional for Phase 1.5C; per-user read state
/// for announcements is a Phase 1.5D concern.
///
/// The [unreadCount] getter drives the red badge on the home screen bell.
/// It must reflect both unread in-app notifications AND all announcements
/// that are newer than the last time the user opened the notifications page.
class NotificationProvider extends ChangeNotifier {
  List<NotificationModel> _notifications = [];
  bool    _loading = false;
  String? _error;

  // Tracks the timestamp of the most recent item the user has seen.
  // Updated when the notifications page is opened.
  DateTime? _lastSeenAt;

  List<NotificationModel> get notifications => _notifications;
  bool    get loading    => _loading;
  String? get error      => _error;

  /// Unread count = items whose createdAt is after _lastSeenAt.
  /// Falls back to the isRead flag on notification-type items.
  int get unreadCount {
    if (_lastSeenAt == null) {
      // First load — count everything that is explicitly marked unread,
      // plus any announcement (they default to unread).
      return _notifications.where((n) => !n.isRead).length;
    }
    return _notifications
        .where((n) => n.createdAt.isAfter(_lastSeenAt!))
        .length;
  }

  /// Fetches both /notifications and /announcements in parallel,
  /// merges them, and sorts by createdAt descending.
  ///
  /// Errors in either source are handled independently:
  ///   - if /notifications fails, we still show announcements
  ///   - if /announcements fails, we still show notifications
  Future<void> fetchNotifications() async {
    _loading = true;
    _error   = null;
    notifyListeners();

    try {
      // Run both fetches concurrently.
      final results = await Future.wait([
        _fetchInAppNotifications(),
        _fetchAnnouncements(),
      ]);

      final inApp         = results[0];
      final announcements = results[1];

      // Merge and sort newest first.
      _notifications = [...inApp, ...announcements]
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      _error = null;
    } catch (e) {
      _error = 'Could not load notifications.';
      dev.log('[NotificationProvider] fetch error: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Mark a single in-app notification as read on the backend
  /// and update local state. Announcements have no per-user read
  /// endpoint yet, so we only update local state for those.
  Future<void> markRead(int id) async {
    final idx = _notifications.indexWhere((n) => n.id == id);
    if (idx == -1) return;

    final item = _notifications[idx];

    // Only call the backend endpoint for real notifications
    // (announcements use negative IDs to avoid collisions — see below).
    if (item.id > 0) {
      try {
        await ApiClient.markNotificationRead(item.id);
      } catch (_) {}
    }

    _notifications[idx] = item.copyWith(isRead: true);
    notifyListeners();
  }

  /// Mark all items as read. For in-app notifications we call the
  /// backend; for announcements we update local state only.
  Future<void> markAllRead() async {
    final unread = _notifications.where((n) => !n.isRead).toList();
    for (final n in unread) {
      if (n.id > 0) {
        try {
          await ApiClient.markNotificationRead(n.id);
        } catch (_) {}
      }
    }
    _notifications = _notifications.map((n) => n.copyWith(isRead: true)).toList();

    // Record the current time as "last seen" so the badge resets.
    _lastSeenAt = DateTime.now();
    notifyListeners();
  }

  /// Record that the user has opened the notifications page.
  /// Calling this collapses the badge to zero until new items arrive.
  void markPageOpened() {
    _lastSeenAt = DateTime.now();
    notifyListeners();
  }

  Future<void> deleteNotification(int id) async {
    try {
      await ApiClient.deleteNotification(id);
      _notifications.removeWhere((n) => n.id == id);
      notifyListeners();
    } catch (_) {}
  }

  /// Insert a notification from an FCM foreground message without
  /// a network call. The badge updates immediately.
  void addLocal(NotificationModel n) {
    _notifications.insert(0, n);
    notifyListeners();
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  Future<List<NotificationModel>> _fetchInAppNotifications() async {
    try {
      final data = await ApiClient.getNotifications();
      return (data as List)
          .map((j) => NotificationModel.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (e) {
      dev.log('[NotificationProvider] /notifications failed: $e');
      return [];
    }
  }

  /// Converts announcements to [NotificationModel] using negative IDs
  /// (id = -announcement.id) so they never collide with real notification IDs.
  /// category is preserved verbatim so the filter tabs work correctly.
  Future<List<NotificationModel>> _fetchAnnouncements() async {
    try {
      final data = await ApiClient.getAnnouncements();
      return (data as List).map((j) {
        final ann = AnnouncementModel.fromJson(j as Map<String, dynamic>);
        return NotificationModel(
          id:        -ann.id,          // negative = announcement
          title:     ann.title,
          body:      ann.message,
          category:  ann.category,     // 'announcement' | 'material' | 'system'
          isRead:    false,            // announcements start unread
          createdAt: DateTime.tryParse(ann.createdAt) ?? DateTime.now(),
        );
      }).toList();
    } catch (e) {
      dev.log('[NotificationProvider] /announcements failed: $e');
      return [];
    }
  }
}
