abstract class NotificationSocketConnection {
  Stream<String> get messages;

  Future<void> close();
}

abstract class NotificationSocketTransport {
  Future<NotificationSocketConnection> connect(Uri uri);
}
