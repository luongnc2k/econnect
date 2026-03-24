import 'dart:async';

import 'package:client/core/constants/server_constant.dart';
import 'package:client/core/providers/theme_notifier.dart';
import 'package:client/core/router/app_router.dart';
import 'package:client/core/theme/theme.dart';
import 'package:client/features/auth/model/user_model.dart';
import 'package:client/features/auth/viewmodel/auth_viewmodel.dart';
import 'package:client/features/notifications/push/notifications_push_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

NotificationsPushService? _notificationsPushService;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final bootstrapError = _releaseConfigurationError();
  if (bootstrapError != null) {
    runApp(_BootstrapErrorApp(message: bootstrapError));
    return;
  }
  final container = ProviderContainer();

  // Giữ authViewModelProvider sống trong suốt quá trình init async.
  // Không có listener thì provider có thể auto-dispose giữa chừng.
  final sub = container.listen<AsyncValue<UserModel>?>(
    authViewModelProvider,
    (prev, next) {},
  );

  await container.read(authViewModelProvider.notifier).initSharedPreferences();
  await container.read(authViewModelProvider.notifier).getData();

  sub.close();
  _notificationsPushService = NotificationsPushService(container);
  await _notificationsPushService?.bootstrap();

  runApp(UncontrolledProviderScope(container: container, child: MyApp()));
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(_notificationsPushService?.onAppReady());
  });
}

String? _releaseConfigurationError() {
  if (!kReleaseMode) {
    return null;
  }
  if (!ServerConstant.isReleaseReady) {
    return 'Bản build release đang dùng SERVER_URL không an toàn. '
        'Hãy đặt --dart-define=SERVER_URL=https://api.your-domain.com trước khi phát hành.';
  }
  return null;
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'econnect',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightThemeMode,
      darkTheme: AppTheme.darkThemeMode,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}

class _BootstrapErrorApp extends StatelessWidget {
  final String message;

  const _BootstrapErrorApp({required this.message});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(message, textAlign: TextAlign.center),
          ),
        ),
      ),
    );
  }
}
