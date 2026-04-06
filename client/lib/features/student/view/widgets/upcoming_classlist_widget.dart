import 'package:client/features/student/model/class_session.dart';
import 'package:client/features/student/view/widgets/class_card_widget.dart';
import 'package:flutter/material.dart';

class UpcomingClassListWidget extends StatelessWidget {
  final List<ClassSession> classes;
  final ValueChanged<ClassSession>? onClassTap;

  const UpcomingClassListWidget({
    super.key,
    required this.classes,
    this.onClassTap,
  });

  @override
  Widget build(BuildContext context) {
    final h = (MediaQuery.of(context).size.height * 0.42).clamp(320.0, 460.0);
    return SizedBox(
      height: h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: classes.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final session = classes[index];
          return ClassCardWidget(
            classCode: session.classCode,
            title: session.title,
            location: session.location,
            teacherName: session.teacherName,
            timeText: session.timeText,
            priceText: session.priceText,
            imageUrl: session.imageUrl,
            statusText: session.statusText,
            countdownText: session.countdownText,
            tags: session.tags,
            onTap: onClassTap != null ? () => onClassTap!(session) : null,
          );
        },
      ),
    );
  }
}
