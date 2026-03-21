import 'package:client/features/notifications/model/app_notification.dart';

abstract final class NotificationFilterKeys {
  static const all = 'all';
  static const unread = 'unread';
  static const minimumReached = 'minimum_participants_reached';
  static const tutorConfirmed = 'tutor_confirmed_teaching';
  static const classStartingSoon = 'class_starting_soon';
  static const classCancelled = 'class_cancelled';
  static const refundIssued = 'refund_issued';
  static const payoutUpdated = 'payout_updated';
  static const disputeResolved = 'dispute_resolved';
}

abstract final class NotificationGroupingModes {
  static const byDate = 'by_date';
  static const byType = 'by_type';
}

class NotificationsState {
  final List<AppNotification> notifications;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final int unreadCount;
  final String? error;
  final String selectedFilterKey;
  final String groupingMode;
  final String? actionNotificationId;
  final Set<String> confirmedClassIds;
  final bool hydratedFromCache;
  final String? nextCursor;
  final bool liveConnected;

  const NotificationsState({
    this.notifications = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.unreadCount = 0,
    this.error,
    this.selectedFilterKey = NotificationFilterKeys.all,
    this.groupingMode = NotificationGroupingModes.byDate,
    this.actionNotificationId,
    this.confirmedClassIds = const <String>{},
    this.hydratedFromCache = false,
    this.nextCursor,
    this.liveConnected = false,
  });

  NotificationsState copyWith({
    List<AppNotification>? notifications,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    int? unreadCount,
    String? error,
    bool clearError = false,
    String? selectedFilterKey,
    String? groupingMode,
    String? actionNotificationId,
    bool clearActionNotificationId = false,
    Set<String>? confirmedClassIds,
    bool? hydratedFromCache,
    String? nextCursor,
    bool clearNextCursor = false,
    bool? liveConnected,
  }) {
    return NotificationsState(
      notifications: notifications ?? this.notifications,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      unreadCount: unreadCount ?? this.unreadCount,
      error: clearError ? null : (error ?? this.error),
      selectedFilterKey: selectedFilterKey ?? this.selectedFilterKey,
      groupingMode: groupingMode ?? this.groupingMode,
      actionNotificationId: clearActionNotificationId
          ? null
          : (actionNotificationId ?? this.actionNotificationId),
      confirmedClassIds: confirmedClassIds ?? this.confirmedClassIds,
      hydratedFromCache: hydratedFromCache ?? this.hydratedFromCache,
      nextCursor: clearNextCursor ? null : (nextCursor ?? this.nextCursor),
      liveConnected: liveConnected ?? this.liveConnected,
    );
  }
}
