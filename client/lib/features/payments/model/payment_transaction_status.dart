class PaymentTransactionStatus {
  final String paymentId;
  final String transactionRef;
  final String paymentType;
  final String provider;
  final String status;
  final int amount;
  final String? redirectUrl;
  final String? bookingId;
  final String? classId;
  final String? bookingStatus;
  final String? escrowStatus;
  final String? classStatus;
  final String? message;
  final DateTime? paidAt;

  const PaymentTransactionStatus({
    required this.paymentId,
    required this.transactionRef,
    required this.paymentType,
    required this.provider,
    required this.status,
    required this.amount,
    this.redirectUrl,
    this.bookingId,
    this.classId,
    this.bookingStatus,
    this.escrowStatus,
    this.classStatus,
    this.message,
    this.paidAt,
  });

  bool get isTerminal => {'paid', 'released', 'refunded', 'failed'}.contains(status);
  bool get isSuccessLike => {'paid', 'released'}.contains(status);

  factory PaymentTransactionStatus.fromMap(Map<String, dynamic> map) {
    return PaymentTransactionStatus(
      paymentId: map['payment_id'] as String? ?? '',
      transactionRef: map['transaction_ref'] as String? ?? '',
      paymentType: map['payment_type'] as String? ?? '',
      provider: map['provider'] as String? ?? '',
      status: map['status'] as String? ?? '',
      amount: _toInt(map['amount']),
      redirectUrl: map['redirect_url'] as String?,
      bookingId: map['booking_id'] as String?,
      classId: map['class_id'] as String?,
      bookingStatus: map['booking_status'] as String?,
      escrowStatus: map['escrow_status'] as String?,
      classStatus: map['class_status'] as String?,
      message: map['message'] as String?,
      paidAt: map['paid_at'] != null ? DateTime.tryParse(map['paid_at'].toString()) : null,
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
