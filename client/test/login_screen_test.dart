import 'package:client/core/router/app_router.dart';
import 'package:client/features/auth/model/user_model.dart';
import 'package:client/features/auth/view/screens/login_screen.dart';
import 'package:client/features/auth/viewmodel/auth_viewmodel.dart';
import 'package:client/features/profile/model/student_my_profile_model.dart';
import 'package:client/features/profile/viewmodel/my_profile_state.dart';
import 'package:client/features/profile/viewmodel/my_profile_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets(
    'student login redirects to bank setup when bank account is missing',
    (tester) async {
      final fakeAuthViewModel = _FakeAuthViewModel(
        user: UserModel(
          id: 'student-1',
          email: 'student@example.com',
          fullName: 'Student Demo',
          role: 'student',
          isActive: true,
          token: 'token-123',
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authViewModelProvider.overrideWith(() => fakeAuthViewModel),
            myProfileViewModelProvider.overrideWith(
              () => _FakeMyProfileViewModel(
                StudentMyProfileModel(
                  id: 'student-1',
                  email: 'student@example.com',
                  fullName: 'Student Demo',
                  role: 'student',
                  isActive: true,
                  token: 'token-123',
                ),
              ),
            ),
          ],
          child: MaterialApp.router(routerConfig: _buildRouter()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextFormField).at(0),
        'student@example.com',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'Password123!');
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('BANK_SETUP'), findsOneWidget);
      expect(find.text('STUDENT_HOME'), findsNothing);
    },
  );
}

GoRouter _buildRouter() {
  return GoRouter(
    initialLocation: AppRoutes.login,
    routes: [
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.studentHome,
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('STUDENT_HOME'))),
      ),
      GoRoute(
        path: AppRoutes.studentBankSetup,
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('BANK_SETUP'))),
      ),
    ],
  );
}

class _FakeAuthViewModel extends AuthViewModel {
  final UserModel user;

  _FakeAuthViewModel({required this.user});

  @override
  AsyncValue<UserModel>? build() {
    return null;
  }

  @override
  Future<void> loginUser({
    required String email,
    required String password,
  }) async {
    state = AsyncValue.data(user);
  }
}

class _FakeMyProfileViewModel extends MyProfileViewModel {
  final StudentMyProfileModel profile;

  _FakeMyProfileViewModel(this.profile);

  @override
  MyProfileState build() {
    return MyProfileState(profile: profile);
  }
}
