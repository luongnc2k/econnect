import 'package:client/features/profile/model/user_model.dart';
import 'package:client/features/profile/repositories/profile_repository.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  UserModel? _myProfile;

  @override
  Future<UserModel?> getMyProfile() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return _myProfile;
  }

  @override
  Future<UserModel> createProfile(UserModel user) async {
    await Future.delayed(const Duration(milliseconds: 800));
    _myProfile = user;
    return user;
  }

  @override
  Future<UserModel> updateProfile(UserModel user) async {
    await Future.delayed(const Duration(milliseconds: 800));
    _myProfile = user;
    return user;
  }

  @override
  Future<UserModel> getUserProfile(String userId) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return _myProfile!;
  }
}