import 'dart:async';

import 'package:client/core/failure/failure.dart';
import 'package:client/core/providers/current_user_notifier.dart';
import 'package:client/core/theme/theme.dart';
import 'package:client/features/auth/model/user_model.dart';
import 'package:client/features/payments/model/payment_transaction_status.dart';
import 'package:client/features/payments/repositories/payments_remote_repository.dart';
import 'package:client/features/tutor/model/learning_location.dart';
import 'package:client/features/tutor/repositories/tutor_remote_repository.dart';
import 'package:client/features/tutor/view/screens/create_class_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeUrlLauncher fakeUrlLauncher;

  setUp(() {
    fakeUrlLauncher = _FakeUrlLauncher();
    UrlLauncherPlatform.instance = fakeUrlLauncher;
  });

  testWidgets(
    'create class screen loads learning locations from server response',
    (tester) async {
      final fakeTutorRepo = _FakeTutorRemoteRepository(
        locations: const [
          LearningLocation(
            id: 'loc-1',
            name: 'Remote Location 01',
            address: '12 Nguyen Van Linh',
            notes: 'Tang 2',
            isActive: true,
          ),
          LearningLocation(
            id: 'loc-2',
            name: 'Remote Location 02',
            address: '34 Le Loi',
            notes: null,
            isActive: true,
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWithValue(_sampleUser()),
            tutorRemoteRepositoryProvider.overrideWithValue(fakeTutorRepo),
          ],
          child: MaterialApp(
            theme: AppTheme.lightThemeMode,
            home: const CreateClassScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(fakeTutorRepo.getLearningLocationsCalls, 1);
      expect(find.text('Đang tải danh sách địa điểm học...'), findsNothing);
      expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(find.text('Tài liệu học (tùy chọn)'), findsOneWidget);
    },
  );

  testWidgets(
    'create class screen asks tutor to confirm the non-refundable creation fee before payment',
    (tester) async {
      final fakeTutorRepo = _FakeTutorRemoteRepository(
        locations: const [
          LearningLocation(
            id: 'loc-1',
            name: 'Remote Location 01',
            address: '12 Nguyen Van Linh',
            notes: 'Tang 2',
            isActive: true,
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWithValue(_sampleUser()),
            tutorRemoteRepositoryProvider.overrideWithValue(fakeTutorRepo),
          ],
          child: MaterialApp(
            theme: AppTheme.lightThemeMode,
            home: const CreateClassScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -1200));
      await tester.pumpAndSettle();

      final primaryButton = find.text('Tạo buổi học và thanh toán');
      await tester.ensureVisible(primaryButton);
      await tester.tap(primaryButton);
      await tester.pumpAndSettle();

      expect(find.text('Xác nhận trước khi thanh toán'), findsOneWidget);
      expect(
        find.text(
          'Sau khi thanh toán sẽ không được hoàn phí tạo lớp nếu hủy lớp. Bạn có muốn tiếp tục không?',
        ),
        findsOneWidget,
      );
      expect(find.text('Quay lại'), findsOneWidget);
      expect(find.text('Tôi đã hiểu'), findsOneWidget);
    },
  );

  testWidgets(
    'create class screen creates a new QR payment when price changes after returning from payment',
    (tester) async {
      final fakeTutorRepo = _FakeTutorRemoteRepository(
        locations: const [
          LearningLocation(
            id: 'loc-1',
            name: 'Remote Location 01',
            address: '12 Nguyen Van Linh',
            notes: 'Tang 2',
            isActive: true,
          ),
        ],
      );
      final fakePaymentsRepo = _FakePaymentsRemoteRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWithValue(_sampleUser()),
            tutorRemoteRepositoryProvider.overrideWithValue(fakeTutorRepo),
            paymentsRemoteRepositoryProvider.overrideWithValue(
              fakePaymentsRepo,
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightThemeMode,
            home: const CreateClassScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await _fillRequiredClassFields(tester, price: '200000');

      await _tapPrimaryAndConfirm(tester);
      await tester.pump();
      await tester.pump();

      expect(fakePaymentsRepo.createClassCreationPaymentCalls, 1);
      expect(fakePaymentsRepo.lastClassPayload?['price'], 200000);
      expect(fakeUrlLauncher.launchedUrls, [
        'http://localhost:8000/payments/mock/checkout/CRF-1',
      ]);

      fakePaymentsRepo.pendingStatusCompleter =
          Completer<Either<AppFailure, PaymentTransactionStatus>>();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(fakePaymentsRepo.getTransactionStatusCalls, 1);

      await _enterTextField(
        tester,
        const ValueKey('create-class-price'),
        '300000',
      );
      fakePaymentsRepo.pendingStatusCompleter!.complete(
        Right(fakePaymentsRepo.createdPayments.first),
      );
      await tester.pump();
      await tester.pump();

      await _tapPrimaryAndConfirm(tester);
      await tester.pump();
      await tester.pump();

      expect(fakePaymentsRepo.createClassCreationPaymentCalls, 2);
      expect(fakePaymentsRepo.lastClassPayload?['price'], 300000);
      expect(fakePaymentsRepo.createdPayments.last.amount, 30000);
      expect(fakeUrlLauncher.launchedUrls, [
        'http://localhost:8000/payments/mock/checkout/CRF-1',
      ]);

      await tester.pumpWidget(const SizedBox.shrink());
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

class _FakeTutorRemoteRepository extends TutorRemoteRepository {
  final List<LearningLocation> locations;
  int getLearningLocationsCalls = 0;

  _FakeTutorRemoteRepository({required this.locations}) : super(Dio());

  @override
  Future<Either<AppFailure, List<LearningLocation>>> getLearningLocations(
    String token,
  ) async {
    getLearningLocationsCalls += 1;
    return Right(locations);
  }
}

Future<void> _fillRequiredClassFields(
  WidgetTester tester, {
  required String price,
}) async {
  await _enterTextField(
    tester,
    const ValueKey('create-class-title'),
    'Mock class',
  );
  await _enterTextField(
    tester,
    const ValueKey('create-class-topic'),
    'English speaking',
  );

  await tester.drag(find.byType(ListView), const Offset(0, -700));
  await tester.pumpAndSettle();
  final locationDropdown = find.byWidgetPredicate(
    (widget) =>
        widget is DropdownButtonFormField<String> &&
        widget.key is ValueKey<String> &&
        (widget.key as ValueKey<String>).value.startsWith('location-'),
  );
  await tester.ensureVisible(locationDropdown);
  tester
      .widget<DropdownButtonFormField<String>>(locationDropdown)
      .onChanged
      ?.call('loc-1');
  await tester.pumpAndSettle();

  await _pickInitialDateTime(tester, 0);
  await _pickInitialDateTime(tester, 1);

  await _enterTextField(
    tester,
    const ValueKey('create-class-min-participants'),
    '1',
  );
  await _enterTextField(
    tester,
    const ValueKey('create-class-max-participants'),
    '4',
  );
  await _enterTextField(tester, const ValueKey('create-class-price'), price);
}

Future<void> _enterTextField(
  WidgetTester tester,
  Key fieldKey,
  String text,
) async {
  final field = find.byKey(fieldKey);
  if (field.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      field,
      240,
      scrollable: find.byType(Scrollable),
    );
  } else {
    await tester.ensureVisible(field);
  }
  await tester.enterText(field, text);
  await tester.pump();
}

Future<void> _pickInitialDateTime(WidgetTester tester, int index) async {
  final dateTimeButton = find
      .byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == '_DateTimeButton',
      )
      .at(index);
  await tester.ensureVisible(dateTimeButton);
  await tester.tap(dateTimeButton);
  await tester.pumpAndSettle();
  await tester.tap(find.text('OK').last);
  await tester.pumpAndSettle();
  await tester.tap(find.text('OK').last);
  await tester.pumpAndSettle();
}

Future<void> _tapPrimaryAndConfirm(WidgetTester tester) async {
  final primaryButton = find.byKey(const ValueKey('create-class-submit'));
  if (primaryButton.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      primaryButton,
      240,
      scrollable: find.byType(Scrollable),
    );
  } else {
    await tester.ensureVisible(primaryButton);
  }
  await tester.tap(primaryButton);
  await tester.pumpAndSettle();
  final confirmButton = find.descendant(
    of: find.byType(AlertDialog),
    matching: find.byType(FilledButton),
  );
  expect(confirmButton, findsOneWidget);
  await tester.tap(confirmButton);
  await tester.pump();
}

class _FakePaymentsRemoteRepository extends PaymentsRemoteRepository {
  int createClassCreationPaymentCalls = 0;
  int getTransactionStatusCalls = 0;
  String? lastToken;
  Map<String, dynamic>? lastClassPayload;
  final createdPayments = <PaymentTransactionStatus>[];
  Completer<Either<AppFailure, PaymentTransactionStatus>>?
  pendingStatusCompleter;

  @override
  Future<Either<AppFailure, PaymentTransactionStatus>>
  createClassCreationPayment({
    required String token,
    required Map<String, dynamic> classPayload,
  }) async {
    createClassCreationPaymentCalls += 1;
    lastToken = token;
    lastClassPayload = classPayload;

    final price = (classPayload['price'] as num).toInt();
    final payment = PaymentTransactionStatus(
      paymentId: 'payment-$createClassCreationPaymentCalls',
      transactionRef: 'CRF-$createClassCreationPaymentCalls',
      paymentType: 'class_creation',
      provider: 'payos',
      status: 'pending',
      amount: (price * 0.1).round(),
      redirectUrl: createClassCreationPaymentCalls == 1
          ? 'http://localhost:8000/payments/mock/checkout/CRF-1'
          : null,
      classId: 'class-$createClassCreationPaymentCalls',
      classStatus: 'draft',
      message: 'Dang cho thanh toan',
    );
    createdPayments.add(payment);
    return Right(payment);
  }

  @override
  Future<Either<AppFailure, PaymentTransactionStatus>> getTransactionStatus({
    required String token,
    required String transactionRef,
  }) {
    getTransactionStatusCalls += 1;
    final completer = pendingStatusCompleter;
    if (completer != null) {
      return completer.future;
    }
    return Future.value(Right(createdPayments.last));
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
