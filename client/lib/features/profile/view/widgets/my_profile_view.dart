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
      ).showSnackBar(const SnackBar(content: Text('Link khong hop le')));
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
                        'Anh chung chi',
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
                    errorBuilder: (_, __, ___) => const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Khong tai duoc anh chung chi'),
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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(myProfileViewModelProvider);

    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final profile = state.profile;
    if (profile == null) {
      return Center(
        child: Text(
          state.errorMessage ??
              'Kh\u00F4ng c\u00F3 d\u1EEF li\u1EC7u h\u1ED3 s\u01A1',
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
            title: 'Th\u00F4ng tin c\u00E1 nh\u00E2n',
            items: [
              ProfileInfoItem(
                label: 'H\u1ECD v\u00E0 t\u00EAn',
                value: profile.fullName,
              ),
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
                ProfileInfoItem(
                  label: 'Ch\u1EE9ng ch\u1EC9 / b\u1EB1ng c\u1EA5p',
                  value: profile.certifications.isEmpty
                      ? '--'
                      : profile.certifications.join(', '),
                ),
              ],
            ),
          if (profile is TeacherMyProfileModel)
            const SizedBox(height: 16),
          if (profile is TeacherMyProfileModel)
            ProfileInfoCard(
              title: 'T\u00E0i kho\u1EA3n ng\u00E2n h\u00E0ng',
              items: [
                ProfileInfoItem(
                  label: 'Ng\u00E2n h\u00E0ng',
                  value: profile.bankName ?? '--',
                ),
                ProfileInfoItem(
                  label: 'Ma BIN',
                  value: profile.bankBin ?? '--',
                ),
                ProfileInfoItem(
                  label: 'S\u1ED1 t\u00E0i kho\u1EA3n',
                  value: profile.bankAccountNumber ?? '--',
                ),
                ProfileInfoItem(
                  label: 'Ch\u1EE7 t\u00E0i kho\u1EA3n',
                  value: profile.bankAccountHolder ?? '--',
                ),
              ],
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
                      'Li\u00EAn k\u1EBFt \u1EA3nh ch\u1EE9ng ch\u1EC9',
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
                            'M\u1EDF link ch\u1EE9ng ch\u1EC9 #${entry.key + 1}',
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
