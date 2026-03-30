import 'dart:async';

import 'package:client/core/failure/failure.dart';
import 'package:client/core/providers/current_user_notifier.dart';
import 'package:client/features/auth/model/user_model.dart';
import 'package:client/features/notifications/model/app_notification.dart';
import 'package:client/features/notifications/model/notification_live_event.dart';
import 'package:client/features/notifications/model/notifications_page.dart';
import 'package:client/features/notifications/repositories/notifications_live_repository.dart';
import 'package:client/features/notifications/repositories/notifications_local_repository.dart';
import 'package:client/features/notifications/repositories/notifications_remote_repository.dart';
import 'package:client/features/notifications/viewmodel/notifications_controller.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

void main() {
  testWidgets(
    'notifications polling stops after live connect and resumes as fallback after disconnect',
    (tester) async {
      final fakeRemote = _FakeNotificationsRemoteRepository();
      final fakeLocal = _FakeNotificationsLocalRepository();
      final fakeLive = _FakeNotificationsLiveRepository();
      final firstConnection = _TestNotificationsLiveConnection();
      fakeLive.enqueueConnection(firstConnection);
      fakeLive.enqueueFailure();

      final container = ProviderContainer(
        overrides: [
          currentUserProvider.overrideWithValue(_sampleCurrentUser()),
          notificationsRemoteRepositoryProvider.overrideWithValue(fakeRemote),
          notificationsLocalRepositoryProvider.overrideWithValue(fakeLocal),
          notificationsLiveRepositoryProvider.overrideWithValue(fakeLive),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const SizedBox.shrink(),
        ),
      );

      container.read(notificationsControllerProvider);
      await tester.pump();
      await tester.pump();

      expect(fakeRemote.pageCalls, 1);
      expect(fakeRemote.unreadCountCalls, 1);
      expect(fakeLive.connectCalls, 1);
      expect(
        container.read(notificationsControllerProvider).liveConnected,
        isTrue,
      );

      await tester.pump(const Duration(seconds: 46));
      await tester.pump();

      expect(fakeRemote.pageCalls, 1);
      expect(fakeRemote.unreadCountCalls, 1);

      await firstConnection.disconnect();
      await tester.pump();
      await tester.pump(const Duration(seconds: 5));
      await tester.pump();

      expect(
        container.read(notificationsControllerProvider).liveConnected,
        isFalse,
      );
      expect(fakeLive.connectCalls, greaterThanOrEqualTo(2));
      expect(fakeRemote.pageCalls, 1);

      await tester.pump(const Duration(seconds: 46));
      await tester.pump();

      expect(fakeRemote.pageCalls, 2);
      expect(fakeRemote.unreadCountCalls, 2);

      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await tester.pump();
    },
  );
}

UserModel _sampleCurrentUser() {
  return UserModel(
    id: 'teacher-1',
    email: 'teacher@example.com',
    fullName: 'Tutor Demo',
    role: 'teacher',
    isActive: true,
    token: 'token-123',
  );
}

class _FakeNotificationsRemoteRepository extends NotificationsRemoteRepository {
  int pageCalls = 0;
  int unreadCountCalls = 0;

  @override
  Future<Either<AppFailure, NotificationsPage>> getNotificationsPage({
    required String token,
    int limit = 20,
    String? cursor,
    String? notificationType,
    bool unreadOnly = false,
  }) async {
    pageCalls += 1;
    return const Right(
      NotificationsPage(items: [], nextCursor: null, hasMore: false),
    );
  }

  @override
  Future<Either<AppFailure, int>> getUnreadCount({
    required String token,
  }) async {
    unreadCountCalls += 1;
    return const Right(0);
  }
}

class _FakeNotificationsLocalRepository extends NotificationsLocalRepository {
  @override
  Future<List<AppNotification>> getCachedNotifications(String userId) async {
    return const [];
  }

  @override
  Future<int?> getCachedUnreadCount(String userId) async {
    return null;
  }

  @override
  Future<void> saveInbox(
    String userId, {
    required List<AppNotification> notifications,
    required int unreadCount,
  }) async {}
}

class _FakeNotificationsLiveRepository extends NotificationsLiveRepository {
  final List<Either<AppFailure, NotificationsLiveConnection>> _connectResults =
      [];
  int connectCalls = 0;

  void enqueueConnection(_TestNotificationsLiveConnection connection) {
    _connectResults.add(Right(connection.connection));
  }

  void enqueueFailure([String message = 'Live connect failed']) {
    _connectResults.add(Left(AppFailure(message)));
  }

  @override
  Future<Either<AppFailure, NotificationsLiveConnection>> connect({
    required String token,
  }) async {
    connectCalls += 1;
    if (_connectResults.isEmpty) {
      return Left(AppFailure('Live connect failed'));
    }
    return _connectResults.removeAt(0);
  }
}

class _TestNotificationsLiveConnection {
  final StreamController<NotificationLiveEvent> _controller =
      StreamController<NotificationLiveEvent>.broadcast();

  late final NotificationsLiveConnection connection =
      NotificationsLiveConnection(
        events: _controller.stream,
        close: () async {
          if (!_controller.isClosed) {
            await _controller.close();
          }
        },
      );

  Future<void> disconnect() async {
    if (!_controller.isClosed) {
      await _controller.close();
    }
  }
}
