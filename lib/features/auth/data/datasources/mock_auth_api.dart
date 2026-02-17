import '../models/auth_response.dart';

class MockAuthApi {
  // "Database" giả: key = emailOrPhone
  static final Map<String, _MockUser> _users = {};

  Future<void> register({
    required String fullName,
    required String emailOrPhone,
    required String password,
    required String role, // 'tutor' | 'student'
  }) async {
    await Future.delayed(const Duration(milliseconds: 600));

    final key = emailOrPhone.trim().toLowerCase();
    if (_users.containsKey(key)) {
      throw Exception('ACCOUNT_EXISTS');
    }

    _users[key] = _MockUser(
      fullName: fullName.trim(),
      emailOrPhone: key,
      password: password,
      role: role,
    );
  }

  Future<AuthResponse> login({
    required String emailOrPhone,
    required String password,
  }) async {
    await Future.delayed(const Duration(milliseconds: 600));

    final key = emailOrPhone.trim().toLowerCase();
    final user = _users[key];

    if (user == null) {
      throw Exception('NOT_FOUND');
    }
    if (user.password != password) {
      throw Exception('WRONG_PASSWORD');
    }

    // token giả
    final token = 'mock_token_${DateTime.now().millisecondsSinceEpoch}';
    return AuthResponse(token: token, role: user.role);
  }
}

class _MockUser {
  final String fullName;
  final String emailOrPhone;
  final String password;
  final String role;

  _MockUser({
    required this.fullName,
    required this.emailOrPhone,
    required this.password,
    required this.role,
  });
}
