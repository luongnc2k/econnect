class AppNotification {
  static final RegExp _legacyUnderfilledReasonPattern = RegExp(
    r'Khong du hoc vien toi thieu truoc ([0-9]+(?:\.[0-9]+)?) gio',
  );

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
  DateTime? get classStartTime => data['start_time'] != null
      ? DateTime.tryParse(data['start_time'].toString())
      : null;
  String? get payoutStatus => data['payout_status']?.toString();
  String? get refundAmount => data['refund_amount']?.toString();
  String? get refundScope => data['refund_scope']?.toString();
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
        return refundScope == 'class_creation_fee'
            ? 'Hoàn phí tạo lớp'
            : 'Hoàn tiền';
      case 'payout_updated':
        return 'Payout';
      case 'dispute_resolved':
        return 'Khiếu nại';
      default:
        return type;
    }
  }

  bool get canConfirmTeaching =>
      type == 'minimum_participants_reached' &&
      classId != null &&
      classId!.isNotEmpty;

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
    final rawData = map['data'] is Map
        ? Map<String, dynamic>.from(map['data'] as Map)
        : <String, dynamic>{};
    final normalizedData = _normalizeData(rawData);

    return AppNotification(
      id: map['id']?.toString() ?? '',
      type: map['type']?.toString() ?? '',
      title: _normalizeText(
        map['title']?.toString() ?? '',
        type: map['type']?.toString() ?? '',
        data: normalizedData,
        isTitle: true,
      ),
      body: _normalizeText(
        map['body']?.toString() ?? '',
        type: map['type']?.toString() ?? '',
        data: normalizedData,
        isTitle: false,
      ),
      data: normalizedData,
      isRead: map['is_read'] as bool? ?? false,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
      readAt: map['read_at'] != null
          ? DateTime.tryParse(map['read_at'].toString())
          : null,
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

  static Map<String, dynamic> _normalizeData(Map<String, dynamic> data) {
    if (data.isEmpty) {
      return const {};
    }

    final normalized = Map<String, dynamic>.from(data);
    for (final key in const [
      'cancellation_reason',
      'refund_reason',
      'message',
    ]) {
      final value = normalized[key];
      if (value is String) {
        normalized[key] = _normalizeKnownPhrase(value);
      }
    }
    return normalized;
  }

  static String _normalizeText(
    String raw, {
    required String type,
    required Map<String, dynamic> data,
    required bool isTitle,
  }) {
    if (type == 'refund_issued' &&
        data['refund_scope']?.toString() == 'class_creation_fee' &&
        data['refund_status']?.toString() == 'legacy_recorded') {
      if (isTitle) {
        return 'Đã ghi nhận hoàn phí tạo lớp';
      }

      final classTitle = data['class_title']?.toString().trim() ?? '';
      final classSegment = classTitle.isEmpty ? '' : " cho lớp '$classTitle'";
      return 'Hệ thống đã ghi nhận khoản hoàn phí tạo lớp '
          '${_formatVndAmount(data['refund_amount'])}$classSegment. '
          'Khoản này chưa đồng nghĩa tiền đã về tài khoản ngân hàng của tutor.';
    }

    return _normalizeKnownPhrase(raw);
  }

  static String _normalizeKnownPhrase(String raw) {
    var normalized = raw.trim();
    if (normalized.isEmpty) {
      return normalized;
    }

    normalized = normalized.replaceAllMapped(
      _legacyUnderfilledReasonPattern,
      (match) => 'Không đủ học viên tối thiểu trước ${match.group(1)} giờ',
    );

    const replacements = {
      'Tutor chua cap nhat day du thong tin payout payOS: bank_bin':
          'Tutor chưa cập nhật đầy đủ thông tin payout payOS: bank_bin',
      'Tutor chu dong huy lop': 'Tutor chủ động hủy lớp',
      'Lop hoc bi huy': 'Lớp học bị hủy',
    };

    replacements.forEach((legacy, clean) {
      normalized = normalized.replaceAll(legacy, clean);
    });

    return normalized;
  }

  static String _formatVndAmount(dynamic rawAmount) {
    final digitsOnly =
        rawAmount?.toString().replaceAll(RegExp(r'[^0-9]'), '') ?? '';
    if (digitsOnly.isEmpty) {
      return '0 VND';
    }

    final amount = int.tryParse(digitsOnly);
    if (amount == null) {
      return '${rawAmount ?? 0} VND';
    }

    final buffer = StringBuffer();
    final reversed = amount.toString().split('').reversed.toList();
    for (var index = 0; index < reversed.length; index++) {
      if (index > 0 && index % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(reversed[index]);
    }

    return '${buffer.toString().split('').reversed.join()} VND';
  }
}
