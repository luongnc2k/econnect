import 'package:client/core/failure/failure.dart';
import 'package:client/core/providers/current_user_notifier.dart';
import 'package:client/core/router/app_router.dart';
import 'package:client/core/theme/theme.dart';
import 'package:client/features/auth/model/user_model.dart';
import 'package:client/features/schedule/view/widgets/schedule_calendar.dart';
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
    'student schedule screen shows upcoming classes without mini calendar and opens detail',
    (tester) async {
      final today = ScheduleCalendar.dateOnly(DateTime.now());
      final alternateDate = today.weekday == DateTime.sunday
          ? today.subtract(const Duration(days: 1))
          : today.add(const Duration(days: 1));
      final fakeRepo = _FakeStudentRemoteRepository(
        upcomingClasses: [
          ClassSession(
            id: 'class-1',
            classCode: 'CLS-260324-ABCD',
            title: 'Today Class',
            location: 'Cafe A',
            teacherId: 'teacher-1',
            teacherName: 'Tutor Demo',
            timeText: '18:00 Hôm nay',
            priceText: '50000 VND',
            statusText: 'OPEN',
            tags: const ['Speaking'],
            startDateTime: today.add(const Duration(hours: 18)),
            endDateTime: today.add(const Duration(hours: 20)),
          ),
          ClassSession(
            id: 'class-2',
            classCode: 'CLS-260325-ABCD',
            title: 'Alternate Day Class',
            location: 'Cafe B',
            teacherId: 'teacher-1',
            teacherName: 'Tutor Demo',
            timeText: '19:00',
            priceText: '50000 VND',
            statusText: 'OPEN',
            tags: const ['Grammar'],
            startDateTime: alternateDate.add(const Duration(hours: 19)),
            endDateTime: alternateDate.add(const Duration(hours: 21)),
          ),
        ],
      );
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) =>
                const Scaffold(body: StudentScheduleScreen()),
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
      expect(find.text('Today Class'), findsOneWidget);
      expect(find.text('Alternate Day Class'), findsOneWidget);
      expect(find.text('Tuần'), findsNothing);
      expect(find.text('Tháng'), findsNothing);

      await tester.tap(find.text('Alternate Day Class'));
      await tester.pumpAndSettle();

      expect(find.text('DETAIL Alternate Day Class'), findsOneWidget);
    },
  );

  testWidgets('student past schedule calendar fits a narrow phone viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final today = ScheduleCalendar.dateOnly(DateTime.now());
    final pastDate = today.subtract(const Duration(days: 2));
    final fakeRepo = _FakeStudentRemoteRepository(
      pastClasses: [
        ClassSession(
          id: 'past-class-1',
          classCode: 'CLS-260301-PAST',
          title: 'Past Class',
          location: 'Cafe C',
          teacherId: 'teacher-1',
          teacherName: 'Tutor Demo',
          timeText: '18:00',
          priceText: '50000 VND',
          statusText: 'DONE',
          tags: const ['Review'],
          startDateTime: pastDate.add(const Duration(hours: 18)),
          endDateTime: pastDate.add(const Duration(hours: 20)),
        ),
      ],
    );
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) =>
              const Scaffold(body: StudentScheduleScreen()),
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

    await tester.tap(find.text('Đã học'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Tuần'), findsOneWidget);
    expect(find.text('Tháng'), findsOneWidget);

    await tester.tap(find.text('Tháng'));
    await tester.pumpAndSettle();

    expect(find.byType(ScheduleCalendar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
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
