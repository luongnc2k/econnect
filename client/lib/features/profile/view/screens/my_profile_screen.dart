import 'package:client/core/router/app_router.dart';
import 'package:client/features/profile/model/student_my_profile_model.dart';
import 'package:client/features/profile/model/teacher_my_profile_model.dart';
import 'package:client/features/profile/view/widgets/my_profile_header.dart';
import 'package:client/features/profile/view/widgets/profile_info_card.dart';
import 'package:client/features/profile/viewmodel/my_profile_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class MyProfileScreen extends ConsumerStatefulWidget {
  const MyProfileScreen({super.key});

  @override
  ConsumerState<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends ConsumerState<MyProfileScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(myProfileViewModelProvider.notifier).fetchMyProfile();
    });
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '--';
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  Future<void> _uploadAvatar() async {
    // Giả lập chọn file và upload avatar
    final success = await ref
        .read(myProfileViewModelProvider.notifier)
        .uploadMyAvatar('/fake/path/avatar.png');

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success ? 'Cập nhật ảnh đại diện thành công' : 'Cập nhật ảnh đại diện thất bại',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(myProfileViewModelProvider);

    if (state.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final profile = state.profile;
    if (profile == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Hồ sơ của tôi')),
        body: Center(
          child: Text(state.errorMessage ?? 'Không có dữ liệu hồ sơ'),
        ),
      );
    }

    final editPath = profile.role == 'teacher'
        ? AppRoutes.teacherEditMyProfile
        : AppRoutes.studentEditMyProfile;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hồ sơ của tôi'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(myProfileViewModelProvider.notifier).fetchMyProfile();
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            MyProfileHeader(
              profile: profile,
              isUploadingAvatar: state.isUploadingAvatar,
              onEditAvatar: _uploadAvatar,
            ),
            const SizedBox(height: 16),
            ProfileInfoCard(
              title: 'Thông tin cá nhân',
              items: [
                ProfileInfoItem(label: 'Họ và tên', value: profile.fullName),
                ProfileInfoItem(label: 'Email', value: profile.email),
                ProfileInfoItem(label: 'Số điện thoại', value: profile.phone ?? '--'),
                ProfileInfoItem(label: 'Trạng thái', value: profile.isActive ? 'Đang hoạt động' : 'Ngưng hoạt động'),
                ProfileInfoItem(label: 'Lần đăng nhập cuối', value: _formatDate(profile.lastLoginAt)),
                ProfileInfoItem(label: 'Ngày tạo', value: _formatDate(profile.createdAt)),
              ],
            ),
            const SizedBox(height: 16),
            if (profile is StudentMyProfileModel)
              ProfileInfoCard(
                title: 'Thông tin học viên',
                items: [
                  ProfileInfoItem(label: 'Trình độ', value: profile.englishLevel ?? '--'),
                  ProfileInfoItem(label: 'Mục tiêu', value: profile.learningGoal ?? '--'),
                  ProfileInfoItem(label: 'Tổng buổi học', value: profile.totalLessons.toString()),
                  ProfileInfoItem(
                    label: 'Điểm trung bình',
                    value: profile.averageScore?.toStringAsFixed(1) ?? '--',
                  ),
                ],
              ),
            if (profile is TeacherMyProfileModel)
              ProfileInfoCard(
                title: 'Thông tin giáo viên',
                items: [
                  ProfileInfoItem(label: 'Chuyên môn', value: profile.specialization ?? '--'),
                  ProfileInfoItem(label: 'Kinh nghiệm', value: '${profile.yearsOfExperience} năm'),
                  ProfileInfoItem(label: 'Đánh giá', value: profile.rating.toStringAsFixed(1)),
                  ProfileInfoItem(label: 'Số học viên', value: profile.totalStudents.toString()),
                  ProfileInfoItem(
                    label: 'Học phí / buổi',
                    value: profile.hourlyRate?.toStringAsFixed(0) ?? '--',
                  ),
                  ProfileInfoItem(label: 'Giới thiệu', value: profile.bio ?? '--'),
                ],
              ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => context.push(editPath),
              child: const Text('Chỉnh sửa hồ sơ'),
            ),
            if (state.errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                state.errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            ],
          ],
        ),
      ),
    );
  }
}