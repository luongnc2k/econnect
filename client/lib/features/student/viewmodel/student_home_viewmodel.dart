import 'package:client/core/providers/current_user_notifier.dart';
import 'package:client/features/student/model/class_session.dart';
import 'package:client/features/student/model/teacher_preview.dart';
import 'package:client/features/student/model/student_home_state.dart';
import 'package:client/features/student/repositories/student_remote_repository.dart';
import 'package:client/features/student/repositories/student_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart' show Left, Right;

const studentHomeCategories = [
  'Tất cả',
  'Giao tiếp',
  'IELTS',
  'Business',
  'Phát âm',
  'Cơ bản',
];

// topic slug tương ứng với category (null = không filter)
const _categoryTopicSlug = <String, String?>{
  'Tất cả':    null,
  'Giao tiếp': 'giao-tiep',
  'IELTS':     'ielts',
  'Business':  'business',
  'Phát âm':   'phat-am',
  'Cơ bản':    'co-ban',
};

final studentHomeViewModelProvider =
    NotifierProvider<StudentHomeViewModel, StudentHomeState>(
  StudentHomeViewModel.new,
);

class StudentHomeViewModel extends Notifier<StudentHomeState> {
  @override
  StudentHomeState build() {
    final user = ref.watch(currentUserProvider);
    if (user != null) {
      Future.microtask(() => _loadClasses(user.token));
    }
    return StudentHomeState(
      classes: mockClasses,
      teachers: mockTeachers,
      selectedCategory: studentHomeCategories.first,
      isLoading: user != null,
    );
  }

  Future<void> _loadClasses(String token, {String? topicSlug}) async {
    state = state.copyWith(isLoading: true, error: null);
    final repo = ref.read(studentRemoteRepositoryProvider);
    final result = await repo.getUpcomingClasses(token, topic: topicSlug);
    switch (result) {
      case Left(value: final failure):
        state = state.copyWith(
          isLoading: false,
          classes: mockClasses,
          error: null,
          teachers: mockTeachers,
        );
      case Right(value: final classes):
        final teachers = _mapTeachers(classes);
        final resolvedClasses = classes.isEmpty ? mockClasses : classes;
        state = state.copyWith(
          isLoading: false,
          classes: resolvedClasses,
          teachers: teachers.isEmpty ? mockTeachers : teachers,
        );
    }
  }

  void selectCategory(String category) {
    state = state.copyWith(selectedCategory: category);
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final slug = _categoryTopicSlug[category];
    _loadClasses(user.token, topicSlug: slug);
  }

  List<TeacherPreview> _mapTeachers(List<ClassSession> classes) {
    final mapped = <String, TeacherPreview>{};

    for (final session in classes) {
      if (session.teacherId == null || mapped.containsKey(session.teacherId)) {
        continue;
      }

      mapped[session.teacherId!] = TeacherPreview(
        id: session.teacherId!,
        name: session.teacherName,
        subtitle: session.tags.join(', '),
        rating: session.teacherRating ?? 0,
        reviewCount: session.teacherSessionCount ?? 0,
        specialties: session.tags,
        avatarUrl: session.teacherAvatarUrl,
      );
    }

    return mapped.values.toList();
  }
}
