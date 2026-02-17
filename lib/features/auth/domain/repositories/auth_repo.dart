import '../entities/user.dart';

abstract class AuthRepo {
  Future<void> register({
    required String fullName,
    required String emailOrPhone,
    required String password,
    required UserRole role,
  });

  Future<void> login({
    required String emailOrPhone,
    required String password,
  });

  Future<void> logout();

  Future<UserRole?> getSavedRole();
  Future<bool> hasToken();
}
