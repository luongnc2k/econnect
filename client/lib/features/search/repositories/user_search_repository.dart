import 'package:client/core/network/dio_provider.dart';
import 'package:client/core/providers/current_user_notifier.dart';
import 'package:client/features/auth/model/user_model.dart';
import 'package:client/testing/manual_test_mocks.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract class IUserSearchRepository {
  Future<List<UserModel>> searchUsers(String query);
}

class UserSearchRepository implements IUserSearchRepository {
  final Ref ref;
  final Dio dio;

  UserSearchRepository(this.ref, this.dio);

  @override
  Future<List<UserModel>> searchUsers(String query) async {
    final keyword = query.trim();
    if (keyword.isEmpty) return const [];

    final currentUser = ref.read(currentUserProvider);
    final token = currentUser?.token ?? '';

    try {
      if (token.isEmpty) {
        throw Exception('Thiếu token đăng nhập');
      }

      final response = await dio.get(
        '/users/search',
        queryParameters: {'q': keyword},
        options: Options(headers: {'x-auth-token': token}),
      );

      final data = response.data;
      if (response.statusCode != 200 || data is! List) {
        throw Exception('Không thể tìm người dùng');
      }

      final results = data
          .whereType<Map<String, dynamic>>()
          .map((item) => UserModel.fromMap({...item, 'token': token}))
          .toList();

      if (results.isNotEmpty) {
        return results;
      }

      if (ManualTestMocks.enabled) {
        return ManualTestMocks.searchUsers(keyword);
      }
      return const [];
    } catch (_) {
      if (ManualTestMocks.enabled) {
        return ManualTestMocks.searchUsers(keyword);
      }
      return const [];
    }
  }
}

final userSearchRepositoryProvider = Provider<IUserSearchRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return UserSearchRepository(ref, dio);
});
