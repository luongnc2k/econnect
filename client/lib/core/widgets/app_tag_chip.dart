import 'package:flutter/material.dart';

/// Chip hiển thị tag/label. Dùng chung cho ClassCard và ClassDetail.
class AppTagChip extends StatelessWidget {
  final String label;
  final double fontSize;
  final EdgeInsetsGeometry padding;

  const AppTagChip({
    super.key,
    required this.label,
    this.fontSize = 11,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: fontSize,
          color: cs.onSurface,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
