import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'app/app_entry.dart';

void main() {
  runApp(const ProviderScope(child: EConnectApp()));
}

class EConnectApp extends StatelessWidget {
  const EConnectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EConnect',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const AppEntry(),
    );
  }
}
