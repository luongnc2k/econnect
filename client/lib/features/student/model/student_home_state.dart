import 'package:client/features/student/model/class_session.dart';
import 'package:client/features/student/model/teacher_preview.dart';

class StudentHomeState {
  final List<ClassSession> classes;
  final List<TeacherPreview> teachers;
  final List<String> categories;
  final String selectedCategory;
  final bool isLoading;
  final String? error;

  const StudentHomeState({
    required this.classes,
    required this.teachers,
    required this.categories,
    required this.selectedCategory,
    this.isLoading = false,
    this.error,
  });

  StudentHomeState copyWith({
    List<ClassSession>? classes,
    List<TeacherPreview>? teachers,
    List<String>? categories,
    String? selectedCategory,
    bool? isLoading,
    String? error,
  }) {
    return StudentHomeState(
      classes: classes ?? this.classes,
      teachers: teachers ?? this.teachers,
      categories: categories ?? this.categories,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}
