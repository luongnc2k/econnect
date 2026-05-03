class StudentClassBookingStatus {
  final String classId;
  final bool hasBooking;
  final bool isRegistered;
  final String? bookingId;
  final String? bookingStatus;
  final String? paymentStatus;
  final String? escrowStatus;
  final String? paymentReference;
  final int? tuitionAmount;
  final DateTime? bookedAt;

  const StudentClassBookingStatus({
    required this.classId,
    required this.hasBooking,
    required this.isRegistered,
    this.bookingId,
    this.bookingStatus,
    this.paymentStatus,
    this.escrowStatus,
    this.paymentReference,
    this.tuitionAmount,
    this.bookedAt,
  });

  bool get hasPendingRegistration =>
      bookingStatus == 'payment_pending' || paymentStatus == 'pending';

  bool get shouldHidePaymentAction => isRegistered || hasPendingRegistration;

  factory StudentClassBookingStatus.fromMap(Map<String, dynamic> map) {
    return StudentClassBookingStatus(
      classId: map['class_id'] as String? ?? '',
      hasBooking: map['has_booking'] as bool? ?? false,
      isRegistered: map['is_registered'] as bool? ?? false,
      bookingId: map['booking_id'] as String?,
      bookingStatus: map['booking_status'] as String?,
      paymentStatus: map['payment_status'] as String?,
      escrowStatus: map['escrow_status'] as String?,
      paymentReference: map['payment_reference'] as String?,
      tuitionAmount: _toIntOrNull(map['tuition_amount']),
      bookedAt: map['booked_at'] != null
          ? DateTime.tryParse(map['booked_at'].toString())
          : null,
    );
  }
}

int? _toIntOrNull(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value) ?? double.tryParse(value)?.toInt();
  }
  return null;
}
