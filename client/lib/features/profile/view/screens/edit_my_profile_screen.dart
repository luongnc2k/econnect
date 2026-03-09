import 'dart:io';

import 'package:client/features/auth/model/user_model.dart';
import 'package:client/features/profile/model/student_my_profile_model.dart';
import 'package:client/features/profile/model/teacher_my_profile_model.dart';
import 'package:client/features/profile/viewmodel/my_profile_viewmodel.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

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

  final _picker = ImagePicker();
  ImageProvider? _avatarPreviewImageProvider;
  bool _didInitForm = false;

  bool _isDesktopDevice() {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_didInitForm) return;

    final profile = ref.read(myProfileViewModelProvider).profile;
    if (profile == null) return;

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

    _didInitForm = true;
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

  Future<void> _showAvatarSourcePicker() async {
    final isDesktop = _isDesktopDevice();

    await showModalBottomSheet(
      context: context,
      builder: (_) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Chọn từ thư viện'),
                onTap: () {
                  Navigator.pop(context);
                  _pickAvatar(ImageSource.gallery);
                },
              ),
              if (!isDesktop)
                ListTile(
                  leading: const Icon(Icons.camera_alt_outlined),
                  title: const Text('Chụp ảnh'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickAvatar(ImageSource.camera);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickAvatar(ImageSource source) async {
    final isDesktop = _isDesktopDevice();

    if (isDesktop && source == ImageSource.camera) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chuc nang chup anh chua ho tro tren desktop'),
        ),
      );
      return;
    }

    XFile? image;
    try {
      image = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1200,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Khong the mo trinh chon anh')),
      );
      return;
    }

    if (image == null) return;
    final pickedImage = image;
    final fileBytes = await pickedImage.readAsBytes();
    final fileName = pickedImage.name.isEmpty
        ? 'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg'
        : pickedImage.name;

    setState(() {
      _avatarPreviewImageProvider = kIsWeb
          ? NetworkImage(pickedImage.path)
          : FileImage(File(pickedImage.path));
    });

    final success = await ref
        .read(myProfileViewModelProvider.notifier)
        .uploadMyAvatar(
          fileName: fileName,
          fileBytes: fileBytes,
          filePath: kIsWeb ? null : pickedImage.path,
        );

    if (!mounted) return;

    if (success) {
      setState(() {
        _avatarPreviewImageProvider = null;
      });
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success ? 'Cap nhat avatar thanh cong' : 'Cap nhat avatar that bai',
        ),
      ),
    );
  }
  Future<void> _submit(UserModel profile) async {
    if (!_formKey.currentState!.validate()) return;

    final latestProfile =
        ref.read(myProfileViewModelProvider).profile ?? profile;

    late UserModel updatedProfile;

    if (latestProfile is StudentMyProfileModel) {
      updatedProfile = latestProfile.copyWith(
        fullName: _fullNameController.text.trim(),
        phone: _phoneController.text.trim(),
        learningGoal: _learningGoalController.text.trim(),
        englishLevel: _englishLevelController.text.trim(),
      );
    } else if (latestProfile is TeacherMyProfileModel) {
      updatedProfile = latestProfile.copyWith(
        fullName: _fullNameController.text.trim(),
        phone: _phoneController.text.trim(),
        specialization: _specializationController.text.trim(),
        bio: _bioController.text.trim(),
        yearsOfExperience:
            int.tryParse(_yearsOfExperienceController.text.trim()) ?? 0,
        hourlyRate: double.tryParse(_hourlyRateController.text.trim()),
      );
    } else {
      updatedProfile = latestProfile.copyWith(
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
      appBar: AppBar(title: const Text('Chỉnh sửa hồ sơ của tôi')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildAvatarSection(profile, state.isUploadingAvatar),
              const SizedBox(height: 16),
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
              _buildField(controller: _phoneController, label: 'Số điện thoại'),
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

  Widget _buildAvatarSection(UserModel profile, bool isUploading) {
    final avatarUrl = profile.avatarUrl;
    final hasNetworkAvatar =
        avatarUrl != null &&
        avatarUrl.isNotEmpty &&
        (avatarUrl.startsWith('http://') || avatarUrl.startsWith('https://'));

    final imageProvider =
        _avatarPreviewImageProvider ??
        (hasNetworkAvatar ? NetworkImage(avatarUrl) : null);

    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            CircleAvatar(
              radius: 52,
              backgroundImage: imageProvider,
              child: imageProvider == null
                  ? const Icon(Icons.person, size: 48)
                  : null,
            ),
            if (isUploading)
              Container(
                width: 104,
                height: 104,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const CircularProgressIndicator(strokeWidth: 3),
              ),
          ],
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: isUploading ? null : _showAvatarSourcePicker,
          icon: const Icon(Icons.photo_camera_outlined),
          label: Text(isUploading ? 'Đang tải ảnh...' : 'Thay đổi avatar'),
        ),
      ],
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
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

