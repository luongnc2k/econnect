import 'package:client/core/localization/app_language.dart';
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

  List<ProfileInfoItem> _buildBankItems(UserModel profile, AppStrings strings) {
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

    return <ProfileInfoItem>[
      if ((bankName ?? '').trim().isNotEmpty)
        ProfileInfoItem(
          label: strings.text(en: 'Bank', vi: 'Ngân hàng'),
          value: bankName ?? '--',
        ),
      if ((bankBin ?? '').trim().isNotEmpty)
        ProfileInfoItem(label: 'BIN', value: bankBin ?? '--'),
      if ((bankAccountNumber ?? '').trim().isNotEmpty)
        ProfileInfoItem(
          label: strings.text(en: 'Account number', vi: 'Số tài khoản'),
          value: bankAccountNumber ?? '--',
        ),
      if ((bankAccountHolder ?? '').trim().isNotEmpty)
        ProfileInfoItem(
          label: strings.text(en: 'Account holder', vi: 'Chủ tài khoản'),
          value: bankAccountHolder ?? '--',
        ),
    ];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          strings.text(en: 'Personal information', vi: 'Thông tin cá nhân'),
        ),
      ),
      body: FutureBuilder<UserModel>(
        future: ref
            .read(userProfileRepositoryProvider)
            .getUserProfileById(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return Center(
              child: Text(
                strings.text(
                  en: 'Could not load user information',
                  vi: 'Không tải được thông tin người dùng',
                ),
              ),
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
            ProfileInfoItem(
              label: strings.text(en: 'Full name', vi: 'Họ và tên'),
              value: profile.fullName,
            ),
          ];

          if (hasEmail) {
            personalItems.add(
              ProfileInfoItem(label: 'Email', value: profile.email),
            );
          }
          if (hasPhone) {
            personalItems.add(
              ProfileInfoItem(
                label: strings.text(en: 'Phone number', vi: 'Số điện thoại'),
                value: profile.phone ?? '--',
              ),
            );
          }
          if (showPrivateMetadata) {
            personalItems.add(
              ProfileInfoItem(
                label: strings.text(en: 'Status', vi: 'Trạng thái'),
                value: profile.isActive
                    ? strings.text(en: 'Active', vi: 'Đang hoạt động')
                    : strings.text(en: 'Inactive', vi: 'Ngừng hoạt động'),
              ),
            );
          }
          if (profile.lastLoginAt != null) {
            personalItems.add(
              ProfileInfoItem(
                label: strings.text(en: 'Last login', vi: 'Lần đăng nhập cuối'),
                value: _formatDate(profile.lastLoginAt),
              ),
            );
          }
          if (profile.createdAt != null) {
            personalItems.add(
              ProfileInfoItem(
                label: strings.text(en: 'Created date', vi: 'Ngày tạo'),
                value: _formatDate(profile.createdAt),
              ),
            );
          }

          final bankItems = _buildBankItems(profile, strings);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              MyProfileHeader(profile: profile),
              const SizedBox(height: 16),
              ProfileInfoCard(
                title: strings.text(
                  en: 'Personal information',
                  vi: 'Thông tin cá nhân',
                ),
                items: personalItems,
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
                      label: strings.text(
                        en: 'Total lessons',
                        vi: 'Tổng buổi học',
                      ),
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
                      label: strings.text(
                        en: 'Specialization',
                        vi: 'Chuyên môn',
                      ),
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
              if (bankItems.isNotEmpty) ...[
                const SizedBox(height: 16),
                ProfileInfoCard(
                  title: strings.text(
                    en: 'Bank account',
                    vi: 'Tài khoản ngân hàng',
                  ),
                  items: bankItems,
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
