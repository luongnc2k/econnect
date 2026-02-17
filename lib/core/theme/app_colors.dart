/// App color definitions for consistent theming across the application. This file defines the various color values used in the app's UI, ensuring a unified and accessible design system. It is part of the core theme layer and is used by the presentation layer to apply consistent styling to UI elements.
/// This file includes primary and secondary colors, background colors, text colors, and any other color definitions needed for the app's design. By centralizing color definitions in this file, it allows for easy maintenance and updates to the app's color scheme.
/// The colors defined in this file should be chosen to provide good contrast and accessibility for all users, and should align with the overall design language of the application.
library;

import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Brand
  static const Color primary = Color(0xFF2563EB); // xanh
  static const Color secondary = Color(0xFF22C55E); // xanh lá

  // Neutral
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Colors.white;
  static const Color text = Color(0xFF0F172A);
  static const Color mutedText = Color(0xFF64748B);

  // Status
  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFDC2626);

  // Border
  static const Color border = Color(0xFFE2E8F0);
}
