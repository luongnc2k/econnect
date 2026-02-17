/// App theme definitions for consistent styling across the application. This file defines the various theme properties used in the app's UI, ensuring a unified and accessible design system. It is part of the core theme layer and is used by the presentation layer to apply consistent styling to UI elements.
library;

import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_spacing.dart';

class AppTheme {
  AppTheme._();

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
      background: AppColors.background,
      surface: AppColors.surface,
    );

    final BorderRadius borderRadius = BorderRadius.circular(AppSpacing.radius);

    final OutlineInputBorder outlineBorder = OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: const BorderSide(color: AppColors.border),
    );

    final OutlineInputBorder focusedOutlineBorder = OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,

      appBarTheme: const AppBarTheme(
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        border: outlineBorder,
        enabledBorder: outlineBorder,
        focusedBorder: focusedOutlineBorder,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: borderRadius,
          ),
        ),
      ),

      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: borderRadius,
          side: const BorderSide(color: AppColors.border),
        ),
      ),
    );
  }
}
