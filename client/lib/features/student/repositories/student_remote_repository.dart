import 'dart:convert';

import 'package:client/core/constants/server_constant.dart';
import 'package:client/core/failure/failure.dart';
import 'package:client/features/student/model/class_session.dart';
import 'package:client/features/student/model/class_session_mapper.dart';
import 'package:fpdart/fpdart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

final studentRemoteRepositoryProvider = Provider((_) => StudentRemoteRepository());

class StudentRemoteRepository {
  Future<Either<AppFailure, List<ClassSession>>> getUpcomingClasses(
    String token, {
    String? topic,
  }) async {
    try {
      final uri = Uri.parse('${ServerConstant.serverURL}/classes/upcoming').replace(
        queryParameters: topic != null ? {'topic': topic} : null,
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
}
