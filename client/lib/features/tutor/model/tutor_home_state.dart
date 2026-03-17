import 'package:client/features/student/model/class_session.dart';
import 'package:client/features/tutor/model/teacher_income_model.dart';

class TutorHomeState {
  final List<ClassSession> upcomingClasses;
  final List<ClassSession> pastClasses;
  final TeacherIncomeModel? income;
  final bool isLoading;
  final bool isLoadingPast;
  final bool isLoadingIncome;
  final String? error;

  const TutorHomeState({
    this.upcomingClasses = const [],
    this.pastClasses = const [],
    this.income,
    this.isLoading = false,
    this.isLoadingPast = false,
    this.isLoadingIncome = false,
    this.error,
  });

  TutorHomeState copyWith({
    List<ClassSession>? upcomingClasses,
    List<ClassSession>? pastClasses,
    TeacherIncomeModel? income,
    bool? isLoading,
    bool? isLoadingPast,
    bool? isLoadingIncome,
    String? error,
    bool clearError = false,
  }) =>
      TutorHomeState(
        upcomingClasses: upcomingClasses ?? this.upcomingClasses,
        pastClasses: pastClasses ?? this.pastClasses,
        income: income ?? this.income,
        isLoading: isLoading ?? this.isLoading,
        isLoadingPast: isLoadingPast ?? this.isLoadingPast,
        isLoadingIncome: isLoadingIncome ?? this.isLoadingIncome,
        error: clearError ? null : (error ?? this.error),
      );
}
