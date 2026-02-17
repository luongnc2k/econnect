/// App text style definitions for consistent typography across the application. This file defines the various text styles used in the app's UI, ensuring a unified and accessible design system. It is part of the core theme layer and is used by the presentation layer to apply consistent styling to text elements.
library;

import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTextStyles {
  AppTextStyles._();

  static const TextStyle h1 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: AppColors.text,
  );

  static const TextStyle h2 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: AppColors.text,
  );

  static const TextStyle body = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.text,
  );

  static const TextStyle bodyMuted = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.mutedText,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.mutedText,
  );
}
