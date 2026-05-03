import 'dart:typed_data';

import 'package:client/core/providers/current_user_notifier.dart';
import 'package:client/core/router/app_router.dart';
import 'package:client/features/auth/model/user_model.dart';
import 'package:client/features/profile/model/payout_bank_account_verification_result.dart';
import 'package:client/features/profile/model/student_my_profile_model.dart';
import 'package:client/features/profile/repositories/my_profile_repository.dart';
import 'package:client/features/profile/view/widgets/student_bank_account_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('redirects student to bank setup when bank account is missing', (
    tester,
  ) async {
    final fakeRepo = _FakeMyProfileRepository(profile: _sampleStudentProfile());
    final router = GoRouter(
      initialLocation: AppRoutes.studentHome,
      routes: [
        GoRoute(
          path: AppRoutes.studentHome,
          builder: (context, state) => StudentBankAccountGate(
            redirectPath: AppRoutes.studentBankSetup,
            child: const Scaffold(body: Center(child: Text('STUDENT_HOME'))),
          ),
        ),
        GoRoute(
          path: AppRoutes.studentBankSetup,
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('BANK_SETUP'))),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWithValue(_sampleCurrentUser()),
          myProfileRepositoryProvider.overrideWithValue(fakeRepo),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('BANK_SETUP'), findsOneWidget);
    expect(find.text('STUDENT_HOME'), findsNothing);
  });
}

class _FakeMyProfileRepository implements IMyProfileRepository {
  final StudentMyProfileModel profile;

  _FakeMyProfileRepository({required this.profile});

  @override
  Future<UserModel> getMyProfile() async {
    return profile;
  }

  @override
  Future<UserModel> updateMyProfile(UserModel profile) async {
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
    return const PayoutBankAccountVerificationResult(
      provider: 'payos',
      isValid: true,
      message:
          'payOS không trả lỗi khi kiểm tra sơ bộ tài khoản nhận tiền này.',
      estimateCredit: 0,
    );
  }
}

UserModel _sampleCurrentUser() {
  return UserModel(
    id: 'student-1',
    email: 'student@example.com',
    fullName: 'Student Demo',
    role: 'student',
    isActive: true,
    token: 'token-123',
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
  );
}
