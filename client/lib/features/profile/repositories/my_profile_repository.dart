import 'dart:typed_data';

import 'package:client/core/network/dio_provider.dart';
import 'package:client/core/providers/current_user_notifier.dart';
import 'package:client/features/auth/model/user_model.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../model/student_my_profile_model.dart';
import '../model/teacher_my_profile_model.dart';

abstract class IMyProfileRepository {
  Future<UserModel> getMyProfile();
  Future<UserModel> updateMyProfile(UserModel profile);
  Future<String> uploadMyAvatar({
    required String fileName,
    required Uint8List fileBytes,
    String? filePath,
  });
}

class MyProfileRepository implements IMyProfileRepository {
  final Ref ref;
  final Dio dio;

  MyProfileRepository(this.ref, this.dio);

  @override
  Future<UserModel> getMyProfile() async {
    final currentUser = ref.read(currentUserProvider);
    final token = currentUser?.token ?? '';

    if (token.isEmpty) {
      throw Exception('Thieu token dang nhap');
    }

    final response = await dio.get(
      '/profile/me',
      options: Options(
        headers: {'x-auth-token': token},
      ),
    );

    final data = response.data;
    if (response.statusCode != 200 || data is! Map<String, dynamic>) {
      throw Exception('Khong the tai ho so');
    }

    final mapped = {...data, 'token': token};
    final profile = _mapProfile(mapped);

    ref.read(currentUserProvider.notifier).setUser(
          UserModel.fromMap(mapped).copyWith(token: token),
        );

    return profile;
  }

  @override
  Future<UserModel> updateMyProfile(UserModel profile) async {
    final currentUser = ref.read(currentUserProvider);
    final token = currentUser?.token ?? '';

    if (token.isEmpty) {
      throw Exception('Thieu token dang nhap');
    }

    final response = await dio.put(
      '/profile/me',
      data: profile.toMap(),
      options: Options(
        headers: {'x-auth-token': token},
      ),
    );

    final data = response.data;
    if (response.statusCode != 200 || data is! Map<String, dynamic>) {
      throw Exception('Cap nhat ho so that bai');
    }

    final mapped = {...data, 'token': token};
    final updatedProfile = _mapProfile(mapped);

    ref.read(currentUserProvider.notifier).setUser(
          UserModel.fromMap(mapped).copyWith(token: token),
        );

    return updatedProfile;
  }

  @override
  Future<String> uploadMyAvatar({
    required String fileName,
    required Uint8List fileBytes,
    String? filePath,
  }) async {
    final currentUser = ref.read(currentUserProvider);
    final token = currentUser?.token ?? '';

    if (token.isEmpty) {
      throw Exception('Thieu token dang nhap');
    }

    final formData = FormData.fromMap({
      'file': filePath != null
          ? await MultipartFile.fromFile(filePath, filename: fileName)
          : MultipartFile.fromBytes(fileBytes, filename: fileName),
    });

    final response = await dio.post(
      '/upload/avatar',
      data: formData,
      options: Options(
        headers: {
          'x-auth-token': token,
        },
      ),
    );

    final data = response.data;

    if (response.statusCode == 200 &&
        data is Map<String, dynamic> &&
        data['url'] != null) {
      return data['url'].toString();
    }

    throw Exception('Upload avatar that bai');
  }

  UserModel _mapProfile(Map<String, dynamic> map) {
    final role = (map['role'] ?? '').toString();
    if (role == 'teacher') {
      return TeacherMyProfileModel.fromMap(map);
    }
    return StudentMyProfileModel.fromMap(map);
  }
}

final myProfileRepositoryProvider = Provider<IMyProfileRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return MyProfileRepository(ref, dio);
});
