import 'package:client/core/failure/failure.dart';
import 'package:client/core/providers/current_user_notifier.dart';
import 'package:client/core/theme/theme.dart';
import 'package:client/features/auth/model/user_model.dart';
import 'package:client/features/search/view/screens/class_search_screen.dart';
import 'package:client/features/student/model/class_session.dart';
import 'package:client/features/student/repositories/student_remote_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

void main() {
  testWidgets('class search debounces typing before loading classes', (
    tester,
  ) async {
    final fakeRepo = _FakeStudentRemoteRepository(
      upcomingResults: {
        'english': [_sampleClassSession(title: 'English Debounced Class')],
      },
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWithValue(_sampleCurrentUser()),
          studentRemoteRepositoryProvider.overrideWithValue(fakeRepo),
        ],
        child: MaterialApp(
          theme: AppTheme.lightThemeMode,
          home: const Scaffold(body: ClassSearchScreen()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Tìm theo mã lớp hoặc tên lớp'), findsOneWidget);
    fakeRepo.upcomingQueries.clear();

    await tester.enterText(find.byType(TextField), 'e');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(find.byType(TextField), 'en');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(find.byType(TextField), 'english');
    await tester.pump(const Duration(milliseconds: 349));

    expect(fakeRepo.upcomingQueries, isEmpty);

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();

    expect(fakeRepo.upcomingQueries, ['english']);
    expect(find.text('English Debounced Class'), findsOneWidget);
  });
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

ClassSession _sampleClassSession({required String title}) {
  return ClassSession(
    id: 'class-${title.toLowerCase().replaceAll(' ', '-')}',
    classCode: 'CLS-260325-ABCD',
    title: title,
    location: 'Cafe A',
    teacherId: 'teacher-1',
    teacherName: 'Tutor Demo',
    timeText: '18:00 - 20:00',
    priceText: '50000 VND',
    statusText: 'OPEN',
    tags: const ['Speaking'],
  );
}

class _FakeStudentRemoteRepository extends StudentRemoteRepository {
  final Map<String, List<ClassSession>> upcomingResults;
  final List<String> upcomingQueries = [];

  _FakeStudentRemoteRepository({this.upcomingResults = const {}});

  @override
  Future<Either<AppFailure, List<ClassSession>>> getUpcomingClasses(
    String token, {
    String? topic,
    String? query,
  }) async {
    final normalizedQuery = query?.trim() ?? '';
    upcomingQueries.add(normalizedQuery);
    return Right(upcomingResults[normalizedQuery] ?? const []);
  }
}
