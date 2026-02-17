import '../../../../core/storage/secure_storage.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repo.dart';
import '../datasources/mock_auth_api.dart';

class AuthRepoMockImpl implements AuthRepo {
  final MockAuthApi _api;
  AuthRepoMockImpl(this._api);

  @override
  Future<void> register({
    required String fullName,
    required String emailOrPhone,
    required String password,
    required UserRole role,
  }) {
    return _api.register(
      fullName: fullName,
      emailOrPhone: emailOrPhone,
      password: password,
      role: role.value,
    );
  }

  @override
  Future<void> login({
    required String emailOrPhone,
    required String password,
  }) async {
    final auth = await _api.login(emailOrPhone: emailOrPhone, password: password);
    await SecureStorage.saveAuth(token: auth.token, role: auth.role);
  }

  @override
  Future<void> logout() => SecureStorage.clearAuth();

  @override
  Future<UserRole?> getSavedRole() async {
    final r = await SecureStorage.readRole();
    if (r == null || r.isEmpty) return null;
    return UserRoleX.fromString(r);
  }

  @override
  Future<bool> hasToken() async {
    final t = await SecureStorage.readToken();
    return t != null && t.isNotEmpty;
  }
}
