/// token storage using flutter_secure_storage

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  SecureStorage._();

  static const _storage = FlutterSecureStorage();
  static const _kToken = 'auth_token';
  static const _kRole = 'auth_role';

  static Future<void> saveAuth({required String token, required String role}) async {
    await _storage.write(key: _kToken, value: token);
    await _storage.write(key: _kRole, value: role);
  }

  static Future<String?> readToken() => _storage.read(key: _kToken);
  static Future<String?> readRole() => _storage.read(key: _kRole);

  static Future<void> clearAuth() async {
    await _storage.delete(key: _kToken);
    await _storage.delete(key: _kRole);
  }
}
