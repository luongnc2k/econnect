import 'package:client/features/student/model/student_home_state.dart';
import 'package:client/features/student/repositories/student_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const studentHomeCategories = [
  'Gần bạn',
  'Hôm nay',
  'Giao tiếp',
  'IELTS',
  'Cơ bản',
];

final studentHomeViewModelProvider =
    NotifierProvider<StudentHomeViewModel, StudentHomeState>(
  StudentHomeViewModel.new,
);

class StudentHomeViewModel extends Notifier<StudentHomeState> {
  @override
  StudentHomeState build() {
    final repo = ref.watch(studentRepositoryProvider);
    return StudentHomeState(
      classes: repo.getClasses(),
      teachers: repo.getFeaturedTeachers(),
      selectedCategory: studentHomeCategories.first,
    );
  }

  void selectCategory(String category) {
    state = state.copyWith(selectedCategory: category);
  }
}
