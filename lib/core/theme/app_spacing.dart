/// App spacing definitions for consistent layout and padding across the application. This file defines the various spacing values used in the app's UI, ensuring a unified and accessible design system. It is part of the core theme layer and is used by the presentation layer to apply consistent spacing to UI elements.
library;

class AppSpacing {
  AppSpacing._();

  static const double xs = 4; // Extra small spacing, typically used for tight layouts or small gaps between elements.
  static const double sm = 8; // Small spacing, commonly used for standard padding around UI elements or between components.
  static const double md = 12; // Medium spacing, often used for larger gaps between sections or to create more breathing room in the layout.
  static const double lg = 16; // Large spacing, suitable for significant separation between major sections or to create a more open and airy design.
  static const double xl = 24; // Extra large spacing, ideal for very spacious layouts or to emphasize separation between distinct areas of the UI.

  static const double radius = 12; // Standard border radius for rounded corners on UI elements, providing a consistent look and feel across the app.
}
