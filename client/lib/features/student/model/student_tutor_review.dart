class StudentTutorReview {
  final String id;
  final String classId;
  final String bookingId;
  final String teacherId;
  final String studentId;
  final int rating;
  final String? comment;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const StudentTutorReview({
    required this.id,
    required this.classId,
    required this.bookingId,
    required this.teacherId,
    required this.studentId,
    required this.rating,
    this.comment,
    this.createdAt,
    this.updatedAt,
  });

  factory StudentTutorReview.fromMap(Map<String, dynamic> map) {
    return StudentTutorReview(
      id: map['id'] as String? ?? '',
      classId: map['class_id'] as String? ?? '',
      bookingId: map['booking_id'] as String? ?? '',
      teacherId: map['teacher_id'] as String? ?? '',
      studentId: map['student_id'] as String? ?? '',
      rating: (map['rating'] as num?)?.toInt() ?? 0,
      comment: map['comment'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'].toString())
          : null,
    );
  }
}
