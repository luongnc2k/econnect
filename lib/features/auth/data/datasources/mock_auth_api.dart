import '../models/auth_response.dart';

class MockAuthApi {
  // "Database" giả: key = emailOrPhone
  static final Map<String, _MockUser> _users = {};

  // Lưu OTP tạm thời cho chức năng quên mật khẩu
  static final Map<String, String> _resetOtps = {}; // key=emailOrPhone -> otp

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

 /// Step 1: Request reset -> generate OTP (mock)
  Future<void> requestPasswordReset({required String emailOrPhone}) async {
    await Future.delayed(const Duration(milliseconds: 600));
    final key = emailOrPhone.trim().toLowerCase();
    final user = _users[key];
    if (user == null) throw Exception('NOT_FOUND');

    // OTP mock cố định cho dễ demo, hoặc random 6 số
    const otp = '123456';
    _resetOtps[key] = otp;
  }

  /// Step 2: Confirm OTP + set new password
  Future<void> confirmPasswordReset({
    required String emailOrPhone,
    required String otp,
    required String newPassword,
  }) async {
    await Future.delayed(const Duration(milliseconds: 600));
    final key = emailOrPhone.trim().toLowerCase();
    final user = _users[key];
    if (user == null) throw Exception('NOT_FOUND');

    final savedOtp = _resetOtps[key];
    if (savedOtp == null) throw Exception('OTP_NOT_REQUESTED');
    if (savedOtp != otp) throw Exception('OTP_INVALID');

    user.password = newPassword;
    _resetOtps.remove(key);
  }
}

class _MockUser {
  final String fullName;
  final String emailOrPhone;
  String password;
  final String role;

  _MockUser({
    required this.fullName,
    required this.emailOrPhone,
    required this.password,
    required this.role,
  });
}
