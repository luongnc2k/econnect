import 'dart:io';

import 'package:client/core/constants/server_constant.dart';
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
  final _bankNameController = TextEditingController();
  final _bankBinController = TextEditingController();
  final _bankAccountNumberController = TextEditingController();
  final _bankAccountHolderController = TextEditingController();
  final _certificationsController = TextEditingController();
  final _bioController = TextEditingController();
  final _yearsOfExperienceController = TextEditingController();
  final _hourlyRateController = TextEditingController();

  final _picker = ImagePicker();
  ImageProvider? _avatarPreviewImageProvider;
  bool _didInitForm = false;
  String? _deletingDocUrl;

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
      _bankNameController.text = profile.bankName ?? '';
      _bankBinController.text = profile.bankBin ?? '';
      _bankAccountNumberController.text = profile.bankAccountNumber ?? '';
      _bankAccountHolderController.text = profile.bankAccountHolder ?? '';
      _certificationsController.text = profile.certifications.join(', ');
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
    _bankNameController.dispose();
    _bankBinController.dispose();
    _bankAccountNumberController.dispose();
    _bankAccountHolderController.dispose();
    _certificationsController.dispose();
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
                title: const Text('Ch\u1ECDn t\u1EEB th\u01B0 vi\u1EC7n'),
                onTap: () {
                  Navigator.pop(context);
                  _pickAvatar(ImageSource.gallery);
                },
              ),
              if (!isDesktop)
                ListTile(
                  leading: const Icon(Icons.camera_alt_outlined),
                  title: const Text('Ch\u1EE5p \u1EA3nh'),
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
          content: Text(
            'Ch\u1EE9c n\u0103ng ch\u1EE5p \u1EA3nh ch\u01B0a h\u1ED7 tr\u1EE3 tr\u00EAn desktop',
          ),
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
        const SnackBar(
          content: Text(
            'Kh\u00F4ng th\u1EC3 m\u1EDF tr\u00ECnh ch\u1ECDn \u1EA3nh',
          ),
        ),
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
          success
              ? 'C\u1EADp nh\u1EADt avatar th\u00E0nh c\u00F4ng'
              : 'C\u1EADp nh\u1EADt avatar th\u1EA5t b\u1EA1i',
        ),
      ),
    );
  }

  Future<void> _uploadTutorDocument() async {
    final current = ref.read(myProfileViewModelProvider).profile;
    if (current is! TeacherMyProfileModel) return;

    XFile? image;
    try {
      image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 2000,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Kh\u00F4ng th\u1EC3 m\u1EDF tr\u00ECnh ch\u1ECDn \u1EA3nh ch\u1EE9ng ch\u1EC9',
          ),
        ),
      );
      return;
    }

    if (image == null) return;
    final fileBytes = await image.readAsBytes();
    final fileName = image.name.isEmpty
        ? 'teacher_doc_${DateTime.now().millisecondsSinceEpoch}.jpg'
        : image.name;

    final success = await ref
        .read(myProfileViewModelProvider.notifier)
        .uploadTutorDocument(
          fileName: fileName,
          fileBytes: fileBytes,
          filePath: kIsWeb ? null : image.path,
        );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'T\u1EA3i l\u00EAn ch\u1EE9ng ch\u1EC9 th\u00E0nh c\u00F4ng'
              : 'T\u1EA3i l\u00EAn ch\u1EE9ng ch\u1EC9 th\u1EA5t b\u1EA1i',
        ),
      ),
    );
  }

  Future<void> _openDocument(String url) async {
    final normalized = _normalizeDocUrl(url);
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
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
      ),
    );
  }

  Future<void> _deleteTutorDocument(String url, int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa chứng chỉ'),
        content: Text('Bạn có chắc muốn xóa chứng chỉ #${index + 1}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _deletingDocUrl = url;
    });

    final success = await ref
        .read(myProfileViewModelProvider.notifier)
        .removeTutorDocument(url);

    if (!mounted) return;

    setState(() {
      _deletingDocUrl = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success ? 'Xóa chứng chỉ thành công' : 'Xóa chứng chỉ thất bại',
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
      final certifications = _certificationsController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      updatedProfile = latestProfile.copyWith(
        fullName: _fullNameController.text.trim(),
        phone: _phoneController.text.trim(),
        specialization: _specializationController.text.trim(),
        bankName: _bankNameController.text.trim(),
        bankBin: _bankBinController.text.trim(),
        bankAccountNumber: _bankAccountNumberController.text.trim(),
        bankAccountHolder: _bankAccountHolderController.text.trim(),
        certifications: certifications,
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
        const SnackBar(
          content: Text(
            'C\u1EADp nh\u1EADt h\u1ED3 s\u01A1 th\u00E0nh c\u00F4ng',
          ),
        ),
      );
      Navigator.pop(context);
    } else {
      final error = ref.read(myProfileViewModelProvider).errorMessage;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error ?? 'C\u1EADp nh\u1EADt h\u1ED3 s\u01A1 th\u1EA5t b\u1EA1i',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(myProfileViewModelProvider);
    final profile = state.profile;

    if (profile == null) {
      return const Scaffold(
        body: Center(
          child: Text('Kh\u00F4ng c\u00F3 d\u1EEF li\u1EC7u h\u1ED3 s\u01A1'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Ch\u1EC9nh s\u1EEDa h\u1ED3 s\u01A1 c\u1EE7a t\u00F4i',
        ),
      ),
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
                label: 'H\u1ECD v\u00E0 t\u00EAn',
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Vui l\u00F2ng nh\u1EADp h\u1ECD v\u00E0 t\u00EAn';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              _buildField(
                controller: _phoneController,
                label: 'S\u1ED1 \u0111i\u1EC7n tho\u1EA1i',
              ),
              const SizedBox(height: 12),
              if (profile is StudentMyProfileModel) ...[
                _buildField(
                  controller: _englishLevelController,
                  label: 'Tr\u00ECnh \u0111\u1ED9 ti\u1EBFng Anh',
                ),
                const SizedBox(height: 12),
                _buildField(
                  controller: _learningGoalController,
                  label: 'M\u1EE5c ti\u00EAu h\u1ECDc',
                  maxLines: 3,
                ),
              ],
              if (profile is TeacherMyProfileModel) ...[
                _buildSectionCard(
                  title: 'Thông tin giáo viên',
                  child: Column(
                    children: [
                      _buildField(
                        controller: _specializationController,
                        label: 'Chuyên môn',
                      ),
                      const SizedBox(height: 12),
                      _buildField(
                        controller: _certificationsController,
                        label: 'Chứng chỉ, bằng cấp (phân tách bằng dấu phẩy)',
                        maxLines: 2,
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
                  ),
                ),
                const SizedBox(height: 12),
                _buildSectionCard(
                  title: 'Tài khoản ngân hàng',
                  subtitle:
                      'Thông tin thanh toán được tách riêng để dễ kiểm tra và cập nhật.',
                  child: Column(
                    children: [
                      _buildField(
                        controller: _bankNameController,
                        label: 'Ngân hàng',
                      ),
                      const SizedBox(height: 12),
                      _buildField(
                        controller: _bankBinController,
                        label: 'Mã ngân hàng (BIN)',
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                      _buildField(
                        controller: _bankAccountNumberController,
                        label: 'Số tài khoản',
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                      _buildField(
                        controller: _bankAccountHolderController,
                        label: 'Chủ tài khoản',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: state.isUploadingAvatar
                        ? null
                        : _uploadTutorDocument,
                    icon: const Icon(Icons.file_upload_outlined),
                    label: const Text(
                      'T\u1EA3i \u1EA3nh ch\u1EE9ng ch\u1EC9 / b\u1EB1ng c\u1EA5p',
                    ),
                  ),
                ),
                if (profile.verificationDocs.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Chứng chỉ đã tải lên',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          ...profile.verificationDocs.asMap().entries.map((
                            entry,
                          ) {
                            final isDeleting = _deletingDocUrl == entry.value;
                            return Row(
                              children: [
                                Expanded(
                                  child: TextButton(
                                    onPressed: isDeleting
                                        ? null
                                        : () => _openDocument(entry.value),
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        'Chứng chỉ #${entry.key + 1}',
                                      ),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: isDeleting
                                      ? null
                                      : () => _deleteTutorDocument(
                                          entry.value,
                                          entry.key,
                                        ),
                                  tooltip: 'Xóa chứng chỉ',
                                  icon: isDeleting
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.delete_outline),
                                ),
                              ],
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                ],
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
                      : const Text('L\u01B0u thay \u0111\u1ED5i'),
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
          label: Text(
            isUploading
                ? '\u0110ang t\u1EA3i \u1EA3nh...'
                : 'Thay \u0111\u1ED5i avatar',
          ),
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

  Widget _buildSectionCard({
    required String title,
    String? subtitle,
    required Widget child,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey[700]),
              ),
            ],
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
