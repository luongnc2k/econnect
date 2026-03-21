import 'package:client/features/notifications/repositories/notification_socket_transport_base.dart';
import 'package:client/features/notifications/repositories/notification_socket_transport_factory_stub.dart'
    if (dart.library.io) 'package:client/features/notifications/repositories/notification_socket_transport_factory_io.dart'
    if (dart.library.html) 'package:client/features/notifications/repositories/notification_socket_transport_factory_web.dart'
    as transport_factory;

export 'package:client/features/notifications/repositories/notification_socket_transport_base.dart';

NotificationSocketTransport createNotificationSocketTransport() {
  return transport_factory.createNotificationSocketTransport();
}
