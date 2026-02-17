import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/auth_api.dart';
import '../../data/repositories/auth_repo_impl.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repo.dart';
import 'auth_state.dart';

final authRepoProvider = Provider<AuthRepo>((ref) {
  return AuthRepoImpl(AuthApi());
});

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(ref.read(authRepoProvider));
});

class AuthController extends StateNotifier<AuthState> {
  final AuthRepo _repo;
  AuthController(this._repo) : super(AuthState.initial());

  Future<void> bootstrap() async {
    final has = await _repo.hasToken();
    if (!has) return;
    final role = await _repo.getSavedRole();
    state = state.copyWith(loggedIn: true, role: role);
  }

  Future<void> register({
    required String fullName,
    required String emailOrPhone,
    required String password,
    required String confirmPassword,
    required UserRole? role,
  }) async {
    // Validate
    if (fullName.trim().isEmpty) return _fail('Vui lòng nhập họ tên');
    if (emailOrPhone.trim().isEmpty) return _fail('Vui lòng nhập email/số điện thoại');
    if (password.length < 8) return _fail('Mật khẩu tối thiểu 8 ký tự');
    if (password != confirmPassword) return _fail('Mật khẩu xác nhận không khớp');
    if (role == null) return _fail('Vui lòng chọn vai trò Tutor/Học viên');

    state = state.copyWith(loading: true, error: null);

    try {
      await _repo.register(
        fullName: fullName.trim(),
        emailOrPhone: emailOrPhone.trim(),
        password: password,
        role: role,
      );
      state = state.copyWith(loading: false);
    } catch (e) {
      _fail('Đăng ký thất bại. Vui lòng thử lại.');
    }
  }

  Future<void> login({
    required String emailOrPhone,
    required String password,
  }) async {
    if (emailOrPhone.trim().isEmpty) return _fail('Vui lòng nhập email/số điện thoại');
    if (password.isEmpty) return _fail('Vui lòng nhập mật khẩu');

    state = state.copyWith(loading: true, error: null);

    try {
      await _repo.login(emailOrPhone: emailOrPhone.trim(), password: password);
      final role = await _repo.getSavedRole();
      state = state.copyWith(loading: false, loggedIn: true, role: role);
    } catch (e) {
      _fail('Sai tài khoản hoặc mật khẩu');
    }
  }

  Future<void> logout() async {
    await _repo.logout();
    state = AuthState.initial();
  }

  void clearError() => state = state.copyWith(error: null);

  void _fail(String msg) {
    state = state.copyWith(loading: false, error: msg);
  }
}
