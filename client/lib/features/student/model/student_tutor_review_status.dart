import 'package:client/features/student/model/student_tutor_review.dart';

class StudentTutorReviewStatus {
  final String classId;
  final bool canReview;
  final bool alreadyReviewed;
  final String hotline;
  final String? reason;
  final StudentTutorReview? review;

  const StudentTutorReviewStatus({
    required this.classId,
    required this.canReview,
    required this.alreadyReviewed,
    required this.hotline,
    this.reason,
    this.review,
  });

  factory StudentTutorReviewStatus.fromMap(Map<String, dynamic> map) {
    return StudentTutorReviewStatus(
      classId: map['class_id'] as String? ?? '',
      canReview: map['can_review'] as bool? ?? false,
      alreadyReviewed: map['already_reviewed'] as bool? ?? false,
      hotline: map['hotline'] as String? ?? '',
      reason: map['reason'] as String?,
      review: map['review'] is Map<String, dynamic>
          ? StudentTutorReview.fromMap(map['review'] as Map<String, dynamic>)
          : null,
    );
  }
}
