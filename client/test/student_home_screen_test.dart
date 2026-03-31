import 'package:client/core/failure/failure.dart';
import 'package:client/core/providers/current_user_notifier.dart';
import 'package:client/core/theme/theme.dart';
import 'package:client/features/auth/model/user_model.dart';
import 'package:client/features/student/model/class_session.dart';
import 'package:client/features/student/model/teacher_preview.dart';
import 'package:client/features/student/repositories/student_remote_repository.dart';
import 'package:client/features/student/view/screens/student_home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

void main() {
  testWidgets('student home shows top featured teachers from dedicated feed', (
    tester,
  ) async {
    final fakeRepo = _FakeStudentRemoteRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWithValue(_sampleUser()),
          studentRemoteRepositoryProvider.overrideWithValue(fakeRepo),
        ],
        child: MaterialApp(
          theme: AppTheme.lightThemeMode,
          home: const Scaffold(body: StudentHomeScreen()),
        ),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    expect(fakeRepo.getUpcomingClassesCalls, 1);
    expect(fakeRepo.getFeaturedTeachersCalls, 1);
    expect(find.text('Giảng viên nổi bật'), findsOneWidget);
    expect(find.text('Tutor Top 1'), findsNWidgets(2));
    expect(find.text('Tutor Top 2'), findsOneWidget);
    expect(find.text('TOP 1'), findsOneWidget);
    expect(find.text('TOP 2'), findsOneWidget);
    expect(find.text('120 buổi dạy'), findsOneWidget);
    expect(find.text('95 buổi dạy'), findsOneWidget);
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
  int getUpcomingClassesCalls = 0;
  int getFeaturedTeachersCalls = 0;

  @override
  Future<Either<AppFailure, List<ClassSession>>> getUpcomingClasses(
    String token, {
    String? topic,
    String? query,
  }) async {
    getUpcomingClassesCalls += 1;
    return const Right([
      ClassSession(
        id: 'class-1',
        classCode: 'CLS-260330-AAAA',
        title: 'English Speaking',
        location: 'Cafe A',
        locationAddress: '123 Main Street',
        teacherId: 'teacher-1',
        teacherName: 'Tutor Top 1',
        timeText: '18:00 Hôm nay',
        priceText: '50.000đ',
        statusText: 'OPEN',
        tags: ['IELTS'],
      ),
    ]);
  }

  @override
  Future<Either<AppFailure, List<TeacherPreview>>> getFeaturedTeachers(
    String token, {
    int limit = 5,
  }) async {
    getFeaturedTeachersCalls += 1;
    return const Right([
      TeacherPreview(
        id: 'teacher-1',
        name: 'Tutor Top 1',
        subtitle: 'IELTS',
        rating: 4.9,
        reviewCount: 54,
        sessionCount: 120,
        specialties: ['IELTS'],
        badgeText: 'TOP 1',
      ),
      TeacherPreview(
        id: 'teacher-2',
        name: 'Tutor Top 2',
        subtitle: 'Business English',
        rating: 4.8,
        reviewCount: 41,
        sessionCount: 95,
        specialties: ['Business English'],
        badgeText: 'TOP 2',
      ),
    ]);
  }
}
