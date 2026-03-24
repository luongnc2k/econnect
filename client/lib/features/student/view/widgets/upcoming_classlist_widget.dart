import 'package:client/features/student/model/class_session.dart';
import 'package:client/features/student/view/widgets/class_card_widget.dart';
import 'package:flutter/material.dart';

class UpcomingClassListWidget extends StatelessWidget {
  final List<ClassSession> classes;
  final ValueChanged<ClassSession>? onClassTap;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final EdgeInsetsGeometry padding;

  const UpcomingClassListWidget({
    super.key,
    required this.classes,
    this.onClassTap,
    this.shrinkWrap = false,
    this.physics,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: padding,
      shrinkWrap: shrinkWrap,
      physics: physics,
      itemCount: classes.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
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
    );
  }
}
