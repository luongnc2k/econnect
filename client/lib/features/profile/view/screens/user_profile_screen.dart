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

  const UserProfileScreen({super.key, required this.userId});

  String _formatDate(DateTime? date) {
    if (date == null) return '--';
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Thông tin cá nhân')),
      body: FutureBuilder<UserModel>(
        future: ref
            .read(userProfileRepositoryProvider)
            .getUserProfileById(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return const Center(
              child: Text('Không tải được thông tin người dùng'),
            );
          }

          final profile = snapshot.data!;
          final hasEmail = profile.email.trim().isNotEmpty;
          final hasPhone = (profile.phone ?? '').trim().isNotEmpty;
          final showPrivateMetadata =
              hasEmail ||
              hasPhone ||
              profile.lastLoginAt != null ||
              profile.createdAt != null;
          final personalItems = <ProfileInfoItem>[
            ProfileInfoItem(label: 'Họ và tên', value: profile.fullName),
          ];

          if (hasEmail) {
            personalItems.add(
              ProfileInfoItem(label: 'Email', value: profile.email),
            );
          }
          if (hasPhone) {
            personalItems.add(
              ProfileInfoItem(
                label: 'Số điện thoại',
                value: profile.phone ?? '--',
              ),
            );
          }
          if (showPrivateMetadata) {
            personalItems.add(
              ProfileInfoItem(
                label: 'Trạng thái',
                value: profile.isActive ? 'Đang hoạt động' : 'Ngừng hoạt động',
              ),
            );
          }
          if (profile.lastLoginAt != null) {
            personalItems.add(
              ProfileInfoItem(
                label: 'Lần đăng nhập cuối',
                value: _formatDate(profile.lastLoginAt),
              ),
            );
          }
          if (profile.createdAt != null) {
            personalItems.add(
              ProfileInfoItem(
                label: 'Ngày tạo',
                value: _formatDate(profile.createdAt),
              ),
            );
          }

          final teacherBankItems = profile is TeacherMyProfileModel
              ? <ProfileInfoItem>[
                  if ((profile.bankName ?? '').trim().isNotEmpty)
                    ProfileInfoItem(
                      label: 'Ngân hàng',
                      value: profile.bankName ?? '--',
                    ),
                  if ((profile.bankBin ?? '').trim().isNotEmpty)
                    ProfileInfoItem(
                      label: 'Mã BIN',
                      value: profile.bankBin ?? '--',
                    ),
                  if ((profile.bankAccountNumber ?? '').trim().isNotEmpty)
                    ProfileInfoItem(
                      label: 'Số tài khoản',
                      value: profile.bankAccountNumber ?? '--',
                    ),
                  if ((profile.bankAccountHolder ?? '').trim().isNotEmpty)
                    ProfileInfoItem(
                      label: 'Chủ tài khoản',
                      value: profile.bankAccountHolder ?? '--',
                    ),
                ]
              : const <ProfileInfoItem>[];

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              MyProfileHeader(profile: profile),
              const SizedBox(height: 16),
              ProfileInfoCard(title: 'Thông tin cá nhân', items: personalItems),
              const SizedBox(height: 16),
              if (profile is StudentMyProfileModel)
                ProfileInfoCard(
                  title: 'Thông tin học viên',
                  items: [
                    ProfileInfoItem(
                      label: 'Trình độ',
                      value: profile.englishLevel ?? '--',
                    ),
                    ProfileInfoItem(
                      label: 'Mục tiêu',
                      value: profile.learningGoal ?? '--',
                    ),
                    ProfileInfoItem(
                      label: 'Tổng buổi học',
                      value: profile.totalLessons.toString(),
                    ),
                  ],
                ),
              if (profile is TeacherMyProfileModel)
                ProfileInfoCard(
                  title: 'Thông tin giáo viên',
                  items: [
                    ProfileInfoItem(
                      label: 'Chuyên môn',
                      value: profile.specialization ?? '--',
                    ),
                    ProfileInfoItem(
                      label: 'Kinh nghiệm',
                      value: '${profile.yearsOfExperience} năm',
                    ),
                    ProfileInfoItem(
                      label: 'Đánh giá',
                      value: profile.rating.toStringAsFixed(1),
                    ),
                    ProfileInfoItem(
                      label: 'Số học viên',
                      value: profile.totalStudents.toString(),
                    ),
                    ProfileInfoItem(
                      label: 'Học phí / buổi',
                      value: profile.hourlyRate?.toStringAsFixed(0) ?? '--',
                    ),
                    ProfileInfoItem(
                      label: 'Giới thiệu',
                      value: profile.bio ?? '--',
                    ),
                    ProfileInfoItem(
                      label: 'Chứng chỉ / bằng cấp',
                      value: profile.certifications.isEmpty
                          ? '--'
                          : profile.certifications.join(', '),
                    ),
                  ],
                ),
              if (teacherBankItems.isNotEmpty) ...[
                const SizedBox(height: 16),
                ProfileInfoCard(
                  title: 'Tài khoản ngân hàng',
                  items: teacherBankItems,
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
