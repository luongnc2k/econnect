import 'package:client/features/auth/model/user_model.dart';
import 'package:client/features/auth/view/screens/signup_screen.dart';
import 'package:client/features/auth/viewmodel/auth_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('teacher signup no longer requires bank account information', (
    tester,
  ) async {
    final fakeViewModel = _FakeAuthViewModel();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [authViewModelProvider.overrideWith(() => fakeViewModel)],
        child: const MaterialApp(home: SignupScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Gia sư'));
    await tester.pumpAndSettle();

    expect(find.text('Tài khoản ngân hàng nhận payout'), findsNothing);

    await tester.enterText(find.byType(TextFormField).at(0), 'Tutor Demo');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'tutor.demo@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(2), 'Password123!');

    await tester.tap(find.text('Sign Up'));
    await tester.pumpAndSettle();

    expect(fakeViewModel.lastSignupRequest, isNotNull);
    expect(fakeViewModel.lastSignupRequest?.role, 'teacher');
    expect(fakeViewModel.lastSignupRequest?.bankName, isNull);
    expect(fakeViewModel.lastSignupRequest?.bankBin, isNull);
    expect(fakeViewModel.lastSignupRequest?.bankAccountNumber, isNull);
    expect(fakeViewModel.lastSignupRequest?.bankAccountHolder, isNull);
  });
}

class _FakeAuthViewModel extends AuthViewModel {
  _SignupRequest? lastSignupRequest;

  @override
  AsyncValue<UserModel>? build() {
    return null;
  }

  @override
  Future<void> signUpUser({
    required String name,
    required String email,
    required String password,
    required String role,
    String? bankName,
    String? bankBin,
    String? bankAccountNumber,
    String? bankAccountHolder,
  }) async {
    lastSignupRequest = _SignupRequest(
      role: role,
      bankName: bankName,
      bankBin: bankBin,
      bankAccountNumber: bankAccountNumber,
      bankAccountHolder: bankAccountHolder,
    );
  }
}

class _SignupRequest {
  final String role;
  final String? bankName;
  final String? bankBin;
  final String? bankAccountNumber;
  final String? bankAccountHolder;

  const _SignupRequest({
    required this.role,
    required this.bankName,
    required this.bankBin,
    required this.bankAccountNumber,
    required this.bankAccountHolder,
  });
}
