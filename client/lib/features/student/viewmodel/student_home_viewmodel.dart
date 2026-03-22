import 'package:client/core/providers/current_user_notifier.dart';
import 'package:client/features/student/model/class_session.dart';
import 'package:client/features/student/model/student_home_state.dart';
import 'package:client/features/student/model/teacher_preview.dart';
import 'package:client/features/student/repositories/student_remote_repository.dart';
import 'package:client/testing/manual_test_mocks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart' show Left, Right;

const _allClassesCategory = 'Tất cả';

final studentHomeViewModelProvider =
    NotifierProvider<StudentHomeViewModel, StudentHomeState>(
      StudentHomeViewModel.new,
    );

class StudentHomeViewModel extends Notifier<StudentHomeState> {
  @override
  StudentHomeState build() {
    final user = ref.watch(currentUserProvider);
    final initialClasses = ManualTestMocks.enabled
        ? ManualTestMocks.mockClasses
        : const <ClassSession>[];
    if (user != null) {
      Future.microtask(() => _loadClasses(user.token));
    }
    return StudentHomeState(
      classes: initialClasses,
      teachers: ManualTestMocks.enabled
          ? ManualTestMocks.mockTeachers
          : const [],
      categories: _buildCategories(initialClasses),
      selectedCategory: _allClassesCategory,
      isLoading: user != null,
    );
  }

  Future<void> _loadClasses(
    String token, {
    String? topic,
    List<String>? preservedCategories,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    final repo = ref.read(studentRemoteRepositoryProvider);
    final result = await repo.getUpcomingClasses(token, topic: topic);
    switch (result) {
      case Left(value: final failure):
        if (ManualTestMocks.enabled) {
          final mockClasses = ManualTestMocks.mockClasses;
          state = state.copyWith(
            isLoading: false,
            classes: mockClasses,
            categories: preservedCategories ?? _buildCategories(mockClasses),
            error: null,
            teachers: ManualTestMocks.mockTeachers,
          );
          return;
        }
        state = state.copyWith(isLoading: false, error: failure.message);
      case Right(value: final classes):
        final resolvedClasses = classes.isEmpty && ManualTestMocks.enabled
            ? ManualTestMocks.mockClasses
            : classes;
        final resolvedTeachers = _mapTeachers(resolvedClasses);
        final categories =
            preservedCategories ?? _buildCategories(resolvedClasses);
        final selectedCategory = categories.contains(state.selectedCategory)
            ? state.selectedCategory
            : _allClassesCategory;
        state = state.copyWith(
          isLoading: false,
          classes: resolvedClasses,
          teachers: resolvedTeachers.isEmpty && ManualTestMocks.enabled
              ? ManualTestMocks.mockTeachers
              : resolvedTeachers,
          categories: categories,
          selectedCategory: selectedCategory,
        );
    }
  }

  void selectCategory(String category) {
    state = state.copyWith(selectedCategory: category);
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final topic = category == _allClassesCategory ? null : category;
    _loadClasses(
      user.token,
      topic: topic,
      preservedCategories: topic == null ? null : state.categories,
    );
  }

  List<String> _buildCategories(List<ClassSession> classes) {
    final uniqueTopics = <String>{};
    for (final session in classes) {
      for (final tag in session.tags) {
        final trimmed = tag.trim();
        if (trimmed.isNotEmpty) {
          uniqueTopics.add(trimmed);
        }
      }
    }
    return [_allClassesCategory, ...uniqueTopics];
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
