import 'package:client/core/router/app_router.dart';
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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(myProfileViewModelProvider);

    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final profile = state.profile;
    if (profile == null) {
      return Center(
        child: Text(state.errorMessage ?? 'Kh\u00F4ng c\u00F3 d\u1EEF li\u1EC7u h\u1ED3 s\u01A1'),
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
            title: 'Th\u00F4ng tin c\u00E1 nh\u00E2n',
            items: [
              ProfileInfoItem(label: 'H\u1ECD v\u00E0 t\u00EAn', value: profile.fullName),
              ProfileInfoItem(label: 'Email', value: profile.email),
              ProfileInfoItem(
                label: 'S\u1ED1 \u0111i\u1EC7n tho\u1EA1i',
                value: profile.phone ?? '--',
              ),
              ProfileInfoItem(
                label: 'Tr\u1EA1ng th\u00E1i',
                value: profile.isActive
                    ? '\u0110ang ho\u1EA1t \u0111\u1ED9ng'
                    : 'Ng\u01B0ng ho\u1EA1t \u0111\u1ED9ng',
              ),
              ProfileInfoItem(
                label: 'L\u1EA7n \u0111\u0103ng nh\u1EADp cu\u1ED1i',
                value: _formatDate(profile.lastLoginAt),
              ),
              ProfileInfoItem(
                label: 'Ng\u00E0y t\u1EA1o',
                value: _formatDate(profile.createdAt),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (profile is StudentMyProfileModel)
            ProfileInfoCard(
              title: 'Th\u00F4ng tin h\u1ECDc vi\u00EAn',
              items: [
                ProfileInfoItem(
                  label: 'Tr\u00ECnh \u0111\u1ED9',
                  value: profile.englishLevel ?? '--',
                ),
                ProfileInfoItem(
                  label: 'M\u1EE5c ti\u00EAu',
                  value: profile.learningGoal ?? '--',
                ),
                ProfileInfoItem(
                  label: 'T\u1ED5ng bu\u1ED5i h\u1ECDc',
                  value: profile.totalLessons.toString(),
                ),
                ProfileInfoItem(
                  label: '\u0110i\u1EC3m trung b\u00ECnh',
                  value: profile.averageScore?.toStringAsFixed(1) ?? '--',
                ),
              ],
            ),
          if (profile is TeacherMyProfileModel)
            ProfileInfoCard(
              title: 'Th\u00F4ng tin gi\u00E1o vi\u00EAn',
              items: [
                ProfileInfoItem(
                  label: 'Chuy\u00EAn m\u00F4n',
                  value: profile.specialization ?? '--',
                ),
                ProfileInfoItem(
                  label: 'Kinh nghi\u1EC7m',
                  value: '${profile.yearsOfExperience} n\u0103m',
                ),
                ProfileInfoItem(
                  label: '\u0110\u00E1nh gi\u00E1',
                  value: profile.rating.toStringAsFixed(1),
                ),
                ProfileInfoItem(
                  label: 'S\u1ED1 h\u1ECDc vi\u00EAn',
                  value: profile.totalStudents.toString(),
                ),
                ProfileInfoItem(
                  label: 'H\u1ECDc ph\u00ED / bu\u1ED5i',
                  value: profile.hourlyRate?.toStringAsFixed(0) ?? '--',
                ),
                ProfileInfoItem(
                  label: 'Gi\u1EDBi thi\u1EC7u',
                  value: profile.bio ?? '--',
                ),
              ],
            ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => context.push(editPath),
            child: const Text('Ch\u1EC9nh s\u1EEDa h\u1ED3 s\u01A1'),
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
        ],
      ),
    );
  }
}
