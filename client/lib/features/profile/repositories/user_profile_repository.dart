import 'package:client/features/auth/model/user_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../model/student_my_profile_model.dart';
import '../model/teacher_my_profile_model.dart';

abstract class IUserProfileRepository {
  Future<UserModel> getUserProfileById(String userId);
}

class UserProfileRepository implements IUserProfileRepository {
  @override
  Future<UserModel> getUserProfileById(String userId) async {
    await Future.delayed(const Duration(milliseconds: 400));

    if (userId.startsWith('teacher')) {
      // Mock: Trả về dữ liệu mẫu cho giáo viên
      return TeacherMyProfileModel(
        id: userId,
        email: 'teacher$userId@gmail.com',
        fullName: 'Teacher $userId',
        phone: '0900000000',
        avatarUrl: null,
        role: 'teacher',
        isActive: true,
        token: '',
        specialization: 'Conversation',
        yearsOfExperience: 5,
        rating: 4.9,
        totalStudents: 120,
        bio: 'Experienced English teacher',
        hourlyRate: 250000,
      );
    }

    // Trả về dữ liệu mẫu cho học viên
    return StudentMyProfileModel(
      id: userId,
      email: 'student$userId@gmail.com',
      fullName: 'Student $userId',
      phone: null,
      avatarUrl: null,
      role: 'student',
      isActive: true,
      token: '',
      englishLevel: 'B1',
      learningGoal: 'Improve IELTS',
      totalLessons: 20,
      averageScore: 7.5,
    );
  }
}

final userProfileRepositoryProvider = Provider<IUserProfileRepository>((ref) {
  return UserProfileRepository();
});