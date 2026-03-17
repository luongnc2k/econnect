import 'package:client/features/student/model/class_session.dart';

class TutorHomeState {
  final List<ClassSession> upcomingClasses;
  final bool isLoading;
  final String? error;

  const TutorHomeState({
    this.upcomingClasses = const [],
    this.isLoading = false,
    this.error,
  });

  TutorHomeState copyWith({
    List<ClassSession>? upcomingClasses,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) =>
      TutorHomeState(
        upcomingClasses: upcomingClasses ?? this.upcomingClasses,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
      );
}
