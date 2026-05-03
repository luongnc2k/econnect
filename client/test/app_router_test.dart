import 'package:client/core/providers/current_user_notifier.dart';
import 'package:client/core/router/app_router.dart';
import 'package:client/features/auth/model/user_model.dart';
import 'package:client/features/profile/model/student_my_profile_model.dart';
import 'package:client/features/profile/view/screens/edit_my_profile_screen.dart';
import 'package:client/features/profile/viewmodel/my_profile_state.dart';
import 'package:client/features/profile/viewmodel/my_profile_viewmodel.dart';
import 'package:client/features/student/view/screens/student_nav_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'router redirects student to bank setup when loaded profile has no bank account',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWithValue(
              UserModel(
                id: 'student-1',
                email: 'student@example.com',
                fullName: 'Student Demo',
                role: 'student',
                isActive: true,
                token: 'token-123',
              ),
            ),
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
          child: Consumer(
            builder: (context, ref, _) =>
                MaterialApp.router(routerConfig: ref.watch(appRouterProvider)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(EditMyProfileScreen), findsOneWidget);
      expect(find.byType(StudentNavShell), findsNothing);
    },
  );

  test('appRouterProvider keeps the same router instance when profile changes', () {
    final profileViewModel = _MutableMyProfileViewModel(
      StudentMyProfileModel(
        id: 'student-1',
        email: 'student@example.com',
        fullName: 'Student Demo',
        role: 'student',
        isActive: true,
        token: 'token-123',
      ),
    );
    final container = ProviderContainer(
      overrides: [
        currentUserProvider.overrideWithValue(
          UserModel(
            id: 'student-1',
            email: 'student@example.com',
            fullName: 'Student Demo',
            role: 'student',
            isActive: true,
            token: 'token-123',
          ),
        ),
        myProfileViewModelProvider.overrideWith(() => profileViewModel),
      ],
    );
    addTearDown(container.dispose);

    final routerBefore = container.read(appRouterProvider);

    profileViewModel.setProfile(
      StudentMyProfileModel(
        id: 'student-1',
        email: 'student@example.com',
        fullName: 'Student Demo',
        role: 'student',
        isActive: true,
        token: 'token-123',
        bankName: 'MBBank',
        bankBin: '970422',
        bankAccountNumber: '1234567890',
        bankAccountHolder: 'STUDENT DEMO',
      ),
    );

    final routerAfter = container.read(appRouterProvider);
    expect(identical(routerBefore, routerAfter), isTrue);
  });
}

class _FakeMyProfileViewModel extends MyProfileViewModel {
  final StudentMyProfileModel profile;

  _FakeMyProfileViewModel(this.profile);

  @override
  MyProfileState build() {
    return MyProfileState(profile: profile);
  }
}

class _MutableMyProfileViewModel extends MyProfileViewModel {
  final StudentMyProfileModel initialProfile;

  _MutableMyProfileViewModel(this.initialProfile);

  @override
  MyProfileState build() {
    return MyProfileState(profile: initialProfile);
  }

  void setProfile(StudentMyProfileModel profile) {
    state = state.copyWith(profile: profile);
  }
}
