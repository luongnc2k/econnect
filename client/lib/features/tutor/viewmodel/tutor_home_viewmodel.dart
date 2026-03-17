import 'package:client/core/providers/current_user_notifier.dart';
import 'package:client/features/tutor/model/tutor_home_state.dart';
import 'package:client/features/tutor/repositories/tutor_remote_repository.dart';
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
      Future.microtask(() => _loadAll(user.token));
    }
    return const TutorHomeState(isLoading: true, isLoadingPast: true);
  }

  Future<void> _loadAll(String token) async {
    await Future.wait([
      _loadUpcoming(token),
      _loadPast(token),
    ]);
  }

  Future<void> _loadUpcoming(String token) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final repo = ref.read(tutorRemoteRepositoryProvider);
    final result = await repo.getMyClasses(token, past: false);
    switch (result) {
      case Left(value: final failure):
        state = state.copyWith(isLoading: false, error: failure.message);
      case Right(value: final classes):
        state = state.copyWith(isLoading: false, upcomingClasses: classes);
    }
  }

  Future<void> _loadPast(String token) async {
    state = state.copyWith(isLoadingPast: true);
    final repo = ref.read(tutorRemoteRepositoryProvider);
    final result = await repo.getMyClasses(token, past: true);
    switch (result) {
      case Left():
        state = state.copyWith(isLoadingPast: false);
      case Right(value: final classes):
        state = state.copyWith(isLoadingPast: false, pastClasses: classes);
    }
  }

  Future<void> refresh() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    await _loadAll(user.token);
  }
}
