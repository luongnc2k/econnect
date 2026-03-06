import 'package:client/core/providers/current_user_notifier.dart';
import 'package:client/features/auth/model/user_model.dart';
import 'package:client/features/auth/repositories/auth_local_repository.dart';
import 'package:client/features/auth/repositories/auth_remote_repository.dart';
import 'package:fpdart/fpdart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth_viewmodel.g.dart';

@riverpod
class AuthViewModel extends _$AuthViewModel {
  late AuthRemoteRepository _authRemoteRepository;
  late AuthLocalRepository _authLocalRepository;
  late CurrentUserNotifier _currentUserNotifier;

  @override
  AsyncValue<UserModel>? build() {
    _authRemoteRepository = ref.watch(authRemoteRepositoryProvider);
    _authLocalRepository = ref.watch(authLocalRepositoryProvider);
    _currentUserNotifier = ref.watch(currentUserProvider.notifier);
    return null;
  }

  Future<void> initSharedPreferences() async {
    await _authLocalRepository.init();
  }

  Future<void> signUpUser({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    state = const AsyncValue.loading();
    final res = await _authRemoteRepository.signup(
      name: name,
      email: email,
      password: password,
      role: role,
    );

    switch (res) {
      case Left(value: final l):
        state = AsyncValue.error(l.message, StackTrace.current);
      case Right(value: final r):
        state = AsyncValue.data(r);
    }
  }

  Future<void> loginUser({
    required String email,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    final res = await _authRemoteRepository.login(
      email: email,
      password: password,
    );

    switch (res) {
      case Left(value: final l):
        state = AsyncValue.error(l.message, StackTrace.current);
      case Right(value: final r):
        _loginSuccess(r);
    }
  }

  AsyncValue<UserModel>? _loginSuccess(UserModel user) {
    _authLocalRepository.setToken(user.token);
    _authLocalRepository.setUser(user);
    _currentUserNotifier.addUser(user);
    return state = AsyncValue.data(user);
  }

  Future<void> getData() async {
    final token = _authLocalRepository.getToken();
    if (token == null) {
      state = null;
      return;
    }

    // Khôi phục từ cache NGAY LẬP TỨC trước khi gọi API
    // Tránh trường hợp !ref.mounted sau await khiến user bị reset
    final cached = _authLocalRepository.getUser();
    if (cached != null) {
      _getDataSuccess(cached.copyWith(token: token));
    } else {
      state = const AsyncValue.loading();
    }

    // Validate token với server
    final res = await _authRemoteRepository.getCurrentUserData(token);
    if (!ref.mounted) return;

    switch (res) {
      case Left(value: final _):
        // Server không phản hồi — giữ nguyên cache nếu đã restore
        if (cached == null) state = null;
      case Right(value: final r):
        _getDataSuccess(r);
    }
  }

  AsyncValue<UserModel> _getDataSuccess(UserModel user) {
    _authLocalRepository.setUser(user);
    _currentUserNotifier.addUser(user);
    return state = AsyncValue.data(user);
  }
}
