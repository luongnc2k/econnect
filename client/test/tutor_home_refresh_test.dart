import 'package:client/core/failure/failure.dart';
import 'package:client/core/providers/current_user_notifier.dart';
import 'package:client/core/theme/theme.dart';
import 'package:client/features/auth/model/user_model.dart';
import 'package:client/features/student/model/class_session.dart';
import 'package:client/features/tutor/repositories/tutor_remote_repository.dart';
import 'package:client/features/tutor/view/screens/tutor_home_tab.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

void main() {
  testWidgets('tutor home refreshes silently when app resumes', (tester) async {
    final fakeTutorRepo = _FakeTutorRemoteRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWithValue(_sampleUser()),
          tutorRemoteRepositoryProvider.overrideWithValue(fakeTutorRepo),
        ],
        child: MaterialApp(
          theme: AppTheme.lightThemeMode,
          home: const Scaffold(body: TutorHomeTab()),
        ),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    final initialUpcomingCalls = fakeTutorRepo.upcomingCalls;
    final initialPastCalls = fakeTutorRepo.pastCalls;

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(fakeTutorRepo.upcomingCalls, initialUpcomingCalls + 1);
    expect(fakeTutorRepo.pastCalls, initialPastCalls + 1);
  });
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
  int upcomingCalls = 0;
  int pastCalls = 0;

  _FakeTutorRemoteRepository() : super(Dio());

  @override
  Future<Either<AppFailure, List<ClassSession>>> getMyClasses(
    String token, {
    bool past = false,
  }) async {
    if (past) {
      pastCalls += 1;
      return const Right([]);
    }

    upcomingCalls += 1;
    return Right([
      ClassSession(
        id: 'class-1',
        classCode: 'CLS-260324-ABCD',
        title: 'English Speaking',
        location: 'Cafe A',
        locationAddress: '123 Main Street',
        teacherId: 'teacher-1',
        teacherName: 'Teacher Demo',
        timeText: '18:00 Hôm nay',
        priceText: '50.000đ',
        statusText: 'OPEN',
        startDateTime: DateTime(2026, 3, 26, 18),
        endDateTime: DateTime(2026, 3, 26, 20),
      ),
    ]);
  }
}
