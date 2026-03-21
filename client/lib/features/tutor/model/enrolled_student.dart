class EnrolledStudent {
  final String id;
  final String fullName;
  final String? avatarUrl;
  final String status; // pending | confirmed | completed | no_show
  final DateTime bookedAt;

  const EnrolledStudent({
    required this.id,
    required this.fullName,
    this.avatarUrl,
    required this.status,
    required this.bookedAt,
  });

  factory EnrolledStudent.fromMap(Map<String, dynamic> m) => EnrolledStudent(
        id: m['id'] as String,
        fullName: m['full_name'] as String,
        avatarUrl: m['avatar_url'] as String?,
        status: m['status'] as String,
        bookedAt: DateTime.parse(m['booked_at'] as String),
      );

  String get statusLabel {
    switch (status) {
      case 'confirmed':
        return 'Đã xác nhận';
      case 'completed':
        return 'Hoàn thành';
      case 'no_show':
        return 'Vắng mặt';
      default:
        return 'Chờ xác nhận';
    }
  }
}
