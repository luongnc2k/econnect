/// implementation of the authentication repository interface
/// This class provides the actual implementation of the authentication repository interface, which is responsible for handling user authentication and related operations. It interacts with the API client to make network requests and uses secure storage to store sensitive information such as tokens.
///

import '../../../../core/storage/secure_storage.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repo.dart';
import '../datasources/auth_api.dart';

class AuthRepoImpl implements AuthRepo {
  final AuthApi _api;
  AuthRepoImpl(this._api);

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
    final auth = await _api.login(
      emailOrPhone: emailOrPhone,
      password: password,
    );
    await SecureStorage.saveAuth(token: auth.token, role: auth.role);
  }

  @override
  Future<void> requestPasswordReset({required String emailOrPhone}) {
    return _api.requestPasswordReset(emailOrPhone: emailOrPhone);
  }

  @override
  Future<void> confirmPasswordReset({
    required String emailOrPhone,
    required String otp,
    required String newPassword,
  }) {
    return _api.confirmPasswordReset(
      emailOrPhone: emailOrPhone,
      otp: otp,
      newPassword: newPassword,
    );
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
