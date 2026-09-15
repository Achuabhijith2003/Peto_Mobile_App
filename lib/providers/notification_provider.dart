import 'package:flutter/material.dart';
import '../models/notification_model.dart';
import '../services/api_service.dart';

class NotificationProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  List<NotificationItem> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = false;
  String? _errorMessage;
  int _page = 1;
  bool _hasMore = true;

  List<NotificationItem> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasMore => _hasMore;

  Future<void> fetchUnreadCount() async {
    try {
      final res = await _apiService.getUnreadNotificationCount();
      if (res.statusCode == 200 && res.data != null) {
        final count = res.data['unread'] ?? res.data['count'] ?? 0;
        _unreadCount = count is int ? count : int.tryParse(count.toString()) ?? 0;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error fetching unread notification count: $e');
    }
  }

  Future<void> fetchNotifications({bool refresh = false}) async {
    if (refresh) {
      _page = 1;
      _hasMore = true;
    }

    if (_isLoading) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _apiService.getNotifications(page: _page, limit: 20);

      if (res.statusCode == 200 && res.data != null) {
        final rawData = res.data['data'] ?? res.data['notifications'] ?? [];
        final List<NotificationItem> loaded = [];

        if (rawData is List) {
          for (final item in rawData) {
            if (item is Map<String, dynamic>) {
              loaded.add(NotificationItem.fromJson(item));
            }
          }
        }

        final pagination = res.data['pagination'];
        if (pagination is Map<String, dynamic>) {
          _hasMore = pagination['hasMore'] == true;
        } else {
          _hasMore = loaded.length >= 20;
        }

        if (refresh) {
          _notifications = loaded;
        } else {
          _notifications.addAll(loaded);
        }

        _page++;
        // Also refresh unread count
        await fetchUnreadCount();
      }
    } catch (e) {
      debugPrint('Error fetching notifications: $e');
      _errorMessage = 'Failed to load notifications';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> markAsRead(String notificationId) async {
    final idx = _notifications.indexWhere((n) => n.id == notificationId);
    if (idx != -1 && !_notifications[idx].isRead) {
      _notifications[idx] = _notifications[idx].copyWith(isRead: true);
      if (_unreadCount > 0) _unreadCount--;
      notifyListeners();

      try {
        await _apiService.markNotificationRead(notificationId);
      } catch (e) {
        debugPrint('Error marking notification read: $e');
      }
    }
  }

  Future<void> markAllAsRead() async {
    if (_notifications.isEmpty && _unreadCount == 0) return;

    _notifications = _notifications.map((n) => n.copyWith(isRead: true)).toList();
    _unreadCount = 0;
    notifyListeners();

    try {
      await _apiService.markAllNotificationsRead();
    } catch (e) {
      debugPrint('Error marking all notifications read: $e');
    }
  }

  Future<bool> deleteNotification(String notificationId) async {
    final idx = _notifications.indexWhere((n) => n.id == notificationId);
    if (idx == -1) return false;

    final removed = _notifications.removeAt(idx);
    if (!removed.isRead && _unreadCount > 0) {
      _unreadCount--;
    }
    notifyListeners();

    try {
      await _apiService.deleteNotification(notificationId);
      return true;
    } catch (e) {
      debugPrint('Error deleting notification: $e');
      // Re-insert if failed
      _notifications.insert(idx, removed);
      if (!removed.isRead) _unreadCount++;
      notifyListeners();
      return false;
    }
  }
}
