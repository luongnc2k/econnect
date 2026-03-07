import 'package:client/core/providers/current_user_notifier.dart';
import 'package:client/features/auth/model/user_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../model/student_my_profile_model.dart';
import '../model/teacher_my_profile_model.dart';

abstract class IMyProfileRepository {
  Future<UserModel> getMyProfile();
  Future<UserModel> createMyProfile(UserModel profile);
  Future<UserModel> updateMyProfile(UserModel profile);
  Future<String> uploadMyAvatar(String filePath);
}

class MyProfileRepository implements IMyProfileRepository {
  final Ref ref;

  MyProfileRepository(this.ref);

  @override
  Future<UserModel> getMyProfile() async {
    await Future.delayed(const Duration(milliseconds: 400));

    final currentUser = ref.read(currentUserProvider);
    final isTeacher = currentUser?.role == 'teacher';

    if (isTeacher) {
      return TeacherMyProfileModel(
        id: currentUser?.id ?? '',
        email: currentUser?.email ?? '',
        fullName: currentUser?.fullName ?? '',
        phone: currentUser?.phone,
        avatarUrl: currentUser?.avatarUrl,
        role: currentUser?.role ?? 'teacher',
        isActive: currentUser?.isActive ?? true,
        lastLoginAt: currentUser?.lastLoginAt,
        createdAt: currentUser?.createdAt,
        updatedAt: currentUser?.updatedAt,
        token: currentUser?.token ?? '',
        specialization: 'IELTS & Speaking',
        yearsOfExperience: 3,
        rating: 4.8,
        totalStudents: 80,
        bio: 'English teacher',
        hourlyRate: 200000,
      );
    }

    return StudentMyProfileModel(
      id: currentUser?.id ?? '',
      email: currentUser?.email ?? '',
      fullName: currentUser?.fullName ?? '',
      phone: currentUser?.phone,
      avatarUrl: currentUser?.avatarUrl,
      role: currentUser?.role ?? 'student',
      isActive: currentUser?.isActive ?? true,
      lastLoginAt: currentUser?.lastLoginAt,
      createdAt: currentUser?.createdAt,
      updatedAt: currentUser?.updatedAt,
      token: currentUser?.token ?? '',
      englishLevel: 'A2',
      learningGoal: 'Improve speaking',
      totalLessons: 12,
      averageScore: 8.0,
    );
  }

  @override
  Future<UserModel> createMyProfile(UserModel profile) async {
    await Future.delayed(const Duration(milliseconds: 400));

    ref
        .read(currentUserProvider.notifier)
        .updateUser(
          fullName: profile.fullName,
          phone: profile.phone,
          avatarUrl: profile.avatarUrl,
          updatedAt: DateTime.now(),
        );

    return profile;
  }

  @override
  Future<UserModel> updateMyProfile(UserModel profile) async {
    await Future.delayed(const Duration(milliseconds: 400));

    ref
        .read(currentUserProvider.notifier)
        .updateUser(
          fullName: profile.fullName,
          phone: profile.phone,
          avatarUrl: profile.avatarUrl,
          updatedAt: DateTime.now(),
        );

    return profile;
  }

  @override
  Future<String> uploadMyAvatar(String filePath) async {
    await Future.delayed(const Duration(milliseconds: 400));
    return 'https://i.pravatar.cc/300?img=15';
  }
}

final myProfileRepositoryProvider = Provider<IMyProfileRepository>((ref) {
  return MyProfileRepository(ref);
});
