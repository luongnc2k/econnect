import 'dart:convert';

import 'package:client/features/notifications/model/app_notification.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final notificationsLocalRepositoryProvider = Provider<NotificationsLocalRepository>(
  (_) => NotificationsLocalRepository(),
);

class NotificationsLocalRepository {
  String _notificationsKey(String userId) => 'notifications.cache.$userId';
  String _unreadCountKey(String userId) => 'notifications.unread_count.$userId';

  Future<List<AppNotification>> getCachedNotifications(String userId) async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_notificationsKey(userId));
    if (raw == null || raw.isEmpty) {
      return const [];
    }

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((item) => AppNotification.fromMap(Map<String, dynamic>.from(item as Map)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<int?> getCachedUnreadCount(String userId) async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getInt(_unreadCountKey(userId));
  }

  Future<void> saveInbox(
    String userId, {
    required List<AppNotification> notifications,
    required int unreadCount,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _notificationsKey(userId),
      jsonEncode(notifications.map((notification) => notification.toMap()).toList()),
    );
    await preferences.setInt(_unreadCountKey(userId), unreadCount);
  }

  Future<void> clearInbox(String userId) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_notificationsKey(userId));
    await preferences.remove(_unreadCountKey(userId));
  }
}
