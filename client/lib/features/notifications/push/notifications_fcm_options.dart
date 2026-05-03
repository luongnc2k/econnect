import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class NotificationsFcmOptions {
  static const _apiKey = String.fromEnvironment('FCM_API_KEY');
  static const _projectId = String.fromEnvironment('FCM_PROJECT_ID');
  static const _messagingSenderId = String.fromEnvironment('FCM_MESSAGING_SENDER_ID');
  static const _storageBucket = String.fromEnvironment('FCM_STORAGE_BUCKET');
  static const _androidAppId = String.fromEnvironment('FCM_ANDROID_APP_ID');
  static const _iosAppId = String.fromEnvironment('FCM_IOS_APP_ID');
  static const _iosBundleId = String.fromEnvironment('FCM_IOS_BUNDLE_ID');
  static const _webAppId = String.fromEnvironment('FCM_WEB_APP_ID');
  static const _authDomain = String.fromEnvironment('FCM_WEB_AUTH_DOMAIN');
  static const _measurementId = String.fromEnvironment('FCM_WEB_MEASUREMENT_ID');

  static bool get isConfigured =>
      _apiKey.isNotEmpty &&
      _projectId.isNotEmpty &&
      _messagingSenderId.isNotEmpty &&
      (_androidAppId.isNotEmpty || _iosAppId.isNotEmpty || _webAppId.isNotEmpty);

  static bool get supportsPushRuntime {
    if (kIsWeb) {
      return false;
    }
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => true,
      TargetPlatform.iOS => true,
      _ => false,
    };
  }

  static FirebaseOptions? get currentPlatform {
    if (!isConfigured) {
      return null;
    }

    if (kIsWeb) {
      if (_webAppId.isEmpty) {
        return null;
      }
      return FirebaseOptions(
        apiKey: _apiKey,
        appId: _webAppId,
        messagingSenderId: _messagingSenderId,
        projectId: _projectId,
        authDomain: _emptyToNull(_authDomain),
        storageBucket: _emptyToNull(_storageBucket),
        measurementId: _emptyToNull(_measurementId),
      );
    }

    return switch (defaultTargetPlatform) {
      TargetPlatform.android => _buildAndroidOptions(),
      TargetPlatform.iOS => _buildIosOptions(),
      _ => null,
    };
  }

  static FirebaseOptions? _buildAndroidOptions() {
    if (_androidAppId.isEmpty) {
      return null;
    }
    return FirebaseOptions(
      apiKey: _apiKey,
      appId: _androidAppId,
      messagingSenderId: _messagingSenderId,
      projectId: _projectId,
      storageBucket: _emptyToNull(_storageBucket),
    );
  }

  static FirebaseOptions? _buildIosOptions() {
    if (_iosAppId.isEmpty) {
      return null;
    }
    return FirebaseOptions(
      apiKey: _apiKey,
      appId: _iosAppId,
      messagingSenderId: _messagingSenderId,
      projectId: _projectId,
      storageBucket: _emptyToNull(_storageBucket),
      iosBundleId: _emptyToNull(_iosBundleId),
    );
  }

  static String? _emptyToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
