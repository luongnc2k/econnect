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
    this.enrolledStudents = const [],
    this.enrolledInitials = const [],
    this.extraEnrolled,
  });
}
