import 'dart:io';

import 'package:client/features/notifications/repositories/notification_socket_transport_base.dart';

NotificationSocketTransport createNotificationSocketTransport() {
  return _IoNotificationSocketTransport();
}

class _IoNotificationSocketTransport implements NotificationSocketTransport {
  @override
  Future<NotificationSocketConnection> connect(Uri uri) async {
    final socket = await WebSocket.connect(uri.toString());
    return _IoNotificationSocketConnection(socket);
  }
}

class _IoNotificationSocketConnection implements NotificationSocketConnection {
  final WebSocket _socket;

  _IoNotificationSocketConnection(this._socket);

  @override
  Stream<String> get messages => _socket.map((event) => event.toString());

  @override
  Future<void> close() async {
    await _socket.close();
  }
}
