/// Main application entry point and configuration file. This file initializes the app's core components and sets up the main application structure. It is responsible for defining the app's behavior, theme, and navigation setup.
library;

import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import 'router.dart';

// The main application widget that sets up the MaterialApp with the defined theme and router configuration. 
// This widget serves as the root of the widget tree and is responsible for rendering the app's UI based on the defined routes and themes.
class EConnectApp extends StatelessWidget {
  const EConnectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'EConnect',
      theme: AppTheme.light(),
      routerConfig: AppRouter.router,
      debugShowCheckedModeBanner: false,
    );
  }
}
