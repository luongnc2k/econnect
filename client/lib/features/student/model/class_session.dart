import 'package:client/features/student/model/enrolled_student_preview.dart';

class ClassSession {
  final String? id;
  final String? classCode;
  final String title;
  final String location;
  final String? locationAddress;
  final String? locationNotes;
  final String? teacherId;
  final String teacherName;
  final String? teacherAvatarUrl;
  final String timeText;
  final String? endTimeText;
  final String priceText;
  final String? totalPriceText;
  final String? imageUrl;
  final String statusText;
  final String? countdownText;
  final List<String> tags;

  final DateTime? startDateTime;
  final DateTime? endDateTime;

  final String? description;
  final String? dateText;
  final String? slotText;
  final String? levelText;
  final double? teacherRating;
  final int? teacherSessionCount;
  final int? teacherReviewCount;
  final List<EnrolledStudentPreview> enrolledStudents;
  final List<String> enrolledInitials;
  final int? extraEnrolled;

  const ClassSession({
    this.id,
    this.classCode,
    required this.title,
    required this.location,
    this.locationAddress,
    this.locationNotes,
    this.teacherId,
    required this.teacherName,
    this.teacherAvatarUrl,
    required this.timeText,
    this.endTimeText,
    required this.priceText,
    this.totalPriceText,
    this.imageUrl,
    this.statusText = 'OPEN',
    this.countdownText,
    this.tags = const [],
    this.startDateTime,
    this.endDateTime,
    this.description,
    this.dateText,
    this.slotText,
    this.levelText,
    this.teacherRating,
    this.teacherSessionCount,
    this.teacherReviewCount,
    this.enrolledStudents = const [],
    this.enrolledInitials = const [],
    this.extraEnrolled,
  });

  String get displayStartTimeText {
    final separatorIndex = timeText.indexOf(' - ');
    if (separatorIndex == -1) {
      return timeText;
    }
    return timeText.substring(0, separatorIndex).trim();
  }

  String? get displayEndTimeText {
    final explicitEnd = endTimeText?.trim();
    if (explicitEnd != null && explicitEnd.isNotEmpty) {
      return explicitEnd;
    }

    final separatorIndex = timeText.indexOf(' - ');
    if (separatorIndex == -1) {
      return null;
    }

    final trailing = timeText.substring(separatorIndex + 3).trim();
    return trailing.isEmpty ? null : trailing;
  }
}
