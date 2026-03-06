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
  });
}
