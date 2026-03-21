import 'dart:convert';

import 'package:client/core/constants/server_constant.dart';
import 'package:client/core/failure/failure.dart';
import 'package:client/features/student/model/class_session.dart';
import 'package:client/features/student/model/class_session_mapper.dart';
import 'package:fpdart/fpdart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

final studentRemoteRepositoryProvider = Provider<StudentRemoteRepository>(
  (_) => StudentRemoteRepository(),
);

class StudentRemoteRepository {
  Future<Either<AppFailure, List<ClassSession>>> getUpcomingClasses(
    String token, {
    String? topic,
    String? query,
  }) async {
    try {
      final queryParameters = <String, String>{};
      if (topic != null && topic.isNotEmpty) {
        queryParameters['topic'] = topic;
      }
      if (query != null && query.trim().isNotEmpty) {
        queryParameters['q'] = query.trim();
      }

      final uri = Uri.parse('${ServerConstant.serverURL}/classes/upcoming').replace(
        queryParameters: queryParameters.isEmpty ? null : queryParameters,
      );

      final response = await http.get(uri, headers: {'x-auth-token': token});

      if (response.statusCode != 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return Left(AppFailure(body['detail'] ?? 'Lỗi tải dữ liệu', response.statusCode));
      }

      final list = jsonDecode(response.body) as List<dynamic>;
      final classes = list
          .map((e) => ClassSessionMapper.fromMap(e as Map<String, dynamic>))
          .toList();

      return Right(classes);
    } catch (e) {
      return Left(AppFailure(e.toString()));
    }
  }

  Future<Either<AppFailure, ClassSession>> getClassByCode(
    String token,
    String classCode,
  ) async {
    try {
      final normalizedCode = classCode.trim().toUpperCase();
      final uri = Uri.parse(
        '${ServerConstant.serverURL}/classes/by-code/$normalizedCode',
      );

      final response = await http.get(uri, headers: {'x-auth-token': token});

      if (response.statusCode != 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return Left(AppFailure(body['detail'] ?? 'Khong tim thay lop hoc', response.statusCode));
      }

      final map = jsonDecode(response.body) as Map<String, dynamic>;
      return Right(ClassSessionMapper.fromMap(map));
    } catch (e) {
      return Left(AppFailure(e.toString()));
    }
  }
}
