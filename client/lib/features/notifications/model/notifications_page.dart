import 'package:client/features/notifications/model/app_notification.dart';

class NotificationsPage {
  final List<AppNotification> items;
  final String? nextCursor;
  final bool hasMore;

  const NotificationsPage({
    required this.items,
    required this.nextCursor,
    required this.hasMore,
  });

  factory NotificationsPage.fromMap(Map<String, dynamic> map) {
    final rawItems = map['items'];
    return NotificationsPage(
      items: rawItems is List
          ? rawItems
              .map((item) => AppNotification.fromMap(item as Map<String, dynamic>))
              .toList()
          : const [],
      nextCursor: map['next_cursor']?.toString(),
      hasMore: map['has_more'] as bool? ?? false,
    );
  }
}
