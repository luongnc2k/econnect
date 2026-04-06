import 'package:client/features/auth/model/user_model.dart';
import 'package:client/features/profile/model/student_my_profile_model.dart';
import 'package:client/features/profile/model/teacher_my_profile_model.dart';
import 'package:client/features/profile/repositories/user_profile_repository.dart';
import 'package:client/features/profile/view/widgets/my_profile_header.dart';
import 'package:client/features/profile/view/widgets/profile_info_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class UserProfileScreen extends ConsumerWidget {
  final String userId;

  const UserProfileScreen({
    super.key,
    required this.userId,
  });

  String _formatDate(DateTime? date) {
    if (date == null) return '--';
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thong tin ca nhan'),
      ),
      body: FutureBuilder<UserModel>(
        future: ref.read(userProfileRepositoryProvider).getUserProfileById(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return const Center(
              child: Text('Khong tai duoc thong tin nguoi dung'),
            );
          }

          final profile = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              MyProfileHeader(profile: profile),
              const SizedBox(height: 16),
              ProfileInfoCard(
                title: 'Thong tin ca nhan',
                items: [
                  ProfileInfoItem(label: 'Ho va ten', value: profile.fullName),
                  ProfileInfoItem(label: 'Email', value: profile.email),
                  ProfileInfoItem(label: 'So dien thoai', value: profile.phone ?? '--'),
                  ProfileInfoItem(
                    label: 'Trang thai',
                    value: profile.isActive ? 'Dang hoat dong' : 'Ngung hoat dong',
                  ),
                  ProfileInfoItem(
                    label: 'Lan dang nhap cuoi',
                    value: _formatDate(profile.lastLoginAt),
                  ),
                  ProfileInfoItem(
                    label: 'Ngay tao',
                    value: _formatDate(profile.createdAt),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (profile is StudentMyProfileModel)
                ProfileInfoCard(
                  title: 'Thong tin hoc vien',
                  items: [
                    ProfileInfoItem(
                      label: 'Trinh do',
                      value: profile.englishLevel ?? '--',
                    ),
                    ProfileInfoItem(
                      label: 'Muc tieu',
                      value: profile.learningGoal ?? '--',
                    ),
                    ProfileInfoItem(
                      label: 'Tong buoi hoc',
                      value: profile.totalLessons.toString(),
                    ),
                  ],
                ),
              if (profile is TeacherMyProfileModel)
                ProfileInfoCard(
                  title: 'Thong tin giao vien',
                  items: [
                    ProfileInfoItem(
                      label: 'Chuyen mon',
                      value: profile.specialization ?? '--',
                    ),
                    ProfileInfoItem(
                      label: 'Kinh nghiem',
                      value: '${profile.yearsOfExperience} nam',
                    ),
                    ProfileInfoItem(
                      label: 'Danh gia',
                      value: profile.rating.toStringAsFixed(1),
                    ),
                    ProfileInfoItem(
                      label: 'So hoc vien',
                      value: profile.totalStudents.toString(),
                    ),
                    ProfileInfoItem(
                      label: 'Hoc phi / buoi',
                      value: profile.hourlyRate?.toStringAsFixed(0) ?? '--',
                    ),
                    ProfileInfoItem(
                      label: 'Gioi thieu',
                      value: profile.bio ?? '--',
                    ),
                    ProfileInfoItem(
                      label: 'Chung chi / bang cap',
                      value: profile.certifications.isEmpty
                          ? '--'
                          : profile.certifications.join(', '),
                    ),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}
