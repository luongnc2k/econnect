import 'package:client/features/auth/model/user_model.dart';

class MyProfileState {
  final UserModel? profile;
  final bool isLoading;
  final bool isSaving;
  final bool isUploadingAvatar;
  final String? errorMessage;

  const MyProfileState({
    this.profile,
    this.isLoading = false,
    this.isSaving = false,
    this.isUploadingAvatar = false,
    this.errorMessage,
  });

  MyProfileState copyWith({
    UserModel? profile,
    bool? isLoading,
    bool? isSaving,
    bool? isUploadingAvatar,
    String? errorMessage,
    bool clearError = false,
  }) {
    return MyProfileState(
      profile: profile ?? this.profile,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      isUploadingAvatar: isUploadingAvatar ?? this.isUploadingAvatar,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}