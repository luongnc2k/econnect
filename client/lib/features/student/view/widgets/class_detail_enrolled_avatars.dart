import 'package:flutter/material.dart';

const _avatarColors = [
  Color(0xFF7950F2),
  Color(0xFF20C997),
  Color(0xFF339AF0),
  Color(0xFFF76707),
  Color(0xFFE64980),
];

class ClassDetailEnrolledAvatars extends StatelessWidget {
  final List<String> initials;
  final int extra;

  const ClassDetailEnrolledAvatars({
    super.key,
    required this.initials,
    this.extra = 0,
  });

  @override
  Widget build(BuildContext context) {
    const double size = 38;
    const double overlap = 14;
    final total = initials.length + (extra > 0 ? 1 : 0);
    final width = size + (total - 1) * (size - overlap);

    return SizedBox(
      height: size,
      width: width,
      child: Stack(
        children: [
          ...List.generate(initials.length, (i) {
            final color = _avatarColors[i % _avatarColors.length];
            return Positioned(
              left: i * (size - overlap),
              child: _AvatarCircle(label: initials[i], color: color, size: size),
            );
          }),
          if (extra > 0)
            Positioned(
              left: initials.length * (size - overlap),
              child: _AvatarCircle(
                label: '+$extra',
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                textColor: Theme.of(context).colorScheme.onSurface,
                borderColor: Theme.of(context).colorScheme.outline,
                size: size,
              ),
            ),
        ],
      ),
    );
  }
}

class _AvatarCircle extends StatelessWidget {
  final String label;
  final Color color;
  final Color? textColor;
  final Color? borderColor;
  final double size;

  const _AvatarCircle({
    required this.label,
    required this.color,
    this.textColor,
    this.borderColor,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: borderColor ?? Theme.of(context).scaffoldBackgroundColor,
          width: 2,
        ),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            fontSize: label.startsWith('+') ? 11 : 13,
            fontWeight: FontWeight.w700,
            color: textColor ?? Colors.white,
          ),
        ),
      ),
    );
  }
}
