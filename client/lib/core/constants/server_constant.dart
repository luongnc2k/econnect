import 'package:flutter/foundation.dart';

class ServerConstant {
  static const String _serverUrlOverride = String.fromEnvironment(
    'SERVER_URL',
    defaultValue: '',
  );

  static String get serverURL => resolveServerUrl(
    environmentUrl: _serverUrlOverride,
    isWeb: kIsWeb,
    targetPlatform: defaultTargetPlatform,
    browserBaseUri: kIsWeb ? Uri.base : null,
  );

  static String resolveServerUrl({
    required String environmentUrl,
    required bool isWeb,
    required TargetPlatform targetPlatform,
    Uri? browserBaseUri,
  }) {
    final trimmed = environmentUrl.trim();
    if (trimmed.isNotEmpty) {
      return trimmed;
    }

    if (isWeb) {
      final inferredWebUrl = _inferWebServerUrl(browserBaseUri);
      if (inferredWebUrl != null) {
        return inferredWebUrl;
      }
      return 'http://127.0.0.1:8000';
    }

    if (targetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }

    return 'http://127.0.0.1:8000';
  }

  static String? _inferWebServerUrl(Uri? browserBaseUri) {
    if (browserBaseUri == null) {
      return null;
    }

    final scheme = browserBaseUri.scheme.toLowerCase();
    final host = browserBaseUri.host.trim();
    if (host.isEmpty || (scheme != 'http' && scheme != 'https')) {
      return null;
    }

    final originPort = browserBaseUri.hasPort
        ? browserBaseUri.port
        : scheme == 'https'
        ? 443
        : 80;
    if (originPort == 8000) {
      return '$scheme://$host:8000';
    }

    if (scheme == 'https') {
      return '$scheme://$host';
    }

    return '$scheme://$host:8000';
  }

  static Uri? get serverUri => Uri.tryParse(serverURL);

  static bool get hasExplicitServerUrl => _serverUrlOverride.trim().isNotEmpty;

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

  static String connectionHelpText({String? action}) {
    final prefix = action == null || action.trim().isEmpty
        ? 'Không thể kết nối tới server $serverURL.'
        : 'Không thể $action vì app không kết nối được tới server $serverURL.';

    if (hasExplicitServerUrl) {
      return '$prefix Kiểm tra backend đã chạy và thiết bị có truy cập được địa chỉ này.';
    }

    if (kIsWeb) {
      return '$prefix Nếu backend không chạy cùng máy, hãy truyền --dart-define=SERVER_URL=http://<SERVER_IP>:8000.';
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      return '$prefix Android emulator mặc định dùng 10.0.2.2. Nếu bạn đang chạy trên máy thật, hãy truyền --dart-define=SERVER_URL=http://<LAN_IP>:8000.';
    }

    return '$prefix Nếu bạn đang chạy trên thiết bị khác máy dev, hãy truyền --dart-define=SERVER_URL=http://<LAN_IP>:8000.';
  }
}
