// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;

import 'package:client/features/notifications/repositories/notification_socket_transport_base.dart';

NotificationSocketTransport createNotificationSocketTransport() {
  return _WebNotificationSocketTransport();
}

class _WebNotificationSocketTransport implements NotificationSocketTransport {
  @override
  Future<NotificationSocketConnection> connect(Uri uri) async {
    final socket = html.WebSocket(uri.toString());
    final ready = Completer<void>();
    late final StreamSubscription<html.Event> openSubscription;
    late final StreamSubscription<html.Event> errorSubscription;

    openSubscription = socket.onOpen.listen((_) {
      if (!ready.isCompleted) {
        ready.complete();
      }
    });
    errorSubscription = socket.onError.listen((_) {
      if (!ready.isCompleted) {
        ready.completeError(
          StateError('Không thể kết nối kênh thông báo trực tiếp.'),
        );
      }
    });

    try {
      await ready.future;
    } finally {
      await openSubscription.cancel();
      await errorSubscription.cancel();
    }

    return _WebNotificationSocketConnection(socket);
  }
}

class _WebNotificationSocketConnection implements NotificationSocketConnection {
  final html.WebSocket _socket;

  _WebNotificationSocketConnection(this._socket);

  @override
  Stream<String> get messages =>
      _socket.onMessage.map((event) => event.data.toString());

  @override
  Future<void> close() async {
    _socket.close();
  }
}
