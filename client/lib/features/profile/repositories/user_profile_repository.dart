import 'package:client/core/network/dio_provider.dart';
import 'package:client/core/providers/current_user_notifier.dart';
import 'package:client/features/auth/model/user_model.dart';
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
        throw Exception('Thieu token dang nhap');
      }

      final response = await dio.get(
        '/profile/$userId',
        options: Options(
          headers: {'x-auth-token': token},
        ),
      );

      final data = response.data;
      if (response.statusCode != 200 || data is! Map<String, dynamic>) {
        throw Exception('Khong the tai ho so nguoi dung');
      }

      final mapped = {...data, 'token': token};
      return _mapProfile(mapped);
    } catch (_) {
      return _mockProfile(userId);
    }
  }

  UserModel _mapProfile(Map<String, dynamic> mapped) {
    final role = (mapped['role'] ?? '').toString();
    if (role == 'teacher') {
      return TeacherMyProfileModel.fromMap(mapped);
    }
    return StudentMyProfileModel.fromMap(mapped);
  }

  UserModel _mockProfile(String userId) {
    if (userId == 'teacher-james-wilson') {
      return TeacherMyProfileModel(
        id: userId,
        email: 'james.wilson@example.com',
        fullName: 'James Wilson',
        phone: '0901000001',
        avatarUrl: null,
        role: 'teacher',
        isActive: true,
        token: '',
        specialization: 'Business English',
        yearsOfExperience: 7,
        rating: 0.0,
        totalStudents: 128,
        bio: 'Chuyen day giao tiep va phat am cho nguoi di lam.',
        hourlyRate: 250000,
        certifications: const ['TESOL', 'IELTS Trainer'],
      );
    }

    if (userId == 'teacher-anna-lee') {
      return TeacherMyProfileModel(
        id: userId,
        email: 'anna.lee@example.com',
        fullName: 'Anna Lee',
        phone: '0901000002',
        avatarUrl: null,
        role: 'teacher',
        isActive: true,
        token: '',
        specialization: 'Speaking Coach',
        yearsOfExperience: 5,
        rating: 0.0,
        totalStudents: 96,
        bio: 'Tap trung luyen phan xa giao tiep va phat am tu nhien.',
        hourlyRate: 220000,
        certifications: const ['TEFL', 'Communication Coaching'],
      );
    }

    if (userId == 'student-minh-tran') {
      return StudentMyProfileModel(
        id: userId,
        email: 'minh.tran@example.com',
        fullName: 'Minh Tran',
        phone: '0902000001',
        avatarUrl: null,
        role: 'student',
        isActive: true,
        token: '',
        englishLevel: 'B1',
        learningGoal: 'Improve business speaking',
        totalLessons: 18,
        averageScore: 7.2,
      );
    }

    if (userId == 'student-thao-nguyen') {
      return StudentMyProfileModel(
        id: userId,
        email: 'thao.nguyen@example.com',
        fullName: 'Thao Nguyen',
        phone: '0902000002',
        avatarUrl: null,
        role: 'student',
        isActive: true,
        token: '',
        englishLevel: 'A2',
        learningGoal: 'Speak confidently in daily situations',
        totalLessons: 9,
        averageScore: 6.8,
      );
    }

    if (userId == 'student-linh-le') {
      return StudentMyProfileModel(
        id: userId,
        email: 'linh.le@example.com',
        fullName: 'Linh Le',
        phone: '0902000003',
        avatarUrl: null,
        role: 'student',
        isActive: true,
        token: '',
        englishLevel: 'B2',
        learningGoal: 'Prepare for IELTS speaking',
        totalLessons: 24,
        averageScore: 7.8,
      );
    }

    if (userId == 'student-an-phan') {
      return StudentMyProfileModel(
        id: userId,
        email: 'an.phan@example.com',
        fullName: 'An Phan',
        phone: '0902000004',
        avatarUrl: null,
        role: 'student',
        isActive: true,
        token: '',
        englishLevel: 'B1',
        learningGoal: 'Improve pronunciation',
        totalLessons: 14,
        averageScore: 7.1,
      );
    }

    if (userId == 'student-binh-vo') {
      return StudentMyProfileModel(
        id: userId,
        email: 'binh.vo@example.com',
        fullName: 'Binh Vo',
        phone: '0902000005',
        avatarUrl: null,
        role: 'student',
        isActive: true,
        token: '',
        englishLevel: 'A2',
        learningGoal: 'Build basic communication skills',
        totalLessons: 7,
        averageScore: 6.5,
      );
    }

    if (userId == 'student-chi-do') {
      return StudentMyProfileModel(
        id: userId,
        email: 'chi.do@example.com',
        fullName: 'Chi Do',
        phone: '0902000006',
        avatarUrl: null,
        role: 'student',
        isActive: true,
        token: '',
        englishLevel: 'B2',
        learningGoal: 'Advance IELTS speaking band',
        totalLessons: 21,
        averageScore: 7.6,
      );
    }

    return StudentMyProfileModel(
      id: userId,
      email: 'student.demo@example.com',
      fullName: 'Student Demo',
      phone: '0901000003',
      avatarUrl: null,
      role: 'student',
      isActive: true,
      token: '',
      englishLevel: 'B1',
      learningGoal: 'Improve speaking confidence',
      totalLessons: 12,
      averageScore: 7.0,
    );
  }
}

final userProfileRepositoryProvider = Provider<IUserProfileRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return UserProfileRepository(ref, dio);
});
