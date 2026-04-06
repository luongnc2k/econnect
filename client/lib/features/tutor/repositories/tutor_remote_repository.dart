import 'dart:convert';
import 'dart:typed_data';

import 'package:client/core/constants/server_constant.dart';
import 'package:client/core/failure/failure.dart';
import 'package:client/core/network/dio_provider.dart';
import 'package:client/features/student/model/class_session.dart';
import 'package:client/features/student/model/class_session_mapper.dart';
import 'package:client/features/tutor/model/enrolled_student.dart';
import 'package:client/features/tutor/model/teacher_income_model.dart';
import 'package:client/features/tutor/model/topic_model.dart';
import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

final tutorRemoteRepositoryProvider = Provider((ref) {
  final dio = ref.watch(dioProvider);
  return TutorRemoteRepository(dio);
});

class TutorRemoteRepository {
  final Dio _dio;

  TutorRemoteRepository(this._dio);

  Future<Either<AppFailure, List<ClassSession>>> getMyClasses(
    String token, {
    bool past = false,
  }) async {
    try {
      final uri = Uri.parse('${ServerConstant.serverURL}/classes/my')
          .replace(queryParameters: {'past': past.toString()});
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

  Future<Either<AppFailure, TeacherIncomeModel>> getIncomeStats(
    String token,
  ) async {
    try {
      final uri = Uri.parse('${ServerConstant.serverURL}/classes/income');
      final response = await http.get(uri, headers: {'x-auth-token': token});

      if (response.statusCode != 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return Left(AppFailure(body['detail'] ?? 'Lỗi tải dữ liệu thu nhập', response.statusCode));
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return Right(TeacherIncomeModel.fromMap(data));
    } catch (e) {
      return Left(AppFailure(e.toString()));
    }
  }

  Future<Either<AppFailure, List<TopicModel>>> getTopics() async {
    try {
      final uri = Uri.parse('${ServerConstant.serverURL}/topics');
      final response = await http.get(uri);

      if (response.statusCode != 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return Left(AppFailure(body['detail'] ?? 'Lỗi tải danh sách chủ đề', response.statusCode));
      }

      final list = jsonDecode(response.body) as List<dynamic>;
      final topics = list.map((e) => TopicModel.fromMap(e as Map<String, dynamic>)).toList();
      return Right(topics);
    } catch (e) {
      return Left(AppFailure(e.toString()));
    }
  }

  Future<Either<AppFailure, Map<String, dynamic>>> createClass(
    String token,
    Map<String, dynamic> body,
  ) async {
    try {
      final uri = Uri.parse('${ServerConstant.serverURL}/classes');
      final response = await http.post(
        uri,
        headers: {
          'x-auth-token': token,
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode != 201) {
        return Left(AppFailure(decoded['detail'] ?? 'Tạo lớp học thất bại', response.statusCode));
      }

      return Right(decoded);
    } catch (e) {
      return Left(AppFailure(e.toString()));
    }
  }

  Future<Either<AppFailure, List<EnrolledStudent>>> getClassDetail(
    String token,
    String classId,
  ) async {
    try {
      final uri = Uri.parse('${ServerConstant.serverURL}/classes/$classId');
      final response = await http.get(uri, headers: {'x-auth-token': token});

      if (response.statusCode != 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return Left(AppFailure(body['detail'] ?? 'Lỗi tải chi tiết lớp', response.statusCode));
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final list = data['enrolled_students'] as List<dynamic>;
      final students = list
          .map((e) => EnrolledStudent.fromMap(e as Map<String, dynamic>))
          .toList();
      return Right(students);
    } catch (e) {
      return Left(AppFailure(e.toString()));
    }
  }

  Future<Either<AppFailure, String>> uploadThumbnail({
    required String token,
    required String fileName,
    required Uint8List fileBytes,
    String? filePath,
  }) async {
    try {
      final formData = FormData.fromMap({
        'file': filePath != null
            ? await MultipartFile.fromFile(filePath, filename: fileName)
            : MultipartFile.fromBytes(fileBytes, filename: fileName),
      });

      final response = await _dio.post(
        '/upload/thumbnail',
        data: formData,
        options: Options(headers: {'x-auth-token': token}),
      );

      final data = response.data;
      if (response.statusCode == 200 && data is Map<String, dynamic> && data['url'] != null) {
        return Right(data['url'].toString());
      }

      return Left(AppFailure('Upload ảnh thất bại'));
    } on DioException catch (e) {
      final detail = (e.response?.data as Map<String, dynamic>?)?['detail'];
      return Left(AppFailure(detail?.toString() ?? e.message ?? 'Upload ảnh thất bại'));
    } catch (e) {
      return Left(AppFailure(e.toString()));
    }
  }
}
