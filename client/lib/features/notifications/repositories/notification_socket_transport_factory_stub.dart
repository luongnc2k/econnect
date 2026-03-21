import 'package:client/features/notifications/repositories/notification_socket_transport_base.dart';

NotificationSocketTransport createNotificationSocketTransport() {
  return _UnsupportedNotificationSocketTransport();
}

class _UnsupportedNotificationSocketTransport implements NotificationSocketTransport {
  @override
  Future<NotificationSocketConnection> connect(Uri uri) {
    throw UnsupportedError('WebSocket không được hỗ trợ trên nền tảng này.');
  }
}
