import 'dart:async';

import 'package:client/core/providers/current_user_notifier.dart';
import 'package:client/core/router/app_router.dart';
import 'package:client/features/auth/model/user_model.dart';
import 'package:client/features/notifications/push/notifications_fcm_options.dart';
import 'package:client/features/notifications/repositories/notifications_remote_repository.dart';
import 'package:client/features/notifications/viewmodel/notifications_controller.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:fpdart/fpdart.dart' show Left, Right;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@pragma('vm:entry-point')
Future<void> notificationsFirebaseMessagingBackgroundHandler(RemoteMessage message) async {
  final options = NotificationsFcmOptions.currentPlatform;
  if (options == null || !NotificationsFcmOptions.supportsPushRuntime) {
    return;
  }

  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: options);
    }
  } catch (_) {
    // Bỏ qua lỗi background bootstrap để không làm crash isolate nền.
  }
}

class NotificationsPushService {
  NotificationsPushService(this._container);

  final ProviderContainer _container;

  ProviderSubscription<UserModel?>? _userSubscription;
  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;
  StreamSubscription<RemoteMessage>? _messageOpenedSubscription;

  RemoteMessage? _pendingInitialMessage;
  String? _deviceToken;
  String? _lastRegisteredUserId;
  String? _lastRegisteredAuthToken;
  String? _lastRegisteredPushToken;
  bool _bootstrapped = false;
  bool _enabled = false;

  Future<void> bootstrap() async {
    if (_bootstrapped) {
      return;
    }
    _bootstrapped = true;

    final options = NotificationsFcmOptions.currentPlatform;
    if (options == null || !NotificationsFcmOptions.supportsPushRuntime) {
      return;
    }

    try {
      FirebaseMessaging.onBackgroundMessage(notificationsFirebaseMessagingBackgroundHandler);
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: options);
      }
      _enabled = true;
    } catch (error) {
      debugPrint('Khởi tạo FCM thất bại: $error');
      return;
    }

    try {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
    } catch (error) {
      debugPrint('Không thể yêu cầu quyền thông báo: $error');
    }

    try {
      _deviceToken = await FirebaseMessaging.instance.getToken();
    } catch (error) {
      debugPrint('Không lấy được FCM token: $error');
    }

    _tokenRefreshSubscription = FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      _deviceToken = token;
      unawaited(_syncCurrentUserToken(force: true));
    });

    _foregroundMessageSubscription = FirebaseMessaging.onMessage.listen((message) {
      unawaited(_handleIncomingMessage(message, openedFromSystemTray: false));
    });

    _messageOpenedSubscription = FirebaseMessaging.onMessageOpenedApp.listen((message) {
      unawaited(_handleIncomingMessage(message, openedFromSystemTray: true));
    });

    _pendingInitialMessage = await FirebaseMessaging.instance.getInitialMessage();

    _userSubscription = _container.listen<UserModel?>(
      currentUserProvider,
      (previous, next) {
        unawaited(_handleUserChanged(previous, next));
      },
      fireImmediately: true,
    );
  }

  Future<void> onAppReady() async {
    final message = _pendingInitialMessage;
    _pendingInitialMessage = null;
    if (message == null) {
      return;
    }
    await _handleIncomingMessage(message, openedFromSystemTray: true);
  }

  Future<void> dispose() async {
    _userSubscription?.close();
    await _tokenRefreshSubscription?.cancel();
    await _foregroundMessageSubscription?.cancel();
    await _messageOpenedSubscription?.cancel();
  }

  Future<void> _handleUserChanged(UserModel? previous, UserModel? next) async {
    if (!_enabled) {
      return;
    }

    final previousAuthToken = previous?.token;
    final currentPushToken = await _ensureDeviceToken();

    if (previous != null &&
        currentPushToken != null &&
        (next == null || next.id != previous.id || next.token != previous.token)) {
      await _unregisterPushToken(
        authToken: previousAuthToken,
        pushToken: currentPushToken,
      );
      _lastRegisteredUserId = null;
      _lastRegisteredAuthToken = null;
      _lastRegisteredPushToken = null;
    }

    if (next != null) {
      await _registerPushToken(next, force: previous?.token != next.token);
    }
  }

  Future<void> _handleIncomingMessage(
    RemoteMessage message, {
    required bool openedFromSystemTray,
  }) async {
    if (_container.read(currentUserProvider) == null) {
      return;
    }

    try {
      await _container.read(notificationsControllerProvider.notifier).refresh(silent: true);
    } catch (error) {
      debugPrint('Không thể làm mới inbox sau khi nhận push: $error');
    }

    if (!openedFromSystemTray) {
      return;
    }

    final router = _container.read(appRouterProvider);
    final currentUser = _container.read(currentUserProvider);
    final classCode = message.data['class_code']?.toString();

    if (currentUser?.role == 'teacher' && classCode != null && classCode.isNotEmpty) {
      router.go('/teacher/class-summary/$classCode');
      return;
    }

    router.go(AppRoutes.notifications);
  }

  Future<void> _syncCurrentUserToken({bool force = false}) async {
    final user = _container.read(currentUserProvider);
    if (user == null) {
      return;
    }
    await _registerPushToken(user, force: force);
  }

  Future<void> _registerPushToken(UserModel user, {bool force = false}) async {
    final pushToken = await _ensureDeviceToken();
    if (pushToken == null || pushToken.isEmpty) {
      return;
    }

    if (!force &&
        _lastRegisteredUserId == user.id &&
        _lastRegisteredAuthToken == user.token &&
        _lastRegisteredPushToken == pushToken) {
      return;
    }

    final repository = _container.read(notificationsRemoteRepositoryProvider);
    final result = await repository.registerPushToken(
      token: user.token,
      pushToken: pushToken,
      platform: _platformName,
      deviceLabel: _deviceLabel,
    );

    switch (result) {
      case Left(value: final failure):
        debugPrint('Đăng ký FCM token thất bại: ${failure.message}');
      case Right():
        _lastRegisteredUserId = user.id;
        _lastRegisteredAuthToken = user.token;
        _lastRegisteredPushToken = pushToken;
    }
  }

  Future<void> _unregisterPushToken({
    required String? authToken,
    required String pushToken,
  }) async {
    if (authToken == null || authToken.isEmpty) {
      return;
    }

    final repository = _container.read(notificationsRemoteRepositoryProvider);
    final result = await repository.unregisterPushToken(
      token: authToken,
      pushToken: pushToken,
    );

    if (result case Left(value: final failure)) {
      debugPrint('Hủy đăng ký FCM token thất bại: ${failure.message}');
    }
  }

  Future<String?> _ensureDeviceToken() async {
    if (_deviceToken != null && _deviceToken!.isNotEmpty) {
      return _deviceToken;
    }

    if (!_enabled) {
      return null;
    }

    try {
      _deviceToken = await FirebaseMessaging.instance.getToken();
    } catch (error) {
      debugPrint('Không thể lấy FCM token hiện tại: $error');
    }
    return _deviceToken;
  }

  String get _platformName {
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      TargetPlatform.macOS => 'macos',
      TargetPlatform.windows => 'windows',
      TargetPlatform.linux => 'linux',
      TargetPlatform.fuchsia => 'fuchsia',
    };
  }

  String get _deviceLabel {
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'Android',
      TargetPlatform.iOS => 'iPhone/iPad',
      TargetPlatform.macOS => 'macOS',
      TargetPlatform.windows => 'Windows',
      TargetPlatform.linux => 'Linux',
      TargetPlatform.fuchsia => 'Fuchsia',
    };
  }
}
