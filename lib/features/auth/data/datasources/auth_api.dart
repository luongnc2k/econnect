import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/endpoints.dart';
import '../models/auth_response.dart';

class AuthApi {
  final Dio _dio;
  AuthApi({Dio? dio}) : _dio = dio ?? ApiClient.dio;

  Future<void> register({
    required String fullName,
    required String emailOrPhone,
    required String password,
    required String role, // 'tutor' | 'student'
  }) async {
    await _dio.post(
      Endpoints.register,
      data: {
        'fullName': fullName,
        'emailOrPhone': emailOrPhone,
        'password': password,
        'role': role,
      },
    );
  }

  Future<AuthResponse> login({
    required String emailOrPhone,
    required String password,
  }) async {
    final res = await _dio.post(
      Endpoints.login,
      data: {
        'emailOrPhone': emailOrPhone,
        'password': password,
      },
    );
    return AuthResponse.fromJson(res.data as Map<String, dynamic>);
  }
}
