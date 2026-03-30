import 'package:client/core/failure/failure.dart';
import 'package:client/core/providers/current_user_notifier.dart';
import 'package:client/core/theme/theme.dart';
import 'package:client/features/auth/model/user_model.dart';
import 'package:client/features/tutor/model/learning_location.dart';
import 'package:client/features/tutor/repositories/tutor_remote_repository.dart';
import 'package:client/features/tutor/view/screens/create_class_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

void main() {
  testWidgets(
    'create class screen loads learning locations from server response',
    (tester) async {
      final fakeTutorRepo = _FakeTutorRemoteRepository(
        locations: const [
          LearningLocation(
            id: 'loc-1',
            name: 'Remote Location 01',
            address: '12 Nguyen Van Linh',
            notes: 'Tang 2',
            isActive: true,
          ),
          LearningLocation(
            id: 'loc-2',
            name: 'Remote Location 02',
            address: '34 Le Loi',
            notes: null,
            isActive: true,
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWithValue(_sampleUser()),
            tutorRemoteRepositoryProvider.overrideWithValue(fakeTutorRepo),
          ],
          child: MaterialApp(
            theme: AppTheme.lightThemeMode,
            home: const CreateClassScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(fakeTutorRepo.getLearningLocationsCalls, 1);
      expect(find.text('Đang tải danh sách địa điểm học...'), findsNothing);
      expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
    },
  );
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
  final List<LearningLocation> locations;
  int getLearningLocationsCalls = 0;

  _FakeTutorRemoteRepository({required this.locations}) : super(Dio());

  @override
  Future<Either<AppFailure, List<LearningLocation>>> getLearningLocations(
    String token,
  ) async {
    getLearningLocationsCalls += 1;
    return Right(locations);
  }
}
