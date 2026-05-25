import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../models/notification_model.dart';

class NotificationProvider extends ChangeNotifier {
  List<NotificationModel> _notifications = [];
  bool _loading = false;
  String? _error;

  List<NotificationModel> get notifications => _notifications;
  bool get loading => _loading;
  String? get error => _error;
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  Future<void> fetchNotifications() async {
    _loading = true; _error = null; notifyListeners();
    try {
      final data = await ApiClient.getNotifications();
      _notifications = data.map((j) => NotificationModel.fromJson(j)).toList();
      _notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false; notifyListeners();
    }
  }

  Future<void> markRead(int id) async {
    try {
      await ApiClient.markNotificationRead(id);
      final idx = _notifications.indexWhere((n) => n.id == id);
      if (idx != -1) {
        _notifications[idx] = _notifications[idx].copyWith(isRead: true);
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> markAllRead() async {
    try {
      await ApiClient.markAllNotificationsRead();
      _notifications = _notifications.map((n) => n.copyWith(isRead: true)).toList();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> deleteNotification(int id) async {
    try {
      await ApiClient.deleteNotification(id);
      _notifications.removeWhere((n) => n.id == id);
      notifyListeners();
    } catch (_) {}
  }

  void addLocal(NotificationModel n) {
    _notifications.insert(0, n);
    notifyListeners();
  }
}
