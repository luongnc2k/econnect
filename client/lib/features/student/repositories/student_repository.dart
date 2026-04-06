import 'package:client/features/student/model/class_session.dart';
import 'package:client/features/student/model/teacher_preview.dart';
import 'package:client/testing/manual_test_mocks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract class StudentRepository {
  List<ClassSession> getClasses();
  List<TeacherPreview> getFeaturedTeachers();
}

final studentRepositoryProvider = Provider<StudentRepository>(
  (ref) => MockStudentRepository(),
);

class MockStudentRepository implements StudentRepository {
  @override
  List<ClassSession> getClasses() => ManualTestMocks.mockClasses;

  @override
  List<TeacherPreview> getFeaturedTeachers() => ManualTestMocks.mockTeachers;
}
