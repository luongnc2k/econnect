import 'dart:async';

import 'package:client/core/constants/server_constant.dart';
import 'package:client/core/localization/app_language.dart';
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
    final strings = ref.read(appStringsProvider);
    final normalized = _normalizeDocUrl(url);
    final uri = Uri.tryParse(normalized);
    if (uri == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            strings.text(en: 'Invalid link', vi: 'Link không hợp lệ'),
          ),
        ),
      );
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
                    Expanded(
                      child: Text(
                        strings.text(
                          en: 'Certificate image',
                          vi: 'Ảnh chứng chỉ',
                        ),
                        style: const TextStyle(fontWeight: FontWeight.w600),
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
                    errorBuilder: (_, error, stackTrace) => Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        strings.text(
                          en: 'Could not load certificate image',
                          vi: 'Không tải được ảnh chứng chỉ',
                        ),
                      ),
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
      if (!mounted) return;
      unawaited(ref.read(myProfileViewModelProvider.notifier).fetchMyProfile());
    });
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '--';
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  List<ProfileInfoItem> _buildBankItems(Object profile, AppStrings strings) {
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
      ProfileInfoItem(
        label: strings.text(en: 'Bank', vi: 'Ngân hàng'),
        value: bankName ?? '--',
      ),
      ProfileInfoItem(label: 'BIN', value: bankBin ?? '--'),
      ProfileInfoItem(
        label: strings.text(en: 'Account number', vi: 'Số tài khoản'),
        value: bankAccountNumber ?? '--',
      ),
      ProfileInfoItem(
        label: strings.text(en: 'Account holder', vi: 'Chủ tài khoản'),
        value: bankAccountHolder ?? '--',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(myProfileViewModelProvider);
    final strings = ref.watch(appStringsProvider);

    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final profile = state.profile;
    if (profile == null) {
      return Center(
        child: Text(
          state.errorMessage ??
              strings.text(en: 'No profile data', vi: 'Không có dữ liệu hồ sơ'),
        ),
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
            title: strings.text(
              en: 'Personal information',
              vi: 'Thông tin cá nhân',
            ),
            items: [
              ProfileInfoItem(
                label: strings.text(en: 'Full name', vi: 'Họ và tên'),
                value: profile.fullName,
              ),
              ProfileInfoItem(label: 'Email', value: profile.email),
              ProfileInfoItem(
                label: strings.text(en: 'Phone number', vi: 'Số điện thoại'),
                value: profile.phone ?? '--',
              ),
              ProfileInfoItem(
                label: strings.text(en: 'Status', vi: 'Trạng thái'),
                value: profile.isActive
                    ? strings.text(en: 'Active', vi: 'Đang hoạt động')
                    : strings.text(en: 'Inactive', vi: 'Ngừng hoạt động'),
              ),
              ProfileInfoItem(
                label: strings.text(en: 'Last login', vi: 'Lần đăng nhập cuối'),
                value: _formatDate(profile.lastLoginAt),
              ),
              ProfileInfoItem(
                label: strings.text(en: 'Created date', vi: 'Ngày tạo'),
                value: _formatDate(profile.createdAt),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (profile is StudentMyProfileModel)
            ProfileInfoCard(
              title: strings.text(
                en: 'Student information',
                vi: 'Thông tin học viên',
              ),
              items: [
                ProfileInfoItem(
                  label: strings.text(en: 'Level', vi: 'Trình độ'),
                  value: profile.englishLevel ?? '--',
                ),
                ProfileInfoItem(
                  label: strings.text(en: 'Goal', vi: 'Mục tiêu'),
                  value: profile.learningGoal ?? '--',
                ),
                ProfileInfoItem(
                  label: strings.text(en: 'Total lessons', vi: 'Tổng buổi học'),
                  value: profile.totalLessons.toString(),
                ),
              ],
            ),
          if (profile is TeacherMyProfileModel)
            ProfileInfoCard(
              title: strings.text(
                en: 'Teacher information',
                vi: 'Thông tin giáo viên',
              ),
              items: [
                ProfileInfoItem(
                  label: strings.text(en: 'Specialization', vi: 'Chuyên môn'),
                  value: profile.specialization ?? '--',
                ),
                ProfileInfoItem(
                  label: strings.text(en: 'Experience', vi: 'Kinh nghiệm'),
                  value: strings.text(
                    en: '${profile.yearsOfExperience} years',
                    vi: '${profile.yearsOfExperience} năm',
                  ),
                ),
                ProfileInfoItem(
                  label: strings.text(en: 'Rating', vi: 'Đánh giá'),
                  value: profile.rating.toStringAsFixed(1),
                ),
                ProfileInfoItem(
                  label: strings.text(en: 'Students', vi: 'Số học viên'),
                  value: profile.totalStudents.toString(),
                ),
                ProfileInfoItem(
                  label: strings.text(en: 'Bio', vi: 'Giới thiệu'),
                  value: profile.bio ?? '--',
                ),
                ProfileInfoItem(
                  label: strings.text(
                    en: 'Certificates / degrees',
                    vi: 'Chứng chỉ / bằng cấp',
                  ),
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
              title: strings.text(
                en: 'Bank account',
                vi: 'Tài khoản ngân hàng',
              ),
              items: _buildBankItems(profile, strings),
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
                      strings.text(
                        en: 'Certificate image links',
                        vi: 'Liên kết ảnh chứng chỉ',
                      ),
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
                          child: Text(
                            strings.text(
                              en: 'Open certificate link #${entry.key + 1}',
                              vi: 'Mở link chứng chỉ #${entry.key + 1}',
                            ),
                          ),
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
            child: Text(
              strings.text(en: 'Edit profile', vi: 'Chỉnh sửa hồ sơ'),
            ),
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
            child: Text(strings.text(en: 'Sign out', vi: 'Đăng xuất')),
          ),
        ],
      ),
    );
  }
}
