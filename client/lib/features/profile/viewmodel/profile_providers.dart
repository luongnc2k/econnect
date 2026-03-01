import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../model/user_model.dart';
import '../repositories/profile_repository.dart';
import '../repositories/profile_repository_impl.dart';

final profileRepositoryProvider =
    Provider<ProfileRepository>((ref) {
  return ProfileRepositoryImpl();
});

/// MY PROFILE
final myProfileProvider =
    AsyncNotifierProvider<MyProfileNotifier, UserModel?>(
        MyProfileNotifier.new);

class MyProfileNotifier extends AsyncNotifier<UserModel?> {

  late final ProfileRepository _repo;

  @override
  Future<UserModel?> build() async {
    _repo = ref.read(profileRepositoryProvider);
    return _repo.getMyProfile();
  }

  Future<void> createProfile(UserModel user) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _repo.createProfile(user),
    );
  }

  Future<void> updateProfile(UserModel user) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _repo.updateProfile(user),
    );
  }
}

/// PUBLIC PROFILE
final publicProfileProvider =
    FutureProvider.family<UserModel, String>((ref, id) {
  final repo = ref.read(profileRepositoryProvider);
  return repo.getUserProfile(id);
});