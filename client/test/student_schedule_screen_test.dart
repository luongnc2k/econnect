import 'package:client/core/failure/failure.dart';
import 'package:client/core/providers/current_user_notifier.dart';
import 'package:client/core/router/app_router.dart';
import 'package:client/core/theme/theme.dart';
import 'package:client/features/auth/model/user_model.dart';
import 'package:client/features/student/model/class_session.dart';
import 'package:client/features/student/repositories/student_remote_repository.dart';
import 'package:client/features/student/view/screens/student_schedule_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets(
    'student schedule screen loads registered classes and opens detail',
    (tester) async {
      final fakeRepo = _FakeStudentRemoteRepository(
        upcomingClasses: [
          const ClassSession(
            id: 'class-1',
            classCode: 'CLS-260324-ABCD',
            title: 'Registered Class',
            location: 'Cafe A',
            teacherId: 'teacher-1',
            teacherName: 'Tutor Demo',
            timeText: '18:00 Hom nay',
            priceText: '50000 VND',
            statusText: 'OPEN',
            tags: ['Speaking'],
          ),
        ],
      );
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => const Scaffold(body: StudentScheduleScreen()),
          ),
          GoRoute(
            path: AppRoutes.classDetail,
            builder: (_, state) {
              final session = state.extra as ClassSession;
              return Scaffold(
                body: Center(child: Text('DETAIL ${session.title}')),
              );
            },
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWithValue(_sampleUser()),
            studentRemoteRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: MaterialApp.router(
            theme: AppTheme.lightThemeMode,
            routerConfig: router,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(fakeRepo.getRegisteredClassesCalls, 1);
      expect(find.text('Lịch học'), findsOneWidget);
      expect(find.text('Registered Class'), findsOneWidget);

      await tester.tap(find.text('Registered Class'));
      await tester.pumpAndSettle();

      expect(find.text('DETAIL Registered Class'), findsOneWidget);
    },
  );
}

UserModel _sampleUser() {
  return UserModel(
    id: 'student-1',
    email: 'student@example.com',
    fullName: 'Student Demo',
    role: 'student',
    isActive: true,
    token: 'token-123',
  );
}

class _FakeStudentRemoteRepository extends StudentRemoteRepository {
  final List<ClassSession> upcomingClasses;
  final List<ClassSession> pastClasses;
  int getRegisteredClassesCalls = 0;

  _FakeStudentRemoteRepository({
    this.upcomingClasses = const [],
    this.pastClasses = const [],
  });

  @override
  Future<Either<AppFailure, List<ClassSession>>> getRegisteredClasses(
    String token, {
    bool past = false,
  }) async {
    getRegisteredClassesCalls += 1;
    return Right(past ? pastClasses : upcomingClasses);
  }
}
