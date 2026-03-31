import 'dart:typed_data';

import 'package:client/core/failure/failure.dart';
import 'package:client/core/providers/current_user_notifier.dart';
import 'package:client/core/theme/theme.dart';
import 'package:client/features/auth/model/user_model.dart';
import 'package:client/features/payments/model/payment_summary.dart';
import 'package:client/features/payments/model/payment_transaction_status.dart';
import 'package:client/features/payments/repositories/payments_remote_repository.dart';
import 'package:client/features/profile/model/payout_bank_account_verification_result.dart';
import 'package:client/features/profile/model/teacher_my_profile_model.dart';
import 'package:client/features/profile/repositories/my_profile_repository.dart';
import 'package:client/features/profile/view/widgets/my_profile_view.dart';
import 'package:client/features/student/model/class_session.dart';
import 'package:client/features/student/model/student_class_booking_status.dart';
import 'package:client/features/student/model/student_tutor_review.dart';
import 'package:client/features/student/model/student_tutor_review_status.dart';
import 'package:client/features/student/repositories/student_remote_repository.dart';
import 'package:client/features/student/view/screens/class_detail_screen.dart';
import 'package:client/features/tutor/view/screens/tutor_home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakePaymentsRemoteRepository fakeRepo;
  late _FakeStudentRemoteRepository fakeStudentRepo;
  late _FakeUrlLauncher fakeUrlLauncher;

  setUp(() {
    fakeRepo = _FakePaymentsRemoteRepository();
    fakeStudentRepo = _FakeStudentRemoteRepository();
    fakeUrlLauncher = _FakeUrlLauncher();
    UrlLauncherPlatform.instance = fakeUrlLauncher;
  });

  testWidgets('student payment flow opens browser and hides CTA after paid', (
    tester,
  ) async {
    fakeRepo.createJoinPaymentResult = const PaymentTransactionStatus(
      paymentId: 'pay-1',
      transactionRef: 'TUI-123',
      paymentType: 'tuition',
      provider: 'payos',
      status: 'pending',
      amount: 50000,
      redirectUrl: 'http://localhost:8000/payments/mock/checkout/TUI-123',
      classId: 'class-1',
      bookingId: 'booking-1',
      bookingStatus: 'payment_pending',
      escrowStatus: 'pending',
      classStatus: 'scheduled',
      message: 'Dang cho ket qua thanh toan',
    );
    fakeRepo.transactionStatuses = [
      const PaymentTransactionStatus(
        paymentId: 'pay-1',
        transactionRef: 'TUI-123',
        paymentType: 'tuition',
        provider: 'payos',
        status: 'paid',
        amount: 50000,
        classId: 'class-1',
        bookingId: 'booking-1',
        bookingStatus: 'confirmed',
        escrowStatus: 'held',
        classStatus: 'scheduled',
        message: 'Thanh toan thanh cong',
      ),
    ];
    fakeStudentRepo.bookingStatusResult = const StudentClassBookingStatus(
      classId: 'class-1',
      hasBooking: false,
      isRegistered: false,
    );

    await tester.pumpWidget(
      _buildApp(
        child: ClassDetailScreen(session: _sampleClassSession()),
        fakeRepo: fakeRepo,
        fakeStudentRepo: fakeStudentRepo,
        user: _sampleUser(role: 'student'),
      ),
    );
    await tester.pump();

    expect(find.text('Quay lại'), findsOneWidget);
    expect(find.text('Giảng viên'), findsOneWidget);
    expect(find.text('Thanh toán học phí'), findsOneWidget);
    expect(find.text('Cafe A'), findsOneWidget);
    expect(find.text('Bắt đầu'), findsOneWidget);
    expect(find.text('Kết thúc'), findsOneWidget);
    expect(find.text('20:00'), findsOneWidget);
    expect(find.text('123 Main Street'), findsOneWidget);
    expect(find.text('Mang theo tai nghe.'), findsNothing);

    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();

    expect(fakeRepo.createJoinPaymentCalls, 1);
    expect(fakeRepo.getTransactionStatusCalls, 1);
    expect(
      fakeUrlLauncher.launchedUrls.single,
      'http://localhost:8000/payments/mock/checkout/TUI-123',
    );
    expect(find.text('BOOKING CONFIRMED'), findsOneWidget);
    expect(find.text('ESCROW HELD'), findsOneWidget);
    expect(find.textContaining('50000 VND'), findsNWidgets(2));
    expect(find.textContaining('TUI-123'), findsWidgets);
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets(
    'student payment flow stops waiting after payment window is closed',
    (tester) async {
      fakeRepo.createJoinPaymentResult = const PaymentTransactionStatus(
        paymentId: 'pay-2',
        transactionRef: 'TUI-456',
        paymentType: 'tuition',
        provider: 'payos',
        status: 'pending',
        amount: 50000,
        redirectUrl: 'http://localhost:8000/payments/mock/checkout/TUI-456',
        classId: 'class-1',
        bookingId: 'booking-2',
        bookingStatus: 'payment_pending',
        escrowStatus: 'pending',
        classStatus: 'scheduled',
        message: 'Dang cho ket qua thanh toan',
      );
      fakeRepo.transactionStatuses = [
        const PaymentTransactionStatus(
          paymentId: 'pay-2',
          transactionRef: 'TUI-456',
          paymentType: 'tuition',
          provider: 'payos',
          status: 'pending',
          amount: 50000,
          redirectUrl: 'http://localhost:8000/payments/mock/checkout/TUI-456',
          classId: 'class-1',
          bookingId: 'booking-2',
          bookingStatus: 'payment_pending',
          escrowStatus: 'pending',
          classStatus: 'scheduled',
          message: 'Dang cho ket qua thanh toan',
        ),
      ];
      fakeStudentRepo.bookingStatusResult = const StudentClassBookingStatus(
        classId: 'class-1',
        hasBooking: false,
        isRegistered: false,
      );

      await tester.pumpWidget(
        _buildApp(
          child: ClassDetailScreen(session: _sampleClassSession()),
          fakeRepo: fakeRepo,
          fakeStudentRepo: fakeStudentRepo,
          user: _sampleUser(role: 'student'),
        ),
      );
      await tester.pump();

      await tester.tap(find.byType(FilledButton));
      await tester.pump();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump();

      expect(fakeRepo.createJoinPaymentCalls, 1);
      expect(fakeRepo.getTransactionStatusCalls, 1);
      expect(find.text('Tiếp tục thanh toán'), findsOneWidget);
      expect(
        find.textContaining('Bạn đã đóng cửa sổ thanh toán'),
        findsOneWidget,
      );

      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      expect(fakeRepo.getTransactionStatusCalls, 1);

      await tester.tap(find.text('Tiếp tục thanh toán'));
      await tester.pump();

      expect(fakeRepo.createJoinPaymentCalls, 1);
      expect(fakeUrlLauncher.launchedUrls.length, 2);
    },
  );

  testWidgets(
    'student detail hides payment action when class is already registered',
    (tester) async {
      fakeStudentRepo.bookingStatusResult = const StudentClassBookingStatus(
        classId: 'class-1',
        hasBooking: true,
        isRegistered: true,
        bookingId: 'booking-1',
        bookingStatus: 'confirmed',
        paymentStatus: 'paid',
        escrowStatus: 'held',
        paymentReference: 'TUI-REGISTERED-1',
        tuitionAmount: 50000,
      );

      await tester.pumpWidget(
        _buildApp(
          child: ClassDetailScreen(session: _sampleClassSession()),
          fakeRepo: fakeRepo,
          fakeStudentRepo: fakeStudentRepo,
          user: _sampleUser(role: 'student'),
        ),
      );
      await tester.pump();

      expect(fakeStudentRepo.getMyBookingStatusCalls, 1);
      expect(find.text('BOOKING CONFIRMED'), findsOneWidget);
      expect(find.text('PAYMENT PAID'), findsOneWidget);
      expect(find.textContaining('TUI-REGISTERED-1'), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
    },
  );

  testWidgets(
    'student can submit tutor review after class ends and sees hotline',
    (tester) async {
      fakeStudentRepo.bookingStatusResult = const StudentClassBookingStatus(
        classId: 'class-1',
        hasBooking: true,
        isRegistered: true,
        bookingId: 'booking-1',
        bookingStatus: 'completed',
        paymentStatus: 'paid',
        escrowStatus: 'released',
      );
      fakeStudentRepo.reviewStatusResult = const StudentTutorReviewStatus(
        classId: 'class-1',
        canReview: true,
        alreadyReviewed: false,
        hotline: '0335837165',
      );
      fakeStudentRepo.submitReviewResult = StudentTutorReviewStatus(
        classId: 'class-1',
        canReview: false,
        alreadyReviewed: true,
        hotline: '0335837165',
        review: _sampleTutorReview(rating: 5, comment: 'Tutor rất nhiệt tình.'),
      );

      await tester.pumpWidget(
        _buildApp(
          child: ClassDetailScreen(session: _sampleClassSession()),
          fakeRepo: fakeRepo,
          fakeStudentRepo: fakeStudentRepo,
          user: _sampleUser(role: 'student'),
        ),
      );
      await tester.pump();

      expect(find.text('Đánh giá buổi học'), findsOneWidget);
      expect(find.textContaining('0335837165'), findsOneWidget);

      final starFinder = find.byKey(const Key('tutorReviewStar-5'));
      await tester.ensureVisible(starFinder);
      await tester.tap(starFinder, warnIfMissed: false);
      await tester.pump();
      final commentFinder = find.byKey(const Key('tutorReviewCommentField'));
      await tester.ensureVisible(commentFinder);
      await tester.enterText(commentFinder, 'Tutor rất nhiệt tình.');
      await tester.pump();
      final submitFinder = find.byKey(const Key('tutorReviewSubmitButton'));
      await tester.ensureVisible(submitFinder);
      await tester.tap(submitFinder, warnIfMissed: false);
      await tester.pump();

      expect(fakeStudentRepo.getMyTutorReviewCalls, 1);
      expect(fakeStudentRepo.submitTutorReviewCalls, 1);
      expect(fakeStudentRepo.lastSubmittedRating, 5);
      expect(fakeStudentRepo.lastSubmittedComment, 'Tutor rất nhiệt tình.');
      expect(find.byKey(const Key('tutorReviewSubmitButton')), findsNothing);
      expect(find.byKey(const Key('tutorReviewCommentField')), findsNothing);
      expect(find.text('Nhận xét của bạn'), findsOneWidget);
      expect(find.text('5/5 sao'), findsOneWidget);
    },
  );

  testWidgets('tutor payment tab loads class summary by class code', (
    tester,
  ) async {
    fakeRepo.summaryResult = const PaymentSummary(
      classId: 'class-1',
      classStatus: 'scheduled',
      creationPaymentStatus: 'paid',
      creationFeeAmount: 12000,
      minParticipants: 2,
      maxParticipants: 4,
      currentParticipants: 3,
      minimumParticipantsReached: true,
      tutorConfirmationStatus: 'confirmed',
      tutorPayoutStatus: 'pending',
      tutorPayoutAmount: 0,
      totalEscrowHeld: 60000,
      activeDisputes: 0,
    );

    await tester.pumpWidget(
      _buildApp(
        child: const TutorNavShell(),
        fakeRepo: fakeRepo,
        fakeStudentRepo: fakeStudentRepo,
        user: _sampleUser(role: 'teacher'),
      ),
    );

    await tester.tap(find.text('Thanh toán'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'CLS-260316-ABCD');
    await tester.tap(find.text('Xem trạng thái'));
    await tester.pump();

    expect(fakeRepo.lastRequestedClassCode, 'CLS-260316-ABCD');
    expect(find.text('Tổng quan đối soát'), findsOneWidget);
    expect(find.text('12000 VND'), findsOneWidget);
    expect(find.text('60000 VND'), findsOneWidget);
  });

  testWidgets('tutor profile tab shows tutor profile details', (tester) async {
    final fakeProfileRepo = _FakeMyProfileRepository(
      profile: TeacherMyProfileModel(
        id: 'teacher-1',
        email: 'teacher@example.com',
        fullName: 'Tutor Profile',
        role: 'teacher',
        isActive: true,
        token: 'token-123',
        specialization: 'English',
        yearsOfExperience: 5,
        bankName: 'VCB',
      ),
    );

    await tester.pumpWidget(
      _buildApp(
        child: const TutorNavShell(),
        fakeRepo: fakeRepo,
        fakeStudentRepo: fakeStudentRepo,
        fakeProfileRepo: fakeProfileRepo,
        user: _sampleUser(role: 'teacher'),
      ),
    );

    await tester.tap(find.text('Hồ sơ'));
    await tester.pump();
    await tester.pump();

    expect(fakeProfileRepo.getMyProfileCalls, 1);
    expect(find.byType(MyProfileView), findsOneWidget);
    expect(find.text('Tutor Profile'), findsNWidgets(2));
    expect(find.text('Học phí / buổi'), findsNothing);
  });
}

Widget _buildApp({
  required Widget child,
  required _FakePaymentsRemoteRepository fakeRepo,
  required _FakeStudentRemoteRepository fakeStudentRepo,
  _FakeMyProfileRepository? fakeProfileRepo,
  required UserModel user,
}) {
  return ProviderScope(
    overrides: [
      currentUserProvider.overrideWithValue(user),
      paymentsRemoteRepositoryProvider.overrideWithValue(fakeRepo),
      studentRemoteRepositoryProvider.overrideWithValue(fakeStudentRepo),
      if (fakeProfileRepo != null)
        myProfileRepositoryProvider.overrideWithValue(fakeProfileRepo),
    ],
    child: MaterialApp(theme: AppTheme.lightThemeMode, home: child),
  );
}

ClassSession _sampleClassSession() {
  return const ClassSession(
    id: 'class-1',
    classCode: 'CLS-260316-ABCD',
    title: 'English Mock Class',
    location: 'Cafe A',
    locationAddress: '123 Main Street',
    locationNotes: 'Mang theo tai nghe.',
    teacherId: 'teacher-1',
    teacherName: 'Tutor Demo',
    timeText: '18:00 - 20:00',
    priceText: '50000 VND',
    statusText: 'OPEN',
    description: 'Mock payment flow',
    dateText: '16/03/2026',
    slotText: '3 / 6',
    levelText: 'Intermediate',
  );
}

UserModel _sampleUser({required String role}) {
  return UserModel(
    id: 'user-1',
    email: 'demo@example.com',
    fullName: 'Demo User',
    role: role,
    isActive: true,
    token: 'token-123',
  );
}

StudentTutorReview _sampleTutorReview({required int rating, String? comment}) {
  return StudentTutorReview(
    id: 'review-1',
    classId: 'class-1',
    bookingId: 'booking-1',
    teacherId: 'teacher-1',
    studentId: 'user-1',
    rating: rating,
    comment: comment,
  );
}

class _FakePaymentsRemoteRepository extends PaymentsRemoteRepository {
  PaymentTransactionStatus? createJoinPaymentResult;
  List<PaymentTransactionStatus> transactionStatuses = [];
  PaymentSummary? summaryResult;
  int createJoinPaymentCalls = 0;
  int getTransactionStatusCalls = 0;
  String? lastRequestedClassCode;

  @override
  Future<Either<AppFailure, PaymentTransactionStatus>> createJoinPayment({
    required String token,
    required String classId,
  }) async {
    createJoinPaymentCalls += 1;
    return Right(createJoinPaymentResult!);
  }

  @override
  Future<Either<AppFailure, PaymentTransactionStatus>> getTransactionStatus({
    required String token,
    required String transactionRef,
  }) async {
    getTransactionStatusCalls += 1;
    final next = transactionStatuses.removeAt(0);
    return Right(next);
  }

  @override
  Future<Either<AppFailure, PaymentSummary>> getSummaryByClassCode({
    required String token,
    required String classCode,
  }) async {
    lastRequestedClassCode = classCode;
    return Right(summaryResult!);
  }
}

class _FakeStudentRemoteRepository extends StudentRemoteRepository {
  StudentClassBookingStatus bookingStatusResult =
      const StudentClassBookingStatus(
        classId: 'class-1',
        hasBooking: false,
        isRegistered: false,
      );
  StudentTutorReviewStatus reviewStatusResult = const StudentTutorReviewStatus(
    classId: 'class-1',
    canReview: false,
    alreadyReviewed: false,
    hotline: '0335837165',
  );
  StudentTutorReviewStatus? submitReviewResult;
  int getMyBookingStatusCalls = 0;
  int getMyTutorReviewCalls = 0;
  int submitTutorReviewCalls = 0;
  int? lastSubmittedRating;
  String? lastSubmittedComment;

  @override
  Future<Either<AppFailure, StudentClassBookingStatus>> getMyBookingStatus({
    required String token,
    required String classId,
  }) async {
    getMyBookingStatusCalls += 1;
    return Right(bookingStatusResult);
  }

  @override
  Future<Either<AppFailure, StudentTutorReviewStatus>> getMyTutorReview({
    required String token,
    required String classId,
  }) async {
    getMyTutorReviewCalls += 1;
    return Right(reviewStatusResult);
  }

  @override
  Future<Either<AppFailure, StudentTutorReviewStatus>> submitTutorReview({
    required String token,
    required String classId,
    required int rating,
    String? comment,
  }) async {
    submitTutorReviewCalls += 1;
    lastSubmittedRating = rating;
    lastSubmittedComment = comment;
    return Right(submitReviewResult ?? reviewStatusResult);
  }
}

class _FakeMyProfileRepository implements IMyProfileRepository {
  final UserModel profile;
  int getMyProfileCalls = 0;

  _FakeMyProfileRepository({required this.profile});

  @override
  Future<UserModel> getMyProfile() async {
    getMyProfileCalls += 1;
    return profile;
  }

  @override
  Future<UserModel> updateMyProfile(UserModel profile) async => profile;

  @override
  Future<String> uploadMyAvatar({
    required String fileName,
    required Uint8List fileBytes,
    String? filePath,
  }) async {
    return 'http://localhost:8000/static/avatar.jpg';
  }

  @override
  Future<String> uploadTutorDocument({
    required String fileName,
    required Uint8List fileBytes,
    String? filePath,
  }) async {
    return 'http://localhost:8000/static/teacher-doc.jpg';
  }

  @override
  Future<PayoutBankAccountVerificationResult> verifyPayoutBankAccount({
    required String bankBin,
    required String bankAccountNumber,
  }) async {
    return const PayoutBankAccountVerificationResult(
      provider: 'payos',
      isValid: true,
      message: 'payOS không trả lỗi khi kiểm tra sơ bộ tài khoản nhận tiền này',
      estimateCredit: 0,
    );
  }
}

class _FakeUrlLauncher extends UrlLauncherPlatform
    with MockPlatformInterfaceMixin {
  final launchedUrls = <String>[];

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<bool> launch(
    String url, {
    required bool useSafariVC,
    required bool useWebView,
    required bool enableJavaScript,
    required bool enableDomStorage,
    required bool universalLinksOnly,
    required Map<String, String> headers,
    String? webOnlyWindowName,
  }) async {
    launchedUrls.add(url);
    return true;
  }
}
