class TutorTeachingConfirmationResult {
  final String classId;
  final String tutorConfirmationStatus;
  final bool minimumParticipantsReached;
  final DateTime? tutorConfirmedAt;
  final int notifiedStudents;
  final String message;

  const TutorTeachingConfirmationResult({
    required this.classId,
    required this.tutorConfirmationStatus,
    required this.minimumParticipantsReached,
    this.tutorConfirmedAt,
    required this.notifiedStudents,
    required this.message,
  });

  factory TutorTeachingConfirmationResult.fromMap(Map<String, dynamic> map) {
    return TutorTeachingConfirmationResult(
      classId: map['class_id']?.toString() ?? '',
      tutorConfirmationStatus: map['tutor_confirmation_status']?.toString() ?? '',
      minimumParticipantsReached: map['minimum_participants_reached'] as bool? ?? false,
      tutorConfirmedAt: map['tutor_confirmed_at'] != null
          ? DateTime.tryParse(map['tutor_confirmed_at'].toString())
          : null,
      notifiedStudents: (map['notified_students'] as num?)?.toInt() ?? 0,
      message: map['message']?.toString() ?? '',
    );
  }
}
