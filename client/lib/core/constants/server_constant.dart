class ServerConstant {
  static const String serverURL = String.fromEnvironment(
    'SERVER_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );

  static Uri? get serverUri => Uri.tryParse(serverURL);

  static bool get isLocalServerUrl {
    final host = serverUri?.host.toLowerCase();
    return host == null ||
        host.isEmpty ||
        host == 'localhost' ||
        host == '127.0.0.1' ||
        host == '0.0.0.0' ||
        host == '10.0.2.2';
  }

  static bool get usesHttps => serverUri?.scheme.toLowerCase() == 'https';

  static Uri? notificationWebSocketUri({required String token}) {
    final uri = serverUri;
    if (uri == null) {
      return null;
    }

    final wsScheme = uri.scheme.toLowerCase() == 'https' ? 'wss' : 'ws';
    return uri.replace(
      scheme: wsScheme,
      path: '/notifications/ws',
      queryParameters: {'token': token},
    );
  }

  static bool get isReleaseReady =>
      serverUri != null && !isLocalServerUrl && usesHttps;
}
