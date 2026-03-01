
import 'package:client/features/profile/model/user_model.dart';

abstract class ProfileRepository {
  Future<UserModel?> getMyProfile();
  Future<UserModel> createProfile(UserModel user);
  Future<UserModel> updateProfile(UserModel user);
  Future<UserModel> getUserProfile(String userId);
}