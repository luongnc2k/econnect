import 'package:flutter/material.dart';

void showSnackBar(BuildContext context, String content) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(content)));
}

/// Horizontal padding that scales with screen width:
/// mobile (<480) → 16, large phone (480-768) → 24, tablet (≥768) → 8% width
double responsiveHPad(BuildContext context) {
  final w = MediaQuery.of(context).size.width;
  if (w >= 768) return w * 0.08;
  if (w >= 480) return 24;
  return 16;
}