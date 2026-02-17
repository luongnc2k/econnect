import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/controllers/auth_controller.dart';
import 'features/auth/presentation/screens/login_screen.dart';

void main() {
  runApp(const ProviderScope(child: EConnectApp()));
}

class EConnectApp extends ConsumerStatefulWidget {
  const EConnectApp({super.key});

  @override
  ConsumerState<EConnectApp> createState() => _EConnectAppState();
}

class _EConnectAppState extends ConsumerState<EConnectApp> {
  @override
  void initState() {
    super.initState();
    // Auto check token on app start
    Future.microtask(() => ref.read(authControllerProvider.notifier).bootstrap());
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EConnect',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const LoginScreen(),
    );
  }
}
