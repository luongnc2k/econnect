class AppNotification {
  final String id;
  final String type;
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final bool isRead;
  final DateTime? createdAt;
  final DateTime? readAt;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.data,
    required this.isRead,
    this.createdAt,
    this.readAt,
  });

  String? get classId => data['class_id']?.toString();
  String? get classCode => data['class_code']?.toString();
  DateTime? get classStartTime =>
      data['start_time'] != null ? DateTime.tryParse(data['start_time'].toString()) : null;
  String? get payoutStatus => data['payout_status']?.toString();
  String? get refundAmount => data['refund_amount']?.toString();
  String? get cancellationReason => data['cancellation_reason']?.toString();
  bool get isUnread => !isRead;
  bool get isClassRelated => classId != null && classId!.isNotEmpty;

  String get typeLabel {
    switch (type) {
      case 'minimum_participants_reached':
        return 'Đủ tối thiểu';
      case 'tutor_confirmed_teaching':
        return 'Tutor xác nhận';
      case 'class_starting_soon':
        return 'Sắp diễn ra';
      case 'class_cancelled':
        return 'Lớp bị hủy';
      case 'refund_issued':
        return 'Hoàn tiền';
      case 'payout_updated':
        return 'Payout';
      case 'dispute_resolved':
        return 'Khiếu nại';
      default:
        return type;
    }
  }

  bool get canConfirmTeaching =>
      type == 'minimum_participants_reached' && classId != null && classId!.isNotEmpty;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'title': title,
      'body': body,
      'data': data,
      'is_read': isRead,
      'created_at': createdAt?.toIso8601String(),
      'read_at': readAt?.toIso8601String(),
    };
  }

  factory AppNotification.fromMap(Map<String, dynamic> map) {
    return AppNotification(
      id: map['id']?.toString() ?? '',
      type: map['type']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      body: map['body']?.toString() ?? '',
      data: map['data'] is Map ? Map<String, dynamic>.from(map['data'] as Map) : const {},
      isRead: map['is_read'] as bool? ?? false,
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) : null,
      readAt: map['read_at'] != null ? DateTime.tryParse(map['read_at'].toString()) : null,
    );
  }

  AppNotification copyWith({
    Map<String, dynamic>? data,
    bool? isRead,
    DateTime? readAt,
  }) {
    return AppNotification(
      id: id,
      type: type,
      title: title,
      body: body,
      data: data ?? this.data,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
      readAt: readAt ?? this.readAt,
    );
  }
}
