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
  );

  static String resolveServerUrl({
    required String environmentUrl,
    required bool isWeb,
    required TargetPlatform targetPlatform,
  }) {
    final trimmed = environmentUrl.trim();
    if (trimmed.isNotEmpty) {
      return trimmed;
    }

    if (isWeb) {
      return 'http://127.0.0.1:8000';
    }

    if (targetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }

    return 'http://127.0.0.1:8000';
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
        ? 'Khong the ket noi toi server $serverURL.'
        : 'Khong the $action vi app khong ket noi duoc toi server $serverURL.';

    if (hasExplicitServerUrl) {
      return '$prefix Kiem tra backend da chay va thiet bi co truy cap duoc dia chi nay.';
    }

    if (kIsWeb) {
      return '$prefix Neu backend khong chay cung may, hay truyen --dart-define=SERVER_URL=http://<SERVER_IP>:8000.';
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      return '$prefix Android emulator mac dinh dung 10.0.2.2. Neu ban dang chay tren may that, hay truyen --dart-define=SERVER_URL=http://<LAN_IP>:8000.';
    }

    return '$prefix Neu ban dang chay tren thiet bi khac may dev, hay truyen --dart-define=SERVER_URL=http://<LAN_IP>:8000.';
  }
}
