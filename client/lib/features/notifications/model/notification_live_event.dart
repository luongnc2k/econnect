class NotificationLiveEvent {
  final String type;
  final int? unreadCount;
  final String? latestNotificationId;

  const NotificationLiveEvent({
    required this.type,
    this.unreadCount,
    this.latestNotificationId,
  });

  factory NotificationLiveEvent.fromMap(Map<String, dynamic> map) {
    return NotificationLiveEvent(
      type: map['type']?.toString() ?? '',
      unreadCount: (map['unread_count'] as num?)?.toInt(),
      latestNotificationId: map['latest_notification_id']?.toString(),
    );
  }
}
