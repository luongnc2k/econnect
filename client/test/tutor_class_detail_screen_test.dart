import 'package:client/core/failure/failure.dart';
import 'package:client/core/providers/current_user_notifier.dart';
import 'package:client/core/theme/theme.dart';
import 'package:client/features/auth/model/user_model.dart';
import 'package:client/features/payments/model/payment_summary.dart';
import 'package:client/features/payments/repositories/payments_remote_repository.dart';
import 'package:client/features/student/model/class_session.dart';
import 'package:client/features/student/model/teacher_preview.dart';
import 'package:client/features/tutor/model/enrolled_student.dart';
import 'package:client/features/tutor/repositories/tutor_remote_repository.dart';
import 'package:client/features/tutor/view/screens/tutor_class_detail_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

void main() {
  testWidgets(
    'tutor can confirm class cancellation and screen updates to cancelled state',
    (tester) async {
      final fakePaymentsRepo = _FakePaymentsRemoteRepository();
      final fakeTutorRepo = _FakeTutorRemoteRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWithValue(_sampleUser()),
            paymentsRemoteRepositoryProvider.overrideWithValue(fakePaymentsRepo),
            tutorRemoteRepositoryProvider.overrideWithValue(fakeTutorRepo),
          ],
          child: MaterialApp(
            theme: AppTheme.lightThemeMode,
            home: TutorClassDetailScreen(session: _sampleSession()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.widgetWithText(OutlinedButton, 'Hủy buổi học'), findsOneWidget);

      await tester.ensureVisible(
        find.widgetWithText(OutlinedButton, 'Hủy buổi học'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(OutlinedButton, 'Hủy buổi học'));
      await tester.pumpAndSettle();

      expect(find.text('Hủy buổi học này?'), findsOneWidget);
      expect(
        find.text('• Bạn sẽ không được hoàn lại phí tạo buổi học.'),
        findsOneWidget,
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Xác nhận hủy'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(fakePaymentsRepo.cancelCalls, 1);
      expect(fakePaymentsRepo.lastCancelledClassId, 'class-1');
      expect(find.text('Buổi học đã được hủy'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Hủy buổi học'), findsNothing);
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

ClassSession _sampleSession() {
  return ClassSession(
    id: 'class-1',
    classCode: 'CLS-260331-9F9A',
    title: 'English Speaking',
    location: 'Google Meet',
    teacherId: 'teacher-1',
    teacherName: 'Teacher Demo',
    timeText: '18:00 Hôm nay',
    endTimeText: '20:00',
    priceText: '50.000đ',
    totalPriceText: '150.000đ',
    statusText: 'OPEN',
    description: 'Test cancel flow',
    dateText: '31/03/2026',
    slotText: '2/3 đã đăng ký',
    tags: const ['Speaking'],
    startDateTime: DateTime.now().add(const Duration(days: 1)),
    endDateTime: DateTime.now().add(const Duration(days: 1, hours: 2)),
  );
}

class _FakePaymentsRemoteRepository extends PaymentsRemoteRepository {
  int cancelCalls = 0;
  String? lastCancelledClassId;

  @override
  Future<Either<AppFailure, PaymentSummary>> cancelClass({
    required String token,
    required String classId,
    String? reason,
  }) async {
    cancelCalls += 1;
    lastCancelledClassId = classId;
    return const Right(
      PaymentSummary(
        classId: 'class-1',
        classStatus: 'cancelled',
        creationPaymentStatus: 'paid',
        creationFeeAmount: 2000,
        minParticipants: 1,
        maxParticipants: 3,
        currentParticipants: 0,
        minimumParticipantsReached: true,
        tutorConfirmationStatus: 'pending',
        tutorPayoutStatus: 'withheld',
        tutorPayoutAmount: 0,
        totalEscrowHeld: 0,
        activeDisputes: 0,
      ),
    );
  }
}

class _FakeTutorRemoteRepository extends TutorRemoteRepository {
  _FakeTutorRemoteRepository() : super(Dio());

  @override
  Future<Either<AppFailure, List<EnrolledStudent>>> getClassDetail(
    String token,
    String classId,
  ) async {
    return Right([
      EnrolledStudent(
        id: 'student-1',
        fullName: 'Student One',
        status: 'confirmed',
        bookedAt: DateTime(2026, 3, 31, 9),
      ),
    ]);
  }

  @override
  Future<Either<AppFailure, List<ClassSession>>> getMyClasses(
    String token, {
    bool past = false,
  }) async {
    return const Right([]);
  }

  @override
  Future<Either<AppFailure, List<TeacherPreview>>> getFeaturedTeachers(
    String token, {
    int limit = 5,
  }) async {
    return const Right([]);
  }
}
