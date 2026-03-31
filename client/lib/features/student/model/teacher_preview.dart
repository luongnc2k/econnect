class TeacherPreview {
  final String id;
  final String name;
  final String subtitle;
  final double rating;
  final int reviewCount;
  final int sessionCount;
  final List<String> specialties;
  final String? avatarUrl;
  final String? badgeText;

  const TeacherPreview({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.rating,
    required this.reviewCount,
    required this.sessionCount,
    required this.specialties,
    this.avatarUrl,
    this.badgeText,
  });

  factory TeacherPreview.fromFeaturedTeacherMap(
    Map<String, dynamic> map, {
    String? badgeText,
  }) {
    final specialization = (map['specialization'] as String? ?? '').trim();
    return TeacherPreview(
      id: map['id'] as String? ?? '',
      name: map['full_name'] as String? ?? '',
      subtitle: specialization.isNotEmpty
          ? specialization
          : 'Giảng viên nổi bật trên EConnect',
      rating: _toDouble(map['rating']),
      reviewCount: _toInt(map['total_reviews']),
      sessionCount: _toInt(map['total_sessions']),
      specialties: specialization.isNotEmpty ? [specialization] : const [],
      avatarUrl: map['avatar_url'] as String?,
      badgeText: badgeText,
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _toDouble(dynamic value) {
    if (value is double) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
