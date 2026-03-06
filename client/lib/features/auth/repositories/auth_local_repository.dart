import 'package:client/features/auth/model/user_model.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'auth_local_repository.g.dart';

@Riverpod(keepAlive: true)
AuthLocalRepository authLocalRepository(Ref ref) {
  return AuthLocalRepository();
}

class AuthLocalRepository {
  static const _tokenKey = 'x-auth-token';
  static const _userKey = 'user';

  late SharedPreferences _sharedPreferences;

  Future<void> init() async {
    _sharedPreferences = await SharedPreferences.getInstance();
  }

  void setToken(String? token) {
    if (token != null) {
      _sharedPreferences.setString(_tokenKey, token);
    }
  }

  String? getToken() {
    return _sharedPreferences.getString(_tokenKey);
  }

  void setUser(UserModel user) {
    _sharedPreferences.setString(_userKey, user.toJson());
  }

  UserModel? getUser() {
    final json = _sharedPreferences.getString(_userKey);
    if (json == null) return null;
    return UserModel.fromJson(json);
  }

  void clearSession() {
    _sharedPreferences.remove(_tokenKey);
    _sharedPreferences.remove(_userKey);
  }
}
