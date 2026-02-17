import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:econnect_app/features/auth/data/datasources/auth_api.dart';
import 'package:econnect_app/features/auth/data/repositories/auth_repo_impl.dart';
import 'package:econnect_app/features/auth/domain/entities/user.dart';
import 'package:econnect_app/features/auth/domain/repositories/auth_repo.dart';
import 'package:econnect_app/features/auth/data/datasources/mock_auth_api.dart';
import 'package:econnect_app/features/auth/data/repositories/auth_repo_mock_impl.dart';
import 'auth_state.dart';

final authRepoProvider = Provider<AuthRepo>((ref) {
  // return AuthRepoImpl(AuthApi());
  return AuthRepoMockImpl(MockAuthApi());
});

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>(
  (ref) {
    return AuthController(ref.read(authRepoProvider));
  },
);

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
    if (emailOrPhone.trim().isEmpty)
      return _fail('Vui lòng nhập email/số điện thoại');
    if (password.length < 8) return _fail('Mật khẩu tối thiểu 8 ký tự');
    if (password != confirmPassword)
      return _fail('Mật khẩu xác nhận không khớp');
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
      final msg = e.toString().contains('ACCOUNT_EXISTS')
          ? 'Tài khoản đã tồn tại'
          : 'Đăng ký thất bại. Vui lòng thử lại.';
      _fail(msg);
    }
  }

  Future<void> login({
    required String emailOrPhone,
    required String password,
  }) async {
    if (emailOrPhone.trim().isEmpty)
      return _fail('Vui lòng nhập email/số điện thoại');
    if (password.isEmpty) return _fail('Vui lòng nhập mật khẩu');

    state = state.copyWith(loading: true, error: null);

    try {
      await _repo.login(emailOrPhone: emailOrPhone.trim(), password: password);
      final role = await _repo.getSavedRole();
      state = state.copyWith(loading: false, loggedIn: true, role: role);
    } catch (e) {
      final msg =
          e.toString().contains('WRONG_PASSWORD') ||
              e.toString().contains('NOT_FOUND')
          ? 'Sai tài khoản hoặc mật khẩu'
          : 'Đăng nhập thất bại. Vui lòng thử lại.';
      _fail(msg);
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
