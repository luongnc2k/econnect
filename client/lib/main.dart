import 'package:client/core/providers/theme_notifier.dart';
import 'package:client/core/router/app_router.dart';
import 'package:client/core/theme/theme.dart';
import 'package:client/features/auth/model/user_model.dart';
import 'package:client/features/auth/viewmodel/auth_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final container = ProviderContainer();

  // Giữ authViewModelProvider sống trong suốt quá trình init async
  // Không có listener → provider bị auto-dispose giữa chừng → !ref.mounted = true
  final sub = container.listen<AsyncValue<UserModel>?>(
    authViewModelProvider,
    (prev, next) {},
  );

  await container.read(authViewModelProvider.notifier).initSharedPreferences();
  await container.read(authViewModelProvider.notifier).getData();

  sub.close();

  runApp(UncontrolledProviderScope(container: container, child: MyApp()));
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