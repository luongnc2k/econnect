import 'dart:async';

import 'package:client/core/failure/failure.dart';
import 'package:client/core/providers/current_user_notifier.dart';
import 'package:client/features/notifications/model/app_notification.dart';
import 'package:client/features/notifications/model/notification_live_event.dart';
import 'package:client/features/notifications/model/notifications_state.dart';
import 'package:client/features/notifications/repositories/notifications_live_repository.dart';
import 'package:client/features/notifications/repositories/notifications_local_repository.dart';
import 'package:client/features/notifications/repositories/notifications_remote_repository.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart' show Either, Left, Right;

final notificationsControllerProvider =
    NotifierProvider<NotificationsController, NotificationsState>(
      NotificationsController.new,
    );

final unreadNotificationsCountProvider = Provider<int>((ref) {
  return ref.watch(notificationsControllerProvider).unreadCount;
});

class NotificationsController extends Notifier<NotificationsState>
    with WidgetsBindingObserver {
  static const _pageSize = 20;
  static const _pollInterval = Duration(seconds: 45);
  static const _liveReconnectDelay = Duration(seconds: 4);

  Timer? _pollTimer;
  Timer? _liveReconnectTimer;
  StreamSubscription<NotificationLiveEvent>? _liveUpdatesSubscription;
  NotificationsLiveConnection? _liveConnection;
  String? _activeUserId;
  bool _observerRegistered = false;
  bool _isAppActive = true;
  bool _connectingLiveUpdates = false;
  bool _stateReady = false;

  @override
  NotificationsState build() {
    ref.onDispose(_dispose);
    _registerLifecycleObserver();

    final user = ref.watch(currentUserProvider);
    if (user == null) {
      _disposePolling();
      unawaited(_disposeLiveUpdates(updateState: false));
      _activeUserId = null;
      _stateReady = true;
      return const NotificationsState();
    }

    if (_activeUserId != user.id) {
      _disposePolling();
      unawaited(_disposeLiveUpdates(updateState: false));
      _activeUserId = user.id;
      Future.microtask(() async {
        await _hydrateFromCache(user.id);
        await refresh();
        _startPolling();
        _startLiveUpdates();
      });
    } else {
      _startPolling();
      _startLiveUpdates();
    }

    _stateReady = true;
    return const NotificationsState(isLoading: true);
  }

  Future<void> _hydrateFromCache(String userId) async {
    final localRepository = ref.read(notificationsLocalRepositoryProvider);
    final cachedNotifications = await localRepository.getCachedNotifications(
      userId,
    );
    final cachedUnreadCount = await localRepository.getCachedUnreadCount(
      userId,
    );

    if (cachedNotifications.isEmpty) {
      return;
    }

    state = state.copyWith(
      notifications: cachedNotifications,
      unreadCount: cachedUnreadCount ?? state.unreadCount,
      isLoading: false,
      hydratedFromCache: true,
      clearError: true,
    );
  }

  Future<void> refresh({bool silent = false}) async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      return;
    }

    if (!silent && state.notifications.isEmpty) {
      state = state.copyWith(isLoading: true, clearError: true);
    } else if (!silent) {
      state = state.copyWith(clearError: true);
    }

    final remoteRepository = ref.read(notificationsRemoteRepositoryProvider);
    final filter = _resolveFilter(state.selectedFilterKey);
    final notificationsResult = await remoteRepository.getNotificationsPage(
      token: user.token,
      limit: _pageSize,
      cursor: null,
      notificationType: filter.notificationType,
      unreadOnly: filter.unreadOnly,
    );
    final unreadCountResult = await remoteRepository.getUnreadCount(
      token: user.token,
    );

    var unreadCount = state.unreadCount;
    if (unreadCountResult is Right<AppFailure, int>) {
      unreadCount = unreadCountResult.value;
    }

    switch (notificationsResult) {
      case Left(value: final failure):
        if (state.notifications.isEmpty) {
          state = state.copyWith(
            isLoading: false,
            unreadCount: unreadCount,
            error: failure.message,
          );
        } else {
          state = state.copyWith(isLoading: false, unreadCount: unreadCount);
        }
      case Right(value: final page):
        state = state.copyWith(
          notifications: page.items,
          unreadCount: unreadCount,
          isLoading: false,
          hasMore: page.hasMore,
          nextCursor: page.nextCursor,
          hydratedFromCache: false,
          clearError: true,
        );
        await _persistInboxIfNeeded();
    }
  }

  Future<void> loadMore() async {
    final user = ref.read(currentUserProvider);
    final nextCursor = state.nextCursor;
    if (user == null ||
        state.isLoadingMore ||
        !state.hasMore ||
        nextCursor == null ||
        nextCursor.isEmpty) {
      return;
    }

    state = state.copyWith(isLoadingMore: true, clearError: true);

    final filter = _resolveFilter(state.selectedFilterKey);
    final result = await ref
        .read(notificationsRemoteRepositoryProvider)
        .getNotificationsPage(
          token: user.token,
          limit: _pageSize,
          cursor: nextCursor,
          notificationType: filter.notificationType,
          unreadOnly: filter.unreadOnly,
        );

    switch (result) {
      case Left(value: final failure):
        state = state.copyWith(isLoadingMore: false, error: failure.message);
      case Right(value: final page):
        state = state.copyWith(
          notifications: [...state.notifications, ...page.items],
          isLoadingMore: false,
          hasMore: page.hasMore,
          nextCursor: page.nextCursor,
          clearError: true,
        );
        await _persistInboxIfNeeded();
    }
  }

  Future<void> setFilter(String filterKey) async {
    if (filterKey == state.selectedFilterKey) {
      return;
    }

    state = state.copyWith(
      selectedFilterKey: filterKey,
      notifications: const [],
      hasMore: true,
      isLoading: true,
      clearNextCursor: true,
      clearError: true,
    );
    await refresh();
  }

  void setGroupingMode(String groupingMode) {
    if (groupingMode == state.groupingMode) {
      return;
    }

    state = state.copyWith(groupingMode: groupingMode);
  }

  Future<AppFailure?> markAsRead(AppNotification notification) async {
    final user = ref.read(currentUserProvider);
    if (user == null || notification.isRead) {
      return null;
    }

    final result = await ref
        .read(notificationsRemoteRepositoryProvider)
        .markAsRead(token: user.token, notificationId: notification.id);
    switch (result) {
      case Left(value: final failure):
        return failure;
      case Right(value: final updated):
        final notifications =
            state.selectedFilterKey == NotificationFilterKeys.unread
            ? state.notifications
                  .where((item) => item.id != updated.id)
                  .toList()
            : state.notifications
                  .map((item) => item.id == updated.id ? updated : item)
                  .toList();

        final nextUnreadCount = notification.isRead
            ? state.unreadCount
            : (state.unreadCount - 1).clamp(0, state.unreadCount).toInt();

        state = state.copyWith(
          notifications: notifications,
          unreadCount: nextUnreadCount,
          clearError: true,
        );
        await _persistInboxIfNeeded();
        return null;
    }
  }

  Future<Either<AppFailure, String>> confirmTeaching(
    AppNotification notification,
  ) async {
    final user = ref.read(currentUserProvider);
    final classId = notification.classId;
    if (user == null || classId == null || classId.isEmpty) {
      return Left(AppFailure('Không tìm thấy lớp học để xác nhận.'));
    }

    state = state.copyWith(actionNotificationId: notification.id);
    final result = await ref
        .read(notificationsRemoteRepositoryProvider)
        .confirmTeaching(token: user.token, classId: classId);

    state = state.copyWith(clearActionNotificationId: true);

    switch (result) {
      case Left(value: final failure):
        return Left(failure);
      case Right(value: final success):
        await markAsRead(notification);
        state = state.copyWith(
          confirmedClassIds: {...state.confirmedClassIds, classId},
        );
        await refresh(silent: true);
        return Right(success.message);
    }
  }

  bool isClassConfirmedLocally(String? classId) {
    if (classId == null || classId.isEmpty) {
      return false;
    }
    return state.confirmedClassIds.contains(classId);
  }

  _NotificationsQuery _resolveFilter(String filterKey) {
    return switch (filterKey) {
      NotificationFilterKeys.unread => const _NotificationsQuery(
        unreadOnly: true,
      ),
      NotificationFilterKeys.minimumReached => const _NotificationsQuery(
        notificationType: NotificationFilterKeys.minimumReached,
      ),
      NotificationFilterKeys.tutorConfirmed => const _NotificationsQuery(
        notificationType: NotificationFilterKeys.tutorConfirmed,
      ),
      NotificationFilterKeys.classStartingSoon => const _NotificationsQuery(
        notificationType: NotificationFilterKeys.classStartingSoon,
      ),
      NotificationFilterKeys.classCancelled => const _NotificationsQuery(
        notificationType: NotificationFilterKeys.classCancelled,
      ),
      NotificationFilterKeys.refundIssued => const _NotificationsQuery(
        notificationType: NotificationFilterKeys.refundIssued,
      ),
      NotificationFilterKeys.payoutUpdated => const _NotificationsQuery(
        notificationType: NotificationFilterKeys.payoutUpdated,
      ),
      NotificationFilterKeys.disputeResolved => const _NotificationsQuery(
        notificationType: NotificationFilterKeys.disputeResolved,
      ),
      _ => const _NotificationsQuery(),
    };
  }

  Future<void> _persistInboxIfNeeded() async {
    final user = ref.read(currentUserProvider);
    if (user == null || state.selectedFilterKey != NotificationFilterKeys.all) {
      return;
    }

    await ref
        .read(notificationsLocalRepositoryProvider)
        .saveInbox(
          user.id,
          notifications: state.notifications,
          unreadCount: state.unreadCount,
        );
  }

  void _startPolling() {
    if (!_isAppActive || ref.read(currentUserProvider) == null) {
      return;
    }

    if (_liveConnection != null) {
      _disposePolling();
      return;
    }

    if (_pollTimer != null) {
      return;
    }

    _pollTimer = Timer.periodic(_pollInterval, (_) {
      unawaited(refresh(silent: true));
    });
  }

  void _disposePolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void _startLiveUpdates() {
    final user = ref.read(currentUserProvider);
    if (user == null ||
        !_isAppActive ||
        _connectingLiveUpdates ||
        _liveConnection != null) {
      return;
    }

    _liveReconnectTimer?.cancel();
    _liveReconnectTimer = null;
    _connectingLiveUpdates = true;

    Future.microtask(() async {
      final result = await ref
          .read(notificationsLiveRepositoryProvider)
          .connect(token: user.token);
      _connectingLiveUpdates = false;

      final currentUser = ref.read(currentUserProvider);
      if (currentUser == null || currentUser.id != user.id || !_isAppActive) {
        if (result is Right<AppFailure, NotificationsLiveConnection>) {
          await result.value.close();
        }
        return;
      }

      switch (result) {
        case Left():
          state = state.copyWith(liveConnected: false);
          _scheduleLiveReconnect();
        case Right(value: final connection):
          _liveConnection = connection;
          _disposePolling();
          state = state.copyWith(liveConnected: true);
          _liveUpdatesSubscription = connection.events.listen(
            _handleLiveEvent,
            onError: (_) => _handleLiveUpdatesInterrupted(user.id),
            onDone: () => _handleLiveUpdatesInterrupted(user.id),
          );
      }
    });
  }

  void _handleLiveEvent(NotificationLiveEvent event) {
    _disposePolling();

    if (!state.liveConnected) {
      state = state.copyWith(liveConnected: true);
    }

    if (event.unreadCount != null && event.unreadCount != state.unreadCount) {
      state = state.copyWith(unreadCount: event.unreadCount);
    }

    if (event.type == 'notifications_changed') {
      unawaited(refresh(silent: true));
    }
  }

  void _handleLiveUpdatesInterrupted(String userId) {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null || currentUser.id != userId) {
      return;
    }

    _liveUpdatesSubscription = null;
    _liveConnection = null;
    state = state.copyWith(liveConnected: false);
    _startPolling();
    _scheduleLiveReconnect();
  }

  void _scheduleLiveReconnect() {
    if (!_isAppActive ||
        ref.read(currentUserProvider) == null ||
        _liveReconnectTimer != null) {
      return;
    }

    _liveReconnectTimer = Timer(_liveReconnectDelay, () {
      _liveReconnectTimer = null;
      _startLiveUpdates();
    });
  }

  Future<void> _disposeLiveUpdates({bool updateState = true}) async {
    _liveReconnectTimer?.cancel();
    _liveReconnectTimer = null;

    if (updateState && _stateReady && state.liveConnected) {
      state = state.copyWith(liveConnected: false);
    }

    final subscription = _liveUpdatesSubscription;
    _liveUpdatesSubscription = null;
    await subscription?.cancel();

    final connection = _liveConnection;
    _liveConnection = null;
    await connection?.close();
  }

  void _registerLifecycleObserver() {
    if (_observerRegistered) {
      return;
    }

    WidgetsBinding.instance.addObserver(this);
    _observerRegistered = true;
  }

  void _unregisterLifecycleObserver() {
    if (!_observerRegistered) {
      return;
    }

    WidgetsBinding.instance.removeObserver(this);
    _observerRegistered = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _isAppActive = true;
        _startPolling();
        _startLiveUpdates();
        unawaited(refresh(silent: true));
        return;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      default:
        _isAppActive = false;
        _disposePolling();
        unawaited(_disposeLiveUpdates());
        return;
    }
  }

  void _dispose() {
    _disposePolling();
    unawaited(_disposeLiveUpdates(updateState: false));
    _unregisterLifecycleObserver();
  }
}

class _NotificationsQuery {
  final String? notificationType;
  final bool unreadOnly;

  const _NotificationsQuery({this.notificationType, this.unreadOnly = false});
}
