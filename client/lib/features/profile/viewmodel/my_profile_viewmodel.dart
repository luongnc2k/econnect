import 'package:client/features/auth/model/user_model.dart';
import 'package:client/features/profile/model/student_my_profile_model.dart';
import 'package:client/features/profile/model/teacher_my_profile_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/my_profile_repository.dart';
import 'my_profile_state.dart';

class MyProfileViewModel extends Notifier<MyProfileState> {
  @override
  MyProfileState build() {
    return const MyProfileState();
  }

  IMyProfileRepository get repository => ref.read(myProfileRepositoryProvider);

  Future<void> fetchMyProfile() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final profile = await repository.getMyProfile();
      state = state.copyWith(isLoading: false, profile: profile);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Không thể tải hồ sơ cá nhân',
      );
    }
  }

  Future<bool> createMyProfile(UserModel newProfile) async {
    state = state.copyWith(isSaving: true, clearError: true);

    try {
      final profile = await repository.createMyProfile(newProfile);
      state = state.copyWith(isSaving: false, profile: profile);
      return true;
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: 'Tạo hồ sơ thất bại',
      );
      return false;
    }
  }

  Future<bool> updateMyProfile(UserModel updatedProfile) async {
    state = state.copyWith(isSaving: true, clearError: true);

    try {
      final profile = await repository.updateMyProfile(updatedProfile);
      state = state.copyWith(isSaving: false, profile: profile);
      return true;
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: 'Cập nhật hồ sơ cá nhân thất bại',
      );
      return false;
    }
  }

  Future<bool> uploadMyAvatar(String filePath) async {
    final current = state.profile;
    if (current == null) return false;

    state = state.copyWith(isUploadingAvatar: true, clearError: true);

    try {
      final avatarUrl = await repository.uploadMyAvatar(filePath);

      final UserModel updated;
      if (current is StudentMyProfileModel) {
        updated = current.copyWith(avatarUrl: avatarUrl);
      } else if (current is TeacherMyProfileModel) {
        updated = current.copyWith(avatarUrl: avatarUrl);
      } else {
        updated = current.copyWith(avatarUrl: avatarUrl);
      }

      state = state.copyWith(isUploadingAvatar: false, profile: updated);
      return true;
    } catch (e) {
      state = state.copyWith(
        isUploadingAvatar: false,
        errorMessage: 'Cập nhật ảnh đại diện thất bại',
      );
      return false;
    }
  }
}

final myProfileViewModelProvider =
    NotifierProvider<MyProfileViewModel, MyProfileState>(
      MyProfileViewModel.new,
    );
