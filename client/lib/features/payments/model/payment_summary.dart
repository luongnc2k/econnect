class PaymentSummary {
  final String classId;
  final String classStatus;
  final String creationPaymentStatus;
  final int creationFeeAmount;
  final int minParticipants;
  final int maxParticipants;
  final int currentParticipants;
  final bool minimumParticipantsReached;
  final String tutorConfirmationStatus;
  final DateTime? tutorConfirmedAt;
  final String tutorPayoutStatus;
  final int tutorPayoutAmount;
  final int totalEscrowHeld;
  final int activeDisputes;

  const PaymentSummary({
    required this.classId,
    required this.classStatus,
    required this.creationPaymentStatus,
    required this.creationFeeAmount,
    required this.minParticipants,
    required this.maxParticipants,
    required this.currentParticipants,
    required this.minimumParticipantsReached,
    required this.tutorConfirmationStatus,
    this.tutorConfirmedAt,
    required this.tutorPayoutStatus,
    required this.tutorPayoutAmount,
    required this.totalEscrowHeld,
    required this.activeDisputes,
  });

  factory PaymentSummary.fromMap(Map<String, dynamic> map) {
    return PaymentSummary(
      classId: map['class_id'] as String? ?? '',
      classStatus: map['class_status'] as String? ?? '',
      creationPaymentStatus: map['creation_payment_status'] as String? ?? '',
      creationFeeAmount: _toInt(map['creation_fee_amount']),
      minParticipants: (map['min_participants'] as num?)?.toInt() ?? 0,
      maxParticipants: (map['max_participants'] as num?)?.toInt() ?? 0,
      currentParticipants: (map['current_participants'] as num?)?.toInt() ?? 0,
      minimumParticipantsReached:
          map['minimum_participants_reached'] as bool? ?? false,
      tutorConfirmationStatus:
          map['tutor_confirmation_status'] as String? ?? '',
      tutorConfirmedAt: map['tutor_confirmed_at'] != null
          ? DateTime.tryParse(map['tutor_confirmed_at'].toString())
          : null,
      tutorPayoutStatus: map['tutor_payout_status'] as String? ?? '',
      tutorPayoutAmount: _toInt(map['tutor_payout_amount']),
      totalEscrowHeld: _toInt(map['total_escrow_held']),
      activeDisputes: (map['active_disputes'] as num?)?.toInt() ?? 0,
    );
  }

  String get creationPaymentStatusLabel {
    switch (creationPaymentStatus) {
      case 'unpaid':
        return 'Chưa thanh toán';
      case 'pending':
        return 'Đang chờ thanh toán';
      case 'paid':
        return 'Đã thanh toán';
      case 'refund_processing':
        return 'Hoàn phí đang được xử lý';
      case 'refund_failed':
        return 'Hoàn phí thất bại';
      case 'refunded':
        return 'Đã ghi nhận hoàn phí';
      default:
        return creationPaymentStatus;
    }
  }
}

int _toInt(dynamic value) {
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value) ?? double.tryParse(value)?.toInt() ?? 0;
  }
  return 0;
}
