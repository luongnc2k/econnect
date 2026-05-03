import 'dart:typed_data';

import 'package:client/core/providers/current_user_notifier.dart';
import 'package:client/core/theme/theme.dart';
import 'package:client/features/auth/model/user_model.dart';
import 'package:client/features/profile/model/payout_bank_account_verification_result.dart';
import 'package:client/features/profile/model/student_my_profile_model.dart';
import 'package:client/features/profile/model/teacher_my_profile_model.dart';
import 'package:client/features/profile/repositories/my_profile_repository.dart';
import 'package:client/features/profile/view/screens/edit_my_profile_screen.dart';
import 'package:client/features/profile/viewmodel/my_profile_state.dart';
import 'package:client/features/profile/viewmodel/my_profile_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('selecting a payout bank autofills bank name and BIN on save', (
    tester,
  ) async {
    final fakeRepo = _FakeMyProfileRepository();
    final teacherProfile = _sampleTeacherProfile();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWithValue(_sampleCurrentUser()),
          myProfileRepositoryProvider.overrideWithValue(fakeRepo),
          myProfileViewModelProvider.overrideWith(
            () => _TestMyProfileViewModel(teacherProfile),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.lightThemeMode,
          home: const EditMyProfileScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ngân hàng nhận payout'), findsOneWidget);

    final dropdownFinder = find.byType(DropdownButtonFormField<String>);
    await tester.ensureVisible(dropdownFinder);
    await tester.tap(dropdownFinder, warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.tap(find.text('BIDV').last);
    await tester.pumpAndSettle();

    await _waitForAutoVerification(tester);

    final saveButtonFinder = find.byKey(const Key('saveProfileButton'));
    await tester.ensureVisible(saveButtonFinder);
    await tester.tap(saveButtonFinder, warnIfMissed: false);
    await tester.pumpAndSettle();

    final saved = fakeRepo.updatedProfile;
    expect(saved, isA<TeacherMyProfileModel>());
    expect((saved as TeacherMyProfileModel).bankName, 'BIDV');
    expect(saved.bankBin, '970418');
    expect(fakeRepo.verifyCallCount, 1);
  });

  testWidgets('student can save bank account with the same bank picker flow', (
    tester,
  ) async {
    final fakeRepo = _FakeMyProfileRepository();
    final studentProfile = _sampleStudentProfile().copyWith(
      bankName: 'ACB',
      bankBin: '970416',
      bankAccountNumber: '1234567890',
      bankAccountHolder: 'STUDENT DEMO',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWithValue(
            _sampleCurrentUser(role: 'student'),
          ),
          myProfileRepositoryProvider.overrideWithValue(fakeRepo),
          myProfileViewModelProvider.overrideWith(
            () => _TestMyProfileViewModel(studentProfile),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.lightThemeMode,
          home: const EditMyProfileScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tài khoản ngân hàng'), findsOneWidget);

    final dropdownFinder = find.byType(DropdownButtonFormField<String>);
    await tester.ensureVisible(dropdownFinder);
    await tester.tap(dropdownFinder, warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.tap(find.text('BIDV').last);
    await tester.pumpAndSettle();

    await _waitForAutoVerification(tester);

    final saveButtonFinder = find.byKey(const Key('saveProfileButton'));
    await tester.ensureVisible(saveButtonFinder);
    await tester.tap(saveButtonFinder, warnIfMissed: false);
    await tester.pumpAndSettle();

    final saved = fakeRepo.updatedProfile;
    expect(saved, isA<StudentMyProfileModel>());
    expect((saved as StudentMyProfileModel).bankName, 'BIDV');
    expect(saved.bankBin, '970418');
    expect(fakeRepo.verifyCallCount, 1);
  });

  testWidgets(
    'student first bank account save from normal edit screen returns to student home',
    (tester) async {
      final fakeRepo = _FakeMyProfileRepository();
      final studentProfile = _sampleStudentProfile();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWithValue(
              _sampleCurrentUser(role: 'student'),
            ),
            myProfileRepositoryProvider.overrideWithValue(fakeRepo),
            myProfileViewModelProvider.overrideWith(
              () => _TestMyProfileViewModel(studentProfile),
            ),
          ],
          child: MaterialApp.router(
            theme: AppTheme.lightThemeMode,
            routerConfig: _buildStudentEditRouter(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final dropdownFinder = find.byType(DropdownButtonFormField<String>);
      await tester.ensureVisible(dropdownFinder);
      await tester.tap(dropdownFinder, warnIfMissed: false);
      await tester.pumpAndSettle();
      await tester.tap(find.text('BIDV').last);
      await tester.pumpAndSettle();

      await _waitForAutoVerification(tester);

      final saveButtonFinder = find.byKey(const Key('saveProfileButton'));
      await tester.ensureVisible(saveButtonFinder);
      await tester.tap(saveButtonFinder, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.text('STUDENT_HOME'), findsOneWidget);
      final saved = fakeRepo.updatedProfile as StudentMyProfileModel;
      expect(saved.bankName, 'BIDV');
      expect(saved.bankBin, '970418');
    },
  );

  testWidgets(
    'student first bank account save reaches student home after router clears bank setup on next frame',
    (tester) async {
      final fakeRepo = _FakeMyProfileRepository();
      final studentProfile = _sampleStudentProfile();
      final needsBankSetup = ValueNotifier<bool>(true);

      fakeRepo.onProfileUpdated = (_) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          needsBankSetup.value = false;
        });
      };

      final router = GoRouter(
        refreshListenable: needsBankSetup,
        initialLocation: '/student-bank-setup',
        redirect: (context, state) {
          final onBankSetup = state.uri.path == '/student-bank-setup';
          if (needsBankSetup.value && !onBankSetup) {
            return '/student-bank-setup';
          }
          if (!needsBankSetup.value && onBankSetup) {
            return '/student';
          }
          return null;
        },
        routes: [
          GoRoute(
            path: '/student-bank-setup',
            builder: (context, state) => const EditMyProfileScreen(),
          ),
          GoRoute(
            path: '/student',
            builder: (context, state) =>
                const Scaffold(body: Center(child: Text('STUDENT_HOME'))),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWithValue(
              _sampleCurrentUser(role: 'student'),
            ),
            myProfileRepositoryProvider.overrideWithValue(fakeRepo),
            myProfileViewModelProvider.overrideWith(
              () => _TestMyProfileViewModel(studentProfile),
            ),
          ],
          child: MaterialApp.router(
            theme: AppTheme.lightThemeMode,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final dropdownFinder = find.byType(DropdownButtonFormField<String>);
      await tester.ensureVisible(dropdownFinder);
      await tester.tap(dropdownFinder, warnIfMissed: false);
      await tester.pumpAndSettle();
      await tester.tap(find.text('BIDV').last);
      await tester.pumpAndSettle();

      await _waitForAutoVerification(tester);

      final saveButtonFinder = find.byKey(const Key('saveProfileButton'));
      await tester.ensureVisible(saveButtonFinder);
      await tester.tap(saveButtonFinder, warnIfMissed: false);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('STUDENT_HOME'), findsOneWidget);
      expect(find.byType(EditMyProfileScreen), findsNothing);
    },
  );

  testWidgets(
    'required bank setup mode only shows bank fields for student and returns to student home',
    (tester) async {
      final fakeRepo = _FakeMyProfileRepository();
      final studentProfile = _sampleStudentProfile();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWithValue(
              _sampleCurrentUser(role: 'student'),
            ),
            myProfileRepositoryProvider.overrideWithValue(fakeRepo),
            myProfileViewModelProvider.overrideWith(
              () => _TestMyProfileViewModel(studentProfile),
            ),
          ],
          child: MaterialApp.router(
            theme: AppTheme.lightThemeMode,
            routerConfig: _buildStudentBankSetupRouter(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('saveProfileButton')), findsOneWidget);
      expect(find.text('Họ và tên'), findsNothing);
      expect(find.text('Trình độ tiếng Anh'), findsNothing);
      expect(find.text('Mục tiêu học'), findsNothing);
      expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);

      final dropdownFinder = find.byType(DropdownButtonFormField<String>);
      await tester.ensureVisible(dropdownFinder);
      await tester.tap(dropdownFinder, warnIfMissed: false);
      await tester.pumpAndSettle();
      await tester.tap(find.text('BIDV').last);
      await tester.pumpAndSettle();

      await _waitForAutoVerification(tester);

      final saveButtonFinder = find.byKey(const Key('saveProfileButton'));
      await tester.ensureVisible(saveButtonFinder);
      await tester.tap(saveButtonFinder, warnIfMissed: false);
      await tester.pumpAndSettle();

      final saved = fakeRepo.updatedProfile as StudentMyProfileModel;
      expect(find.text('STUDENT_HOME'), findsOneWidget);
      expect(saved.fullName, 'Student Demo');
      expect(saved.englishLevel, 'intermediate');
      expect(saved.bankName, 'BIDV');
      expect(saved.bankBin, '970418');
    },
  );

  testWidgets('required bank setup mode only shows payout bank fields', (
    tester,
  ) async {
    final fakeRepo = _FakeMyProfileRepository();
    final teacherProfile = _sampleTeacherProfile();
    final router = _buildTeacherBankSetupRouter();

    await _pumpBankSetupApp(
      tester,
      fakeRepo: fakeRepo,
      teacherProfile: teacherProfile,
      router: router,
    );

    expect(find.text('Thiết lập tài khoản ngân hàng'), findsOneWidget);
    expect(find.text('Tài khoản ngân hàng'), findsOneWidget);
    expect(find.text('Lưu tài khoản ngân hàng'), findsOneWidget);
    expect(find.text('Thông tin giáo viên'), findsNothing);
    expect(find.text('Họ và tên'), findsNothing);
    expect(find.text('Tải ảnh chứng chỉ / bằng cấp'), findsNothing);
    expect(find.text('Thay đổi avatar'), findsNothing);

    final dropdownFinder = find.byType(DropdownButtonFormField<String>);
    await tester.ensureVisible(dropdownFinder);
    await tester.tap(dropdownFinder, warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.tap(find.text('BIDV').last);
    await tester.pumpAndSettle();

    await _waitForAutoVerification(tester);

    final saveButtonFinder = find.byKey(const Key('saveProfileButton'));
    await tester.ensureVisible(saveButtonFinder);
    await tester.tap(saveButtonFinder, warnIfMissed: false);
    await tester.pumpAndSettle();

    final saved = fakeRepo.updatedProfile as TeacherMyProfileModel;
    expect(find.text('TEACHER_HOME'), findsOneWidget);
    expect(saved.fullName, 'Teacher Demo');
    expect(saved.specialization, 'IELTS');
    expect(saved.bankName, 'BIDV');
    expect(saved.bankBin, '970418');
  });

  testWidgets('bank account must be verified before tutor can save', (
    tester,
  ) async {
    final fakeRepo = _FakeMyProfileRepository();
    final teacherProfile = _sampleTeacherProfile();

    await _pumpBankSetupApp(
      tester,
      fakeRepo: fakeRepo,
      teacherProfile: teacherProfile,
      router: _buildTeacherBankSetupRouter(),
    );

    final dropdownFinder = find.byType(DropdownButtonFormField<String>);
    await tester.ensureVisible(dropdownFinder);
    await tester.tap(dropdownFinder, warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.tap(find.text('BIDV').last);
    await tester.pump(const Duration(milliseconds: 300));

    final saveButtonFinder = find.byKey(const Key('saveProfileButton'));
    await tester.ensureVisible(saveButtonFinder);
    await tester.tap(saveButtonFinder, warnIfMissed: false);
    await tester.pump();

    expect(
      find.text(
        'Vui lòng chờ hệ thống kiểm tra sơ bộ tài khoản ngân hàng với payOS trước khi lưu',
      ),
      findsOneWidget,
    );
    expect(fakeRepo.updatedProfile, isNull);
    expect(fakeRepo.verifyCallCount, 0);
  });

  testWidgets(
    'bank account auto verifies and allows tutor save after success',
    (tester) async {
      final fakeRepo = _FakeMyProfileRepository();
      final teacherProfile = _sampleTeacherProfile();

      await _pumpBankSetupApp(
        tester,
        fakeRepo: fakeRepo,
        teacherProfile: teacherProfile,
        router: _buildTeacherBankSetupRouter(),
      );

      final dropdownFinder = find.byType(DropdownButtonFormField<String>);
      await tester.ensureVisible(dropdownFinder);
      await tester.tap(dropdownFinder, warnIfMissed: false);
      await tester.pumpAndSettle();
      await tester.tap(find.text('BIDV').last);
      await tester.pumpAndSettle();

      await _waitForAutoVerification(tester);

      expect(find.text(fakeRepo.verificationMessage!), findsOneWidget);
      expect(fakeRepo.verifyCallCount, 1);
      expect(fakeRepo.verifiedBankBin, '970418');
      expect(fakeRepo.verifiedBankAccountNumber, '1234567890');

      final saveButtonFinder = find.byKey(const Key('saveProfileButton'));
      await tester.ensureVisible(saveButtonFinder);
      await tester.tap(saveButtonFinder, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.text('TEACHER_HOME'), findsOneWidget);
      final saved = fakeRepo.updatedProfile as TeacherMyProfileModel;
      expect(saved.bankName, 'BIDV');
      expect(saved.bankBin, '970418');
    },
  );

  testWidgets(
    'bank account holder input is normalized to uppercase without accents',
    (tester) async {
      final fakeRepo = _FakeMyProfileRepository();
      final teacherProfile = _sampleTeacherProfile();

      await _pumpBankSetupApp(
        tester,
        fakeRepo: fakeRepo,
        teacherProfile: teacherProfile,
        router: _buildTeacherBankSetupRouter(),
      );

      final bankAccountHolderField = find.byKey(
        const Key('bankAccountHolderField'),
      );
      await tester.ensureVisible(bankAccountHolderField);
      await tester.enterText(bankAccountHolderField, 'Trần Đăng Khoa');
      await tester.pump();

      expect(find.text('TRAN DANG KHOA'), findsOneWidget);

      final dropdownFinder = find.byType(DropdownButtonFormField<String>);
      await tester.ensureVisible(dropdownFinder);
      await tester.tap(dropdownFinder, warnIfMissed: false);
      await tester.pumpAndSettle();
      await tester.tap(find.text('BIDV').last);
      await tester.pumpAndSettle();
      await _waitForAutoVerification(tester);

      final saveButtonFinder = find.byKey(const Key('saveProfileButton'));
      await tester.ensureVisible(saveButtonFinder);
      await tester.tap(saveButtonFinder, warnIfMissed: false);
      await tester.pumpAndSettle();

      final saved = fakeRepo.updatedProfile as TeacherMyProfileModel;
      expect(saved.bankAccountHolder, 'TRAN DANG KHOA');
    },
  );
}

Future<void> _pumpBankSetupApp(
  WidgetTester tester, {
  required _FakeMyProfileRepository fakeRepo,
  required TeacherMyProfileModel teacherProfile,
  required GoRouter router,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserProvider.overrideWithValue(_sampleCurrentUser()),
        myProfileRepositoryProvider.overrideWithValue(fakeRepo),
        myProfileViewModelProvider.overrideWith(
          () => _TestMyProfileViewModel(teacherProfile),
        ),
      ],
      child: MaterialApp.router(
        theme: AppTheme.lightThemeMode,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

GoRouter _buildTeacherBankSetupRouter() {
  return GoRouter(
    initialLocation: '/bank-setup',
    routes: [
      GoRoute(
        path: '/bank-setup',
        builder: (context, state) =>
            const EditMyProfileScreen(requireBankSetup: true),
      ),
      GoRoute(
        path: '/teacher',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('TEACHER_HOME'))),
      ),
    ],
  );
}

GoRouter _buildStudentBankSetupRouter() {
  return GoRouter(
    initialLocation: '/student-bank-setup',
    routes: [
      GoRoute(
        path: '/student-bank-setup',
        builder: (context, state) =>
            const EditMyProfileScreen(requireBankSetup: true),
      ),
      GoRoute(
        path: '/student',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('STUDENT_HOME'))),
      ),
    ],
  );
}

GoRouter _buildStudentEditRouter() {
  return GoRouter(
    initialLocation: '/student-edit',
    routes: [
      GoRoute(
        path: '/student-edit',
        builder: (context, state) => const EditMyProfileScreen(),
      ),
      GoRoute(
        path: '/student',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('STUDENT_HOME'))),
      ),
    ],
  );
}

Future<void> _waitForAutoVerification(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 750));
  await tester.pumpAndSettle();
}

class _TestMyProfileViewModel extends MyProfileViewModel {
  final UserModel profile;

  _TestMyProfileViewModel(this.profile);

  @override
  MyProfileState build() {
    return MyProfileState(profile: profile);
  }
}

class _FakeMyProfileRepository implements IMyProfileRepository {
  UserModel? updatedProfile;
  int verifyCallCount = 0;
  String? verifiedBankBin;
  String? verifiedBankAccountNumber;
  void Function(UserModel profile)? onProfileUpdated;
  String? verificationMessage =
      'payOS không trả lỗi khi kiểm tra sơ bộ tài khoản nhận tiền này.';

  @override
  Future<UserModel> getMyProfile() async {
    throw UnimplementedError();
  }

  @override
  Future<UserModel> updateMyProfile(UserModel profile) async {
    updatedProfile = profile;
    onProfileUpdated?.call(profile);
    return profile;
  }

  @override
  Future<String> uploadMyAvatar({
    required String fileName,
    required Uint8List fileBytes,
    String? filePath,
  }) async {
    return 'https://example.com/avatar.jpg';
  }

  @override
  Future<String> uploadTutorDocument({
    required String fileName,
    required Uint8List fileBytes,
    String? filePath,
  }) async {
    return 'https://example.com/doc.jpg';
  }

  @override
  Future<PayoutBankAccountVerificationResult> verifyPayoutBankAccount({
    required String bankBin,
    required String bankAccountNumber,
  }) async {
    verifyCallCount += 1;
    verifiedBankBin = bankBin;
    verifiedBankAccountNumber = bankAccountNumber;
    return PayoutBankAccountVerificationResult(
      provider: 'payos',
      isValid: true,
      message: verificationMessage!,
      estimateCredit: 0,
    );
  }
}

UserModel _sampleCurrentUser({String role = 'teacher'}) {
  return UserModel(
    id: 'teacher-1',
    email: 'teacher@example.com',
    fullName: 'Teacher Demo',
    role: role,
    isActive: true,
    token: 'token-123',
  );
}

TeacherMyProfileModel _sampleTeacherProfile() {
  return TeacherMyProfileModel(
    id: 'teacher-1',
    email: 'teacher@example.com',
    fullName: 'Teacher Demo',
    role: 'teacher',
    isActive: true,
    token: 'token-123',
    specialization: 'IELTS',
    bankAccountNumber: '1234567890',
    bankAccountHolder: 'Teacher Demo',
  );
}

StudentMyProfileModel _sampleStudentProfile() {
  return StudentMyProfileModel(
    id: 'student-1',
    email: 'student@example.com',
    fullName: 'Student Demo',
    role: 'student',
    isActive: true,
    token: 'token-123',
    englishLevel: 'intermediate',
    learningGoal: 'Giao tiếp tự tin',
    bankAccountNumber: '1234567890',
    bankAccountHolder: 'Student Demo',
  );
}
