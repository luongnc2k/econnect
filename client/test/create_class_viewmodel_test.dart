import 'dart:typed_data';

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

  test(
    'submitClass uploads optional class material and includes it in payment payload',
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
        title: 'Class with material',
        description: 'Practice session',
        level: 'beginner',
        locationId: 'location-1',
        startTime: DateTime.utc(2026, 3, 22, 10),
        endTime: DateTime.utc(2026, 3, 22, 12),
        minParticipants: 1,
        maxParticipants: 5,
        price: 150000,
        materialBytes: Uint8List.fromList([1, 2, 3]),
        materialFileName: 'lesson-plan.pdf',
      );

      expect(payment, isNotNull);
      expect(fakeTutorRepo.uploadClassMaterialCalls, 1);
      expect(fakeTutorRepo.lastUploadedMaterialName, 'lesson-plan.pdf');
      expect(fakePaymentsRepo.lastClassPayload!['material_url'], _materialUrl);
      expect(
        fakePaymentsRepo.lastClassPayload!['material_file_name'],
        'lesson-plan.pdf',
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
  int uploadClassMaterialCalls = 0;
  String? lastUploadedMaterialName;

  _FakeTutorRemoteRepository() : super(Dio());

  @override
  Future<Either<AppFailure, Map<String, dynamic>>> createClass(
    String token,
    Map<String, dynamic> body,
  ) async {
    createClassCalls += 1;
    return const Right(<String, dynamic>{});
  }

  @override
  Future<Either<AppFailure, String>> uploadClassMaterial({
    required String token,
    required String fileName,
    required Uint8List fileBytes,
    String? filePath,
  }) async {
    uploadClassMaterialCalls += 1;
    lastUploadedMaterialName = fileName;
    return const Right(_materialUrl);
  }
}

const _materialUrl = 'http://127.0.0.1:8000/static/class-materials/lesson.pdf';
