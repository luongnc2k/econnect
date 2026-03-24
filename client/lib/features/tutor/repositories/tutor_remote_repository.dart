import 'dart:convert';
import 'dart:typed_data';

import 'package:client/core/constants/server_constant.dart';
import 'package:client/core/failure/failure.dart';
import 'package:client/core/network/dio_provider.dart';
import 'package:client/core/network/multipart_file_helper.dart';
import 'package:client/features/student/model/class_session.dart';
import 'package:client/features/student/model/class_session_mapper.dart';
import 'package:client/features/tutor/model/enrolled_student.dart';
import 'package:client/features/tutor/model/learning_location.dart';
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
      final uri = Uri.parse(
        '${ServerConstant.serverURL}/classes/my',
      ).replace(queryParameters: {'past': past.toString()});
      final response = await http.get(uri, headers: {'x-auth-token': token});

      if (response.statusCode != 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return Left(
          AppFailure(body['detail'] ?? 'Loi tai du lieu', response.statusCode),
        );
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

  Future<Either<AppFailure, Map<String, dynamic>>> createClass(
    String token,
    Map<String, dynamic> body,
  ) async {
    try {
      final uri = Uri.parse('${ServerConstant.serverURL}/classes');
      final response = await http.post(
        uri,
        headers: {'x-auth-token': token, 'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode != 201) {
        return Left(
          AppFailure(
            decoded['detail'] ?? 'Tao buoi hoc that bai',
            response.statusCode,
          ),
        );
      }

      return Right(decoded);
    } catch (e) {
      return Left(AppFailure(e.toString()));
    }
  }

  Future<Either<AppFailure, List<LearningLocation>>> getLearningLocations(
    String token,
  ) async {
    try {
      final uri = Uri.parse('${ServerConstant.serverURL}/locations');
      final response = await http.get(uri, headers: {'x-auth-token': token});

      if (response.statusCode != 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return Left(
          AppFailure(
            body['detail'] ?? 'Loi tai danh sach dia diem hoc',
            response.statusCode,
          ),
        );
      }

      final list = jsonDecode(response.body) as List<dynamic>;
      return Right(
        list
            .map(
              (item) => LearningLocation.fromMap(item as Map<String, dynamic>),
            )
            .where((location) => location.id.isNotEmpty)
            .toList(),
      );
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
        return Left(
          AppFailure(
            body['detail'] ?? 'Loi tai chi tiet lop',
            response.statusCode,
          ),
        );
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
        'file': await buildUploadMultipartFile(
          fileName: fileName,
          fileBytes: fileBytes,
          filePath: filePath,
        ),
      });

      final response = await _dio.post(
        '/upload/thumbnail',
        data: formData,
        options: Options(headers: {'x-auth-token': token}),
      );

      final data = response.data;
      if (response.statusCode == 200 &&
          data is Map<String, dynamic> &&
          data['url'] != null) {
        return Right(data['url'].toString());
      }

      return Left(AppFailure('Upload anh that bai'));
    } on DioException catch (e) {
      final detail = (e.response?.data as Map<String, dynamic>?)?['detail'];
      return Left(
        AppFailure(detail?.toString() ?? e.message ?? 'Upload anh that bai'),
      );
    } catch (e) {
      return Left(AppFailure(e.toString()));
    }
  }
}
