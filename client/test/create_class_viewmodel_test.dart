import 'package:client/core/failure/failure.dart';
import 'package:client/core/providers/current_user_notifier.dart';
import 'package:client/features/auth/model/user_model.dart';
import 'package:client/features/payments/model/payment_transaction_status.dart';
import 'package:client/features/payments/repositories/payments_remote_repository.dart';
import 'package:client/features/tutor/repositories/tutor_remote_repository.dart';
import 'package:client/features/tutor/viewmodel/create_class_viewmodel.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

void main() {
  test(
    'submitClass requests class creation payment instead of direct class creation',
    () async {
      final fakePaymentsRepo = _FakePaymentsRemoteRepository();
      final fakeTutorRepo = _FakeTutorRemoteRepository();
      final container = ProviderContainer(
        overrides: [
          currentUserProvider.overrideWithValue(_sampleUser()),
          paymentsRemoteRepositoryProvider.overrideWithValue(fakePaymentsRepo),
          tutorRemoteRepositoryProvider.overrideWithValue(fakeTutorRepo),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(createClassViewModelProvider.notifier);
      final payment = await notifier.submitClass(
        topic: 'English speaking',
        title: 'Mock class',
        description: 'Practice session',
        level: 'beginner',
        locationId: 'location-1',
        startTime: DateTime.utc(2026, 3, 22, 10),
        endTime: DateTime.utc(2026, 3, 22, 12),
        minParticipants: 1,
        maxParticipants: 5,
        price: 150000,
      );

      expect(payment, isNotNull);
      expect(payment!.transactionRef, 'CLS-123');
      expect(fakePaymentsRepo.createClassCreationPaymentCalls, 1);
      expect(fakeTutorRepo.createClassCalls, 0);
      expect(fakePaymentsRepo.lastToken, 'token-123');
      expect(fakePaymentsRepo.lastClassPayload, isNotNull);
      expect(fakePaymentsRepo.lastClassPayload!['title'], 'Mock class');
      expect(fakePaymentsRepo.lastClassPayload!['location_id'], 'location-1');
      expect(fakePaymentsRepo.lastClassPayload!['price'], 150000);
      expect(container.read(createClassViewModelProvider).error, isNull);
      expect(
        container.read(createClassViewModelProvider).isSubmitting,
        isFalse,
      );
    },
  );
}

UserModel _sampleUser() {
  return UserModel(
    id: 'teacher-1',
    email: 'teacher@example.com',
    fullName: 'Teacher Demo',
    role: 'teacher',
    isActive: true,
    token: 'token-123',
  );
}

class _FakePaymentsRemoteRepository extends PaymentsRemoteRepository {
  int createClassCreationPaymentCalls = 0;
  String? lastToken;
  Map<String, dynamic>? lastClassPayload;

  @override
  Future<Either<AppFailure, PaymentTransactionStatus>>
  createClassCreationPayment({
    required String token,
    required Map<String, dynamic> classPayload,
  }) async {
    createClassCreationPaymentCalls += 1;
    lastToken = token;
    lastClassPayload = classPayload;
    return const Right(
      PaymentTransactionStatus(
        paymentId: 'payment-1',
        transactionRef: 'CLS-123',
        paymentType: 'class_creation',
        provider: 'payos',
        status: 'pending',
        amount: 12000,
        redirectUrl: 'http://localhost:8000/payments/mock/checkout/CLS-123',
        classId: 'class-1',
        classStatus: 'draft',
        message: 'Dang cho thanh toan',
      ),
    );
  }
}

class _FakeTutorRemoteRepository extends TutorRemoteRepository {
  int createClassCalls = 0;

  _FakeTutorRemoteRepository() : super(Dio());

  @override
  Future<Either<AppFailure, Map<String, dynamic>>> createClass(
    String token,
    Map<String, dynamic> body,
  ) async {
    createClassCalls += 1;
    return const Right(<String, dynamic>{});
  }
}
