import 'package:client/features/auth/model/user_model.dart';
import 'package:client/features/profile/model/student_my_profile_model.dart';
import 'package:client/features/profile/model/teacher_my_profile_model.dart';
import 'package:client/features/profile/viewmodel/my_profile_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class EditMyProfileScreen extends ConsumerStatefulWidget {
  const EditMyProfileScreen({super.key});

  @override
  ConsumerState<EditMyProfileScreen> createState() =>
      _EditMyProfileScreenState();
}

class _EditMyProfileScreenState extends ConsumerState<EditMyProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();

  final _englishLevelController = TextEditingController();
  final _learningGoalController = TextEditingController();

  final _specializationController = TextEditingController();
  final _bioController = TextEditingController();
  final _yearsOfExperienceController = TextEditingController();
  final _hourlyRateController = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final profile = ref.read(myProfileViewModelProvider).profile;
    if (profile == null) return;
    if (_fullNameController.text.isNotEmpty) return;

    _fullNameController.text = profile.fullName;
    _phoneController.text = profile.phone ?? '';

    if (profile is StudentMyProfileModel) {
      _englishLevelController.text = profile.englishLevel ?? '';
      _learningGoalController.text = profile.learningGoal ?? '';
    }

    if (profile is TeacherMyProfileModel) {
      _specializationController.text = profile.specialization ?? '';
      _bioController.text = profile.bio ?? '';
      _yearsOfExperienceController.text = profile.yearsOfExperience.toString();
      _hourlyRateController.text = profile.hourlyRate?.toStringAsFixed(0) ?? '';
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
    _yearsOfExperienceController.dispose();
    _hourlyRateController.dispose();
    super.dispose();
  }

  Future<void> _submit(UserModel profile) async {
    if (!_formKey.currentState!.validate()) return;

    late UserModel updatedProfile;

    if (profile is StudentMyProfileModel) {
      updatedProfile = profile.copyWith(
        fullName: _fullNameController.text.trim(),
        phone: _phoneController.text.trim(),
        learningGoal: _learningGoalController.text.trim(),
        englishLevel: _englishLevelController.text.trim(),
      );
    } else if (profile is TeacherMyProfileModel) {
      updatedProfile = profile.copyWith(
        fullName: _fullNameController.text.trim(),
        phone: _phoneController.text.trim(),
        specialization: _specializationController.text.trim(),
        bio: _bioController.text.trim(),
        yearsOfExperience:
            int.tryParse(_yearsOfExperienceController.text.trim()) ?? 0,
        hourlyRate: double.tryParse(_hourlyRateController.text.trim()),
      );
    } else {
      updatedProfile = profile.copyWith(
        fullName: _fullNameController.text.trim(),
        phone: _phoneController.text.trim(),
      );
    }

    final success = await ref
        .read(myProfileViewModelProvider.notifier)
        .updateMyProfile(updatedProfile);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cập nhật hồ sơ thành công')),
      );
      Navigator.pop(context);
    } else {
      final error = ref.read(myProfileViewModelProvider).errorMessage;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error ?? 'Cập nhật hồ sơ thất bại')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(myProfileViewModelProvider);
    final profile = state.profile;

    if (profile == null) {
      return const Scaffold(
        body: Center(child: Text('Không có dữ liệu hồ sơ')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chỉnh sửa hồ sơ của tôi'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildField(
                controller: _fullNameController,
                label: 'Họ và tên',
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Vui lòng nhập họ và tên';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              _buildField(
                controller: _phoneController,
                label: 'Số điện thoại',
              ),
              const SizedBox(height: 12),
              if (profile is StudentMyProfileModel) ...[
                _buildField(
                  controller: _englishLevelController,
                  label: 'Trình độ tiếng Anh',
                ),
                const SizedBox(height: 12),
                _buildField(
                  controller: _learningGoalController,
                  label: 'Mục tiêu học',
                  maxLines: 3,
                ),
              ],
              if (profile is TeacherMyProfileModel) ...[
                _buildField(
                  controller: _specializationController,
                  label: 'Chuyên môn',
                ),
                const SizedBox(height: 12),
                _buildField(
                  controller: _yearsOfExperienceController,
                  label: 'Số năm kinh nghiệm',
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                _buildField(
                  controller: _hourlyRateController,
                  label: 'Học phí / buổi',
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                _buildField(
                  controller: _bioController,
                  label: 'Giới thiệu',
                  maxLines: 4,
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: state.isSaving ? null : () => _submit(profile),
                  child: state.isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Lưu thay đổi'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}