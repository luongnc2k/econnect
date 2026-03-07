class ClassSession {
  final String title;
  final String location;
  final String teacherName;
  final String timeText;
  final String priceText;
  final String? imageUrl;
  final String statusText;
  final String? countdownText;
  final List<String> tags;

  // Detail screen fields
  final String? description;
  final String? dateText;
  final String? slotText;
  final String? levelText;
  final double? teacherRating;
  final int? teacherSessionCount;
  final List<String> enrolledInitials;
  final int? extraEnrolled;

  const ClassSession({
    required this.title,
    required this.location,
    required this.teacherName,
    required this.timeText,
    required this.priceText,
    this.imageUrl,
    this.statusText = 'OPEN',
    this.countdownText,
    this.tags = const [],
    this.description,
    this.dateText,
    this.slotText,
    this.levelText,
    this.teacherRating,
    this.teacherSessionCount,
    this.enrolledInitials = const [],
    this.extraEnrolled,
  });
}
