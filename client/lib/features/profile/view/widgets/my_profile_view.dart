import 'package:client/core/constants/server_constant.dart';
import 'package:client/core/router/app_router.dart';
import 'package:client/features/auth/viewmodel/auth_viewmodel.dart';
import 'package:client/features/profile/model/student_my_profile_model.dart';
import 'package:client/features/profile/model/teacher_my_profile_model.dart';
import 'package:client/features/profile/view/widgets/my_profile_header.dart';
import 'package:client/features/profile/view/widgets/profile_info_card.dart';
import 'package:client/features/profile/viewmodel/my_profile_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class MyProfileView extends ConsumerStatefulWidget {
  final bool showAppBarSpacing;

  const MyProfileView({super.key, this.showAppBarSpacing = false});

  @override
  ConsumerState<MyProfileView> createState() => _MyProfileViewState();
}

class _MyProfileViewState extends ConsumerState<MyProfileView> {
  String _normalizeDocUrl(String url) {
    final docUri = Uri.tryParse(url);
    final serverUri = Uri.tryParse(ServerConstant.serverURL);
    if (docUri == null || serverUri == null) return url;

    final isLocalLoopback =
        docUri.host == '127.0.0.1' || docUri.host == 'localhost';
    if (!isLocalLoopback) return url;

    return docUri
        .replace(
          scheme: serverUri.scheme,
          host: serverUri.host,
          port: serverUri.hasPort ? serverUri.port : null,
        )
        .toString();
  }

  Future<void> _openLink(String url) async {
    final normalized = _normalizeDocUrl(url);
    final uri = Uri.tryParse(normalized);
    if (uri == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Link không hợp lệ')));
      return;
    }
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Ảnh chứng chỉ',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: InteractiveViewer(
                  child: Image.network(
                    normalized,
                    fit: BoxFit.contain,
                    errorBuilder: (_, error, stackTrace) => const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Không tải được ảnh chứng chỉ'),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

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

  List<ProfileInfoItem> _buildBankItems(Object profile) {
    String? bankName;
    String? bankBin;
    String? bankAccountNumber;
    String? bankAccountHolder;

    if (profile is TeacherMyProfileModel) {
      bankName = profile.bankName;
      bankBin = profile.bankBin;
      bankAccountNumber = profile.bankAccountNumber;
      bankAccountHolder = profile.bankAccountHolder;
    } else if (profile is StudentMyProfileModel) {
      bankName = profile.bankName;
      bankBin = profile.bankBin;
      bankAccountNumber = profile.bankAccountNumber;
      bankAccountHolder = profile.bankAccountHolder;
    } else {
      return const [];
    }

    return [
      ProfileInfoItem(label: 'Ngân hàng', value: bankName ?? '--'),
      ProfileInfoItem(label: 'Mã BIN', value: bankBin ?? '--'),
      ProfileInfoItem(label: 'Số tài khoản', value: bankAccountNumber ?? '--'),
      ProfileInfoItem(label: 'Chủ tài khoản', value: bankAccountHolder ?? '--'),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(myProfileViewModelProvider);

    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final profile = state.profile;
    if (profile == null) {
      return Center(
        child: Text(state.errorMessage ?? 'Không có dữ liệu hồ sơ'),
      );
    }

    final editPath = profile.role == 'teacher'
        ? AppRoutes.teacherEditMyProfile
        : AppRoutes.studentEditMyProfile;

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(myProfileViewModelProvider.notifier).fetchMyProfile();
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.showAppBarSpacing) const SizedBox(height: 4),
          MyProfileHeader(profile: profile),
          const SizedBox(height: 16),
          ProfileInfoCard(
            title: 'Thông tin cá nhân',
            items: [
              ProfileInfoItem(label: 'Họ và tên', value: profile.fullName),
              ProfileInfoItem(label: 'Email', value: profile.email),
              ProfileInfoItem(
                label: 'Số điện thoại',
                value: profile.phone ?? '--',
              ),
              ProfileInfoItem(
                label: 'Trạng thái',
                value: profile.isActive ? 'Đang hoạt động' : 'Ngừng hoạt động',
              ),
              ProfileInfoItem(
                label: 'Lần đăng nhập cuối',
                value: _formatDate(profile.lastLoginAt),
              ),
              ProfileInfoItem(
                label: 'Ngày tạo',
                value: _formatDate(profile.createdAt),
              ),
            ],
          ),
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
          if (profile is TeacherMyProfileModel ||
              profile is StudentMyProfileModel)
            const SizedBox(height: 16),
          if (profile is TeacherMyProfileModel ||
              profile is StudentMyProfileModel)
            ProfileInfoCard(
              title: 'Tài khoản ngân hàng',
              items: _buildBankItems(profile),
            ),
          if (profile is TeacherMyProfileModel &&
              profile.verificationDocs.isNotEmpty) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Liên kết ảnh chứng chỉ',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...profile.verificationDocs.asMap().entries.map(
                      (entry) => Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () => _openLink(entry.value),
                          child: Text('Mở link chứng chỉ #${entry.key + 1}'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
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
          const SizedBox(height: 24),
          FilledButton.tonal(
            onPressed: () => ref.read(authViewModelProvider.notifier).logout(),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.errorContainer,
              foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
            ),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
  }
}
