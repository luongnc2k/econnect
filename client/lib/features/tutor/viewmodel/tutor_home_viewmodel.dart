import 'package:client/core/providers/current_user_notifier.dart';
import 'package:client/features/student/repositories/student_remote_repository.dart';
import 'package:client/features/tutor/model/tutor_home_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart' show Left, Right;

final tutorHomeViewModelProvider =
    NotifierProvider<TutorHomeViewModel, TutorHomeState>(
  TutorHomeViewModel.new,
);

class TutorHomeViewModel extends Notifier<TutorHomeState> {
  @override
  TutorHomeState build() {
    final user = ref.watch(currentUserProvider);
    if (user != null) {
      Future.microtask(() => _loadMyClasses(user.token, user.id));
    }
    return const TutorHomeState(isLoading: true);
  }

  Future<void> _loadMyClasses(String token, String teacherId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final repo = ref.read(studentRemoteRepositoryProvider);
    final result = await repo.getUpcomingClasses(token);
    switch (result) {
      case Left(value: final failure):
        state = state.copyWith(isLoading: false, error: failure.message);
      case Right(value: final classes):
        final myClasses =
            classes.where((c) => c.teacherId == teacherId).toList();
        state = state.copyWith(isLoading: false, upcomingClasses: myClasses);
    }
  }

  Future<void> refresh() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    await _loadMyClasses(user.token, user.id);
  }
}
