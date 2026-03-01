import 'package:client/app/app_router.dart';
import 'package:client/core/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


void main() {
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkThemeMode,
      darkTheme: AppTheme.darkThemeMode,
      themeMode: ThemeMode.dark,
    );
  }
}