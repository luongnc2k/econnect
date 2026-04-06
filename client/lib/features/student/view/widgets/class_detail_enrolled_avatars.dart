import 'package:flutter/material.dart';
import 'package:client/features/student/model/enrolled_student_preview.dart';

const _avatarColors = [
  Color(0xFF7950F2),
  Color(0xFF20C997),
  Color(0xFF339AF0),
  Color(0xFFF76707),
  Color(0xFFE64980),
];

class ClassDetailEnrolledAvatars extends StatelessWidget {
  final List<EnrolledStudentPreview> students;
  final List<String> initials;
  final int extra;
  final ValueChanged<EnrolledStudentPreview>? onAvatarTap;

  const ClassDetailEnrolledAvatars({
    super.key,
    this.students = const [],
    required this.initials,
    this.extra = 0,
    this.onAvatarTap,
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
            final student = i < students.length ? students[i] : null;
            return Positioned(
              left: i * (size - overlap),
              child: _AvatarCircle(
                label: initials[i],
                color: color,
                size: size,
                onTap: student == null || onAvatarTap == null
                    ? null
                    : () => onAvatarTap!(student),
              ),
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
  final VoidCallback? onTap;

  const _AvatarCircle({
    required this.label,
    required this.color,
    this.textColor,
    this.borderColor,
    required this.size,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
      ),
    );
  }
}
