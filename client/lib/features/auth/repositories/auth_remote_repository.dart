// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';

import 'package:client/core/constants/server_constant.dart';
import 'package:client/core/failure/failure.dart';
import 'package:client/features/auth/model/user_model.dart';
import 'package:fpdart/fpdart.dart';
import 'package:http/http.dart' as http;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth_remote_repository.g.dart';

@riverpod
AuthRemoteRepository authRemoteRepository(Ref ref) {
  return AuthRemoteRepository();
}

class AuthRemoteRepository {
  static const _requestTimeout = Duration(seconds: 15);

  Future<Either<AppFailure, UserModel>> signup({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('${ServerConstant.serverURL}/auth/signup'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'full_name': name,
              'email': email,
              'password': password,
              'role': role,
            }),
          )
          .timeout(_requestTimeout);

      final resBodyMap = _decodeResponseBody(response.body);

      if (response.statusCode != 201) {
        return Left(
          AppFailure(
            resBodyMap['detail']?.toString() ?? 'Đăng ký thất bại',
            response.statusCode,
          ),
        );
      }

      return Right(UserModel.fromMap(resBodyMap));
    } on TimeoutException {
      return Left(
        AppFailure(ServerConstant.connectionHelpText(action: 'đăng ký')),
      );
    } catch (e) {
      return Left(
        AppFailure(_networkFailureMessage(action: 'đăng ký', error: e)),
      );
    }
  }

  Future<Either<AppFailure, UserModel>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('${ServerConstant.serverURL}/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(_requestTimeout);

      final resBodyMap = _decodeResponseBody(response.body);

      if (response.statusCode != 200) {
        return Left(
          AppFailure(
            resBodyMap['detail']?.toString() ?? 'Đăng nhập thất bại',
            response.statusCode,
          ),
        );
      }
      return Right(
        UserModel.fromMap(
          resBodyMap['user'],
        ).copyWith(token: resBodyMap['token']),
      );
    } on TimeoutException {
      return Left(
        AppFailure(ServerConstant.connectionHelpText(action: 'đăng nhập')),
      );
    } catch (e) {
      return Left(
        AppFailure(_networkFailureMessage(action: 'đăng nhập', error: e)),
      );
    }
  }

  Future<Either<AppFailure, UserModel>> getCurrentUserData(String token) async {
    try {
      final response = await http
          .get(
            Uri.parse('${ServerConstant.serverURL}/auth/'),
            headers: {
              'Content-Type': 'application/json',
              'x-auth-token': token,
            },
          )
          .timeout(_requestTimeout);

      final resBodyMap = _decodeResponseBody(response.body);

      if (response.statusCode != 200) {
        return Left(
          AppFailure(
            resBodyMap['detail']?.toString() ??
                'Không thể tải thông tin người dùng',
            response.statusCode,
          ),
        );
      }
      return Right(UserModel.fromMap(resBodyMap).copyWith(token: token));
    } on TimeoutException {
      return Left(
        AppFailure(
          ServerConstant.connectionHelpText(action: 'tải phiên đăng nhập'),
        ),
      );
    } catch (e) {
      return Left(
        AppFailure(
          _networkFailureMessage(action: 'tải phiên đăng nhập', error: e),
        ),
      );
    }
  }

  Map<String, dynamic> _decodeResponseBody(String body) {
    if (body.trim().isEmpty) {
      return const {};
    }

    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    return const {};
  }

  String _networkFailureMessage({
    required String action,
    required Object error,
  }) {
    final raw = error.toString().toLowerCase();
    if (raw.contains('socketexception') ||
        raw.contains('clientexception') ||
        raw.contains('connection refused') ||
        raw.contains('failed host lookup')) {
      return ServerConstant.connectionHelpText(action: action);
    }
    return 'Không thể $action. $error';
  }
}
