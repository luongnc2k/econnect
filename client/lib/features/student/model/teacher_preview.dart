class TeacherPreview {
  final String id;
  final String name;
  final String subtitle;
  final double rating;
  final int reviewCount;
  final List<String> specialties;
  final String? avatarUrl;
  final String? badgeText;

  const TeacherPreview({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.rating,
    required this.reviewCount,
    required this.specialties,
    this.avatarUrl,
    this.badgeText,
  });
}
