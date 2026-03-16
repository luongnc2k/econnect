class PaymentSummary {
  final String classId;
  final String classStatus;
  final String creationPaymentStatus;
  final int creationFeeAmount;
  final int currentParticipants;
  final String tutorPayoutStatus;
  final int tutorPayoutAmount;
  final int totalEscrowHeld;
  final int activeDisputes;

  const PaymentSummary({
    required this.classId,
    required this.classStatus,
    required this.creationPaymentStatus,
    required this.creationFeeAmount,
    required this.currentParticipants,
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
      currentParticipants: (map['current_participants'] as num?)?.toInt() ?? 0,
      tutorPayoutStatus: map['tutor_payout_status'] as String? ?? '',
      tutorPayoutAmount: _toInt(map['tutor_payout_amount']),
      totalEscrowHeld: _toInt(map['total_escrow_held']),
      activeDisputes: (map['active_disputes'] as num?)?.toInt() ?? 0,
    );
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
