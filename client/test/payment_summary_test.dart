import 'package:client/features/payments/model/payment_summary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps creation payment refund statuses to tutor-friendly labels', () {
    const summary = PaymentSummary(
      classId: 'class-1',
      classStatus: 'cancelled',
      creationPaymentStatus: 'refund_processing',
      creationFeeAmount: 2000,
      minParticipants: 1,
      maxParticipants: 2,
      currentParticipants: 0,
      minimumParticipantsReached: false,
      tutorConfirmationStatus: 'waiting_minimum',
      tutorPayoutStatus: 'withheld',
      tutorPayoutAmount: 0,
      totalEscrowHeld: 0,
      activeDisputes: 0,
    );

    expect(summary.creationPaymentStatusLabel, 'Hoàn phí đang được xử lý');
  });
}
