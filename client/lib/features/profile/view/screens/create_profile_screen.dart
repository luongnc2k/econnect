import 'package:client/core/providers/current_user_notifier.dart';
import 'package:client/core/router/app_router.dart';
import 'package:client/features/auth/model/user_model.dart';
import 'package:client/features/profile/model/student_my_profile_model.dart';
import 'package:client/features/profile/model/teacher_my_profile_model.dart';
import 'package:client/features/profile/viewmodel/my_profile_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class CreateProfileScreen extends ConsumerStatefulWidget {
  const CreateProfileScreen({super.key});

  @override
  ConsumerState<CreateProfileScreen> createState() =>
      _CreateProfileScreenState();
}

class _CreateProfileScreenState extends ConsumerState<CreateProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();

  final _englishLevelController = TextEditingController();
  final _learningGoalController = TextEditingController();

  final _specializationController = TextEditingController();
  final _bioController = TextEditingController();
  final _yearsController = TextEditingController();
  final _hourlyRateController = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final currentUser = ref.read(currentUserProvider);

    if (_fullNameController.text.isEmpty) {
      _fullNameController.text = currentUser?.fullName ?? '';
      _phoneController.text = currentUser?.phone ?? '';
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _englishLevelController.dispose();
    _learningGoalController.dispose();
    _specializationController.dispose();
    _bioController.dispose();
    _yearsController.dispose();
    _hourlyRateController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return;

    late UserModel profile;

    if (currentUser.role == 'teacher') {
      profile = TeacherMyProfileModel(
        id: currentUser.id,
        email: currentUser.email,
        fullName: _fullNameController.text.trim(),
        phone: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        avatarUrl: currentUser.avatarUrl,
        role: currentUser.role,
        isActive: currentUser.isActive,
        lastLoginAt: currentUser.lastLoginAt,
        createdAt: currentUser.createdAt,
        updatedAt: currentUser.updatedAt,
        token: currentUser.token,
        specialization: _specializationController.text.trim().isEmpty
            ? null
            : _specializationController.text.trim(),
        bio: _bioController.text.trim().isEmpty
            ? null
            : _bioController.text.trim(),
        yearsOfExperience: int.tryParse(_yearsController.text.trim()) ?? 0,
        hourlyRate: double.tryParse(_hourlyRateController.text.trim()),
      );
    } else {
      profile = StudentMyProfileModel(
        id: currentUser.id,
        email: currentUser.email,
        fullName: _fullNameController.text.trim(),
        phone: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        avatarUrl: currentUser.avatarUrl,
        role: currentUser.role,
        isActive: currentUser.isActive,
        lastLoginAt: currentUser.lastLoginAt,
        createdAt: currentUser.createdAt,
        updatedAt: currentUser.updatedAt,
        token: currentUser.token,
        englishLevel: _englishLevelController.text.trim().isEmpty
            ? null
            : _englishLevelController.text.trim(),
        learningGoal: _learningGoalController.text.trim().isEmpty
            ? null
            : _learningGoalController.text.trim(),
      );
    }

    final success = await ref
        .read(myProfileViewModelProvider.notifier)
        .createMyProfile(profile);

    if (!mounted) return;

    if (!success) {
      final error = ref.read(myProfileViewModelProvider).errorMessage;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error ?? 'Tạo hồ sơ thất bại')));
      return;
    }

    context.go(
      currentUser.role == 'teacher'
          ? AppRoutes.teacherMyProfile
          : AppRoutes.studentMyProfile,
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final state = ref.watch(myProfileViewModelProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Tạo hồ sơ')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _fullNameController,
                decoration: const InputDecoration(
                  labelText: 'Họ và tên',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Vui lòng nhập họ và tên';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Số điện thoại',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              if (currentUser?.role == 'teacher') ...[
                TextFormField(
                  controller: _specializationController,
                  decoration: const InputDecoration(
                    labelText: 'Chuyên môn',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _yearsController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Số năm kinh nghiệm',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _hourlyRateController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Học phí / buổi',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _bioController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Giới thiệu',
                    border: OutlineInputBorder(),
                  ),
                ),
              ] else ...[
                TextFormField(
                  controller: _englishLevelController,
                  decoration: const InputDecoration(
                    labelText: 'Trình độ tiếng Anh',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _learningGoalController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Mục tiêu học',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: state.isSaving ? null : _submit,
                  child: state.isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Tạo hồ sơ'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
