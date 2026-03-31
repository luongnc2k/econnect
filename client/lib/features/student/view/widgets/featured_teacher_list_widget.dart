import 'package:client/features/student/model/teacher_preview.dart';
import 'package:client/features/student/view/widgets/teacher_card_widget.dart';
import 'package:flutter/material.dart';

class FeaturedTeacherListWidget extends StatelessWidget {
  final List<TeacherPreview> teachers;
  final ValueChanged<TeacherPreview>? onTeacherTap;
  final double spacing;

  const FeaturedTeacherListWidget({
    super.key,
    required this.teachers,
    this.onTeacherTap,
    this.spacing = 12,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: teachers.length,
      separatorBuilder: (_, _) => SizedBox(height: spacing),
      itemBuilder: (context, index) {
        final teacher = teachers[index];
        return TeacherCardWidget(
          name: teacher.name,
          subtitle: teacher.subtitle,
          rating: teacher.rating,
          reviewCount: teacher.reviewCount,
          sessionCount: teacher.sessionCount,
          specialties: teacher.specialties,
          avatarUrl: teacher.avatarUrl,
          badgeText: teacher.badgeText,
          onTap: onTeacherTap != null ? () => onTeacherTap!(teacher) : null,
        );
      },
    );
  }
}
