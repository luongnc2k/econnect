import 'dart:async';

import 'package:client/core/providers/current_user_notifier.dart';
import 'package:client/features/tutor/model/tutor_home_state.dart';
import 'package:client/features/tutor/repositories/tutor_remote_repository.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart' show Left, Right;

final tutorHomeViewModelProvider =
    NotifierProvider<TutorHomeViewModel, TutorHomeState>(
      TutorHomeViewModel.new,
    );

class TutorHomeViewModel extends Notifier<TutorHomeState>
    with WidgetsBindingObserver {
  bool _observerRegistered = false;
  bool _resumeRefreshInFlight = false;

  @override
  TutorHomeState build() {
    ref.onDispose(_dispose);
    _registerLifecycleObserver();
    final user = ref.watch(currentUserProvider);
    if (user != null) {
      Future.microtask(() => _loadAll(user.token));
    }
    return const TutorHomeState(isLoading: true, isLoadingPast: true);
  }

  Future<void> _loadAll(String token, {bool silent = false}) async {
    await Future.wait([
      _loadUpcoming(token, silent: silent),
      _loadPast(token, silent: silent),
    ]);
  }

  Future<void> _loadUpcoming(String token, {bool silent = false}) async {
    state = silent
        ? state.copyWith(clearError: true)
        : state.copyWith(isLoading: true, clearError: true);
    final repo = ref.read(tutorRemoteRepositoryProvider);
    final result = await repo.getMyClasses(token, past: false);
    switch (result) {
      case Left(value: final failure):
        state = state.copyWith(isLoading: false, error: failure.message);
      case Right(value: final classes):
        state = state.copyWith(isLoading: false, upcomingClasses: classes);
    }
  }

  Future<void> _loadPast(String token, {bool silent = false}) async {
    if (!silent) {
      state = state.copyWith(isLoadingPast: true);
    }
    final repo = ref.read(tutorRemoteRepositoryProvider);
    final result = await repo.getMyClasses(token, past: true);
    switch (result) {
      case Left():
        state = state.copyWith(isLoadingPast: false);
      case Right(value: final classes):
        state = state.copyWith(isLoadingPast: false, pastClasses: classes);
    }
  }

  Future<void> refresh({bool silent = false}) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    await _loadAll(user.token, silent: silent);
  }

  void _registerLifecycleObserver() {
    if (_observerRegistered) {
      return;
    }
    WidgetsBinding.instance.addObserver(this);
    _observerRegistered = true;
  }

  void _dispose() {
    if (!_observerRegistered) {
      return;
    }
    WidgetsBinding.instance.removeObserver(this);
    _observerRegistered = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || _resumeRefreshInFlight) {
      return;
    }

    final user = ref.read(currentUserProvider);
    if (user == null) {
      return;
    }

    _resumeRefreshInFlight = true;
    unawaited(
      refresh(silent: true).whenComplete(() {
        _resumeRefreshInFlight = false;
      }),
    );
  }
}
