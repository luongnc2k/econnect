import 'package:client/core/network/dio_provider.dart';
import 'package:client/core/providers/current_user_notifier.dart';
import 'package:client/features/auth/model/user_model.dart';
import 'package:client/testing/manual_test_mocks.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../model/student_my_profile_model.dart';
import '../model/teacher_my_profile_model.dart';

abstract class IUserProfileRepository {
  Future<UserModel> getUserProfileById(String userId);
}

class UserProfileRepository implements IUserProfileRepository {
  final Ref ref;
  final Dio dio;

  UserProfileRepository(this.ref, this.dio);

  @override
  Future<UserModel> getUserProfileById(String userId) async {
    final currentUser = ref.read(currentUserProvider);
    final token = currentUser?.token ?? '';

    try {
      if (token.isEmpty) {
        throw Exception('Thiếu token đăng nhập');
      }

      final response = await dio.get(
        '/profile/$userId',
        options: Options(headers: {'x-auth-token': token}),
      );

      final data = response.data;
      if (response.statusCode != 200 || data is! Map<String, dynamic>) {
        throw Exception('Không thể tải hồ sơ người dùng');
      }

      final mapped = {...data, 'token': token};
      return _mapProfile(mapped);
    } catch (_) {
      if (ManualTestMocks.enabled) {
        final mockProfile = ManualTestMocks.findProfile(userId);
        if (mockProfile != null) {
          return mockProfile;
        }
      }
      rethrow;
    }
  }

  UserModel _mapProfile(Map<String, dynamic> mapped) {
    final role = (mapped['role'] ?? '').toString();
    if (role == 'teacher') {
      return TeacherMyProfileModel.fromMap(mapped);
    }
    return StudentMyProfileModel.fromMap(mapped);
  }
}

final userProfileRepositoryProvider = Provider<IUserProfileRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return UserProfileRepository(ref, dio);
});
