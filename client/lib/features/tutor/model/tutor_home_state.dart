import 'package:client/features/student/model/class_session.dart';
import 'package:client/features/student/model/teacher_preview.dart';

class TutorHomeState {
  final List<ClassSession> upcomingClasses;
  final List<ClassSession> pastClasses;
  final List<TeacherPreview> featuredTeachers;
  final bool isLoading;
  final bool isLoadingPast;
  final String? error;

  const TutorHomeState({
    this.upcomingClasses = const [],
    this.pastClasses = const [],
    this.featuredTeachers = const [],
    this.isLoading = false,
    this.isLoadingPast = false,
    this.error,
  });

  TutorHomeState copyWith({
    List<ClassSession>? upcomingClasses,
    List<ClassSession>? pastClasses,
    List<TeacherPreview>? featuredTeachers,
    bool? isLoading,
    bool? isLoadingPast,
    String? error,
    bool clearError = false,
  }) => TutorHomeState(
    upcomingClasses: upcomingClasses ?? this.upcomingClasses,
    pastClasses: pastClasses ?? this.pastClasses,
    featuredTeachers: featuredTeachers ?? this.featuredTeachers,
    isLoading: isLoading ?? this.isLoading,
    isLoadingPast: isLoadingPast ?? this.isLoadingPast,
    error: clearError ? null : (error ?? this.error),
  );
}
