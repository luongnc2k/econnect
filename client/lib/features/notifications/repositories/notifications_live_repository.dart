import 'dart:async';
import 'dart:convert';

import 'package:client/core/constants/server_constant.dart';
import 'package:client/core/failure/failure.dart';
import 'package:client/features/notifications/model/notification_live_event.dart';
import 'package:client/features/notifications/repositories/notification_socket_transport.dart';
import 'package:fpdart/fpdart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final notificationsLiveRepositoryProvider = Provider<NotificationsLiveRepository>(
  (_) => NotificationsLiveRepository(),
);

class NotificationsLiveRepository {
  final NotificationSocketTransport _transport;

  NotificationsLiveRepository({
    NotificationSocketTransport? transport,
  }) : _transport = transport ?? createNotificationSocketTransport();

  Future<Either<AppFailure, NotificationsLiveConnection>> connect({
    required String token,
  }) async {
    try {
      final uri = ServerConstant.notificationWebSocketUri(token: token);
      if (uri == null) {
        return Left(AppFailure('Không thể khởi tạo kênh thông báo trực tiếp.'));
      }

      final socket = await _transport.connect(uri);
      final controller = StreamController<NotificationLiveEvent>.broadcast();
      late final StreamSubscription<String> subscription;
      subscription = socket.messages.listen(
        (message) {
          if (message.isEmpty) {
            return;
          }

          try {
            final map = jsonDecode(message) as Map<String, dynamic>;
            controller.add(NotificationLiveEvent.fromMap(map));
          } catch (_) {
            // Bỏ qua payload không hợp lệ để giữ kênh sống.
          }
        },
        onError: controller.addError,
        onDone: () {
          if (!controller.isClosed) {
            controller.close();
          }
        },
      );

      return Right(
        NotificationsLiveConnection(
          events: controller.stream,
          close: () async {
            await subscription.cancel();
            await socket.close();
            if (!controller.isClosed) {
              await controller.close();
            }
          },
        ),
      );
    } catch (e) {
      return Left(AppFailure(e.toString()));
    }
  }
}

class NotificationsLiveConnection {
  final Stream<NotificationLiveEvent> events;
  final Future<void> Function() _onClose;

  const NotificationsLiveConnection({
    required this.events,
    required Future<void> Function() close,
  }) : _onClose = close;

  Future<void> close() => _onClose();
}
