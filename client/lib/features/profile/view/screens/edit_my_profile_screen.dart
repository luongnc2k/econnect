import 'dart:async';
import 'dart:io';

import 'package:client/core/constants/server_constant.dart';
import 'package:client/core/providers/current_user_notifier.dart';
import 'package:client/core/router/app_router.dart';
import 'package:client/features/auth/model/user_model.dart';
import 'package:client/features/profile/model/payout_bank_account_verification_result.dart';
import 'package:client/features/profile/model/payout_bank_option.dart';
import 'package:client/features/profile/model/student_my_profile_model.dart';
import 'package:client/features/profile/model/teacher_my_profile_model.dart';
import 'package:client/features/profile/repositories/my_profile_repository.dart';
import 'package:client/features/profile/viewmodel/my_profile_viewmodel.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

class EditMyProfileScreen extends ConsumerStatefulWidget {
  final bool requireBankSetup;

  const EditMyProfileScreen({super.key, this.requireBankSetup = false});

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
  bool? _initialStudentHadBankAccount;
  bool _handledBankSetupCompletionRedirect = false;
  String? _deletingDocUrl;
  String? _selectedPayoutBankId;
  bool _isVerifyingBankAccount = false;
  bool? _isBankAccountVerified;
  String? _bankVerificationMessage;
  String? _verifiedBankBin;
  String? _verifiedBankAccountNumber;
  Timer? _bankVerificationDebounce;
  int _bankVerificationGeneration = 0;

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
  void initState() {
    super.initState();
    Future.microtask(() {
      final state = ref.read(myProfileViewModelProvider);
      final currentUser = ref.read(currentUserProvider);
      final shouldFetch =
          state.profile == null ||
          (currentUser != null &&
              state.profile != null &&
              state.profile!.id != currentUser.id);
      if (shouldFetch && !state.isLoading) {
        ref.read(myProfileViewModelProvider.notifier).fetchMyProfile();
      }
    });
  }

  void _initializeForm(UserModel profile) {
    if (_didInitForm) return;

    _fullNameController.text = profile.fullName;
    _phoneController.text = profile.phone ?? '';

    if (profile is StudentMyProfileModel) {
      _initialStudentHadBankAccount ??= profile.hasBankAccount;
      _englishLevelController.text = profile.englishLevel ?? '';
      _learningGoalController.text = profile.learningGoal ?? '';
      _bankNameController.text = profile.bankName ?? '';
      _bankBinController.text = profile.bankBin ?? '';
      _bankAccountNumberController.text = profile.bankAccountNumber ?? '';
      _bankAccountHolderController.text = _normalizeBankAccountHolderForStorage(
        profile.bankAccountHolder ?? '',
      );
      _selectedPayoutBankId = _resolveInitialPayoutBankId();
    }

    if (profile is TeacherMyProfileModel) {
      _specializationController.text = profile.specialization ?? '';
      _bankNameController.text = profile.bankName ?? '';
      _bankBinController.text = profile.bankBin ?? '';
      _bankAccountNumberController.text = profile.bankAccountNumber ?? '';
      _bankAccountHolderController.text = _normalizeBankAccountHolderForStorage(
        profile.bankAccountHolder ?? '',
      );
      _certificationsController.text = profile.certifications.join(', ');
      _bioController.text = profile.bio ?? '';
      _yearsOfExperienceController.text = profile.yearsOfExperience.toString();
      _hourlyRateController.text = profile.hourlyRate?.toStringAsFixed(0) ?? '';
      _selectedPayoutBankId = _resolveInitialPayoutBankId();
    }

    _didInitForm = true;
  }

  bool _supportsBankAccount(UserModel profile) {
    return profile is TeacherMyProfileModel || profile is StudentMyProfileModel;
  }

  bool _shouldRequireBankFields(UserModel profile) {
    if (!_supportsBankAccount(profile)) {
      return false;
    }
    if (widget.requireBankSetup) {
      return true;
    }

    return _selectedPayoutBankId != null ||
        _bankNameController.text.trim().isNotEmpty ||
        _bankBinController.text.trim().isNotEmpty ||
        _bankAccountNumberController.text.trim().isNotEmpty ||
        _bankAccountHolderController.text.trim().isNotEmpty;
  }

  String _profileBankBin(UserModel profile) {
    if (profile is TeacherMyProfileModel) {
      return (profile.bankBin ?? '').trim();
    }
    if (profile is StudentMyProfileModel) {
      return (profile.bankBin ?? '').trim();
    }
    return '';
  }

  String _profileBankAccountNumber(UserModel profile) {
    if (profile is TeacherMyProfileModel) {
      return (profile.bankAccountNumber ?? '').trim();
    }
    if (profile is StudentMyProfileModel) {
      return (profile.bankAccountNumber ?? '').trim();
    }
    return '';
  }

  bool _isBankSetupComplete(UserModel? profile) {
    if (profile is TeacherMyProfileModel) {
      return profile.hasPayoutBankAccount;
    }
    if (profile is StudentMyProfileModel) {
      return profile.hasBankAccount;
    }
    return false;
  }

  void _navigateToRoleHome(UserModel profile) {
    if (_handledBankSetupCompletionRedirect) {
      return;
    }
    _handledBankSetupCompletionRedirect = true;
    final destination = profile is TeacherMyProfileModel
        ? AppRoutes.teacherHome
        : AppRoutes.studentHome;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.go(destination);
    });
  }

  @override
  void dispose() {
    _bankVerificationDebounce?.cancel();
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

  String? _resolveInitialPayoutBankId() {
    final matchedBank = PayoutBankCatalog.match(
      bankName: _bankNameController.text,
      bankBin: _bankBinController.text,
    );
    if (matchedBank != null) {
      _bankNameController.text = matchedBank.bankName;
      _bankBinController.text = matchedBank.bankBin;
      return matchedBank.id;
    }

    if (_bankNameController.text.trim().isNotEmpty ||
        _bankBinController.text.trim().isNotEmpty) {
      return PayoutBankCatalog.manual.id;
    }

    return null;
  }

  void _onPayoutBankChanged(String? bankId, UserModel profile) {
    final selectedBank = PayoutBankCatalog.findById(bankId);
    setState(() {
      _selectedPayoutBankId = bankId;
      _isBankAccountVerified = null;
      _bankVerificationMessage = null;
      _isVerifyingBankAccount = false;
      _verifiedBankBin = null;
      _verifiedBankAccountNumber = null;
      if (selectedBank == null || selectedBank.isManualEntry) {
        return;
      }
      _bankNameController.text = selectedBank.bankName;
      _bankBinController.text = selectedBank.bankBin;
    });
    _scheduleBankVerification(profile);
  }

  String? _validateBankSelection(String? value, UserModel profile) {
    if (!_shouldRequireBankFields(profile)) {
      return null;
    }
    if (value == null || value.isEmpty) {
      return 'Vui lòng chọn ngân hàng';
    }
    return null;
  }

  String? _validateBankRequired(
    String? value,
    String label,
    UserModel profile,
  ) {
    if (!_shouldRequireBankFields(profile)) {
      return null;
    }
    if (value == null || value.trim().isEmpty) {
      return 'Vui lòng nhập $label';
    }
    return null;
  }

  String? _validateManualBankBin(String? value, UserModel profile) {
    if (!_shouldRequireBankFields(profile) ||
        !_supportsBankAccount(profile) ||
        _selectedPayoutBankId != PayoutBankCatalog.manual.id) {
      return null;
    }
    if (value == null || value.trim().isEmpty) {
      return 'Vui lòng nhập mã ngân hàng (BIN)';
    }
    if (!RegExp(r'^\d{3,20}$').hasMatch(value.trim())) {
      return 'Mã BIN phải gồm 3-20 chữ số';
    }
    return null;
  }

  void _clearBankVerificationState() {
    _bankVerificationDebounce?.cancel();
    _bankVerificationDebounce = null;
    _bankVerificationGeneration += 1;
    if (_isBankAccountVerified == null &&
        _bankVerificationMessage == null &&
        !_isVerifyingBankAccount &&
        _verifiedBankBin == null &&
        _verifiedBankAccountNumber == null) {
      return;
    }

    setState(() {
      _isVerifyingBankAccount = false;
      _isBankAccountVerified = null;
      _bankVerificationMessage = null;
      _verifiedBankBin = null;
      _verifiedBankAccountNumber = null;
    });
  }

  void _scheduleBankVerification(UserModel profile) {
    _clearBankVerificationState();

    if (_bankVerificationInputError(profile) != null) {
      return;
    }

    _bankVerificationDebounce = Timer(const Duration(milliseconds: 700), () {
      _bankVerificationDebounce = null;
      final latestProfile =
          ref.read(myProfileViewModelProvider).profile ?? profile;
      _verifyBankAccount(latestProfile, showInputErrorSnackBar: false);
    });

    if (mounted) {
      setState(() {});
    }
  }

  String? _bankVerificationInputError(UserModel profile) {
    if (!_supportsBankAccount(profile)) {
      return 'Loại tài khoản hiện tại không hỗ trợ kiểm tra tài khoản ngân hàng';
    }

    if (_selectedPayoutBankId == null || _selectedPayoutBankId!.isEmpty) {
      return 'Vui lòng chọn ngân hàng trước khi kiểm tra';
    }

    if (_selectedPayoutBankId == PayoutBankCatalog.manual.id &&
        _bankNameController.text.trim().isEmpty) {
      return 'Vui lòng nhập tên ngân hàng';
    }

    final bankBin = _bankBinController.text.trim();
    if (bankBin.isEmpty) {
      return 'Vui lòng nhập mã ngân hàng (BIN)';
    }
    if (!RegExp(r'^\d{3,20}$').hasMatch(bankBin)) {
      return 'Mã BIN phải gồm 3-20 chữ số';
    }

    final bankAccountNumber = _bankAccountNumberController.text.trim();
    if (bankAccountNumber.isEmpty) {
      return 'Vui lòng nhập số tài khoản';
    }
    if (!RegExp(r'^\d{6,30}$').hasMatch(bankAccountNumber)) {
      return 'Số tài khoản phải gồm 6-30 chữ số';
    }

    return null;
  }

  bool _hasVerifiedCurrentBankDestination() {
    return _isBankAccountVerified == true &&
        _verifiedBankBin == _bankBinController.text.trim() &&
        _verifiedBankAccountNumber == _bankAccountNumberController.text.trim();
  }

  bool _requiresBankDestinationVerification(UserModel profile) {
    if (!_supportsBankAccount(profile)) {
      return false;
    }
    final currentBankBin = _bankBinController.text.trim();
    final currentAccountNumber = _bankAccountNumberController.text.trim();
    if (currentBankBin.isEmpty || currentAccountNumber.isEmpty) {
      return false;
    }

    if (widget.requireBankSetup) {
      return true;
    }

    return currentBankBin != _profileBankBin(profile) ||
        currentAccountNumber != _profileBankAccountNumber(profile);
  }

  Future<void> _verifyBankAccount(
    UserModel profile, {
    bool showInputErrorSnackBar = true,
  }) async {
    final inputError = _bankVerificationInputError(profile);
    if (inputError != null) {
      if (!mounted || !showInputErrorSnackBar) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(inputError)));
      return;
    }

    final requestedBankBin = _bankBinController.text.trim();
    final requestedBankAccountNumber = _bankAccountNumberController.text.trim();
    final generation = _bankVerificationGeneration;

    setState(() {
      _isVerifyingBankAccount = true;
      _isBankAccountVerified = null;
      _bankVerificationMessage = null;
      _verifiedBankBin = null;
      _verifiedBankAccountNumber = null;
    });

    try {
      final result = await ref
          .read(myProfileRepositoryProvider)
          .verifyPayoutBankAccount(
            bankBin: requestedBankBin,
            bankAccountNumber: requestedBankAccountNumber,
          );

      if (!mounted || generation != _bankVerificationGeneration) return;

      setState(() {
        _isVerifyingBankAccount = false;
        _isBankAccountVerified = result.isValid;
        _bankVerificationMessage = result.message;
        if (result.isValid) {
          _verifiedBankBin = requestedBankBin;
          _verifiedBankAccountNumber = requestedBankAccountNumber;
        }
      });
    } catch (e) {
      if (!mounted || generation != _bankVerificationGeneration) return;

      setState(() {
        _isVerifyingBankAccount = false;
        _isBankAccountVerified = false;
        _bankVerificationMessage =
            PayoutBankAccountVerificationResult.normalizeMessage(
              e.toString().replaceFirst('Exception: ', ''),
            );
      });
    }
  }

  Future<void> _submit(UserModel profile) async {
    if (!_formKey.currentState!.validate()) return;

    final latestProfile =
        ref.read(myProfileViewModelProvider).profile ?? profile;

    if (_supportsBankAccount(latestProfile) &&
        _requiresBankDestinationVerification(latestProfile) &&
        !_hasVerifiedCurrentBankDestination()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isVerifyingBankAccount ||
                    (_bankVerificationDebounce?.isActive ?? false)
                ? 'Vui lòng chờ hệ thống kiểm tra sơ bộ tài khoản ngân hàng với payOS trước khi lưu'
                : 'Tài khoản ngân hàng chưa vượt qua bước kiểm tra sơ bộ với payOS. Vui lòng kiểm tra lại thông tin tài khoản',
          ),
        ),
      );
      return;
    }

    late UserModel updatedProfile;
    var shouldGoToStudentHomeAfterSave = false;

    if (latestProfile is StudentMyProfileModel) {
      if (widget.requireBankSetup) {
        updatedProfile = latestProfile.copyWith(
          bankName: _bankNameController.text.trim(),
          bankBin: _bankBinController.text.trim(),
          bankAccountNumber: _bankAccountNumberController.text.trim(),
          bankAccountHolder: _normalizeBankAccountHolderForStorage(
            _bankAccountHolderController.text,
          ),
        );
      } else {
        updatedProfile = latestProfile.copyWith(
          fullName: _fullNameController.text.trim(),
          phone: _phoneController.text.trim(),
          learningGoal: _learningGoalController.text.trim(),
          englishLevel: _englishLevelController.text.trim(),
          bankName: _bankNameController.text.trim(),
          bankBin: _bankBinController.text.trim(),
          bankAccountNumber: _bankAccountNumberController.text.trim(),
          bankAccountHolder: _normalizeBankAccountHolderForStorage(
            _bankAccountHolderController.text,
          ),
        );
      }
      final startedWithoutStudentBankAccount =
          _initialStudentHadBankAccount == false;
      shouldGoToStudentHomeAfterSave =
          startedWithoutStudentBankAccount &&
          updatedProfile is StudentMyProfileModel &&
          updatedProfile.hasBankAccount;
    } else if (latestProfile is TeacherMyProfileModel) {
      if (widget.requireBankSetup) {
        updatedProfile = latestProfile.copyWith(
          bankName: _bankNameController.text.trim(),
          bankBin: _bankBinController.text.trim(),
          bankAccountNumber: _bankAccountNumberController.text.trim(),
          bankAccountHolder: _normalizeBankAccountHolderForStorage(
            _bankAccountHolderController.text,
          ),
        );
      } else {
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
          bankAccountHolder: _normalizeBankAccountHolderForStorage(
            _bankAccountHolderController.text,
          ),
          certifications: certifications,
          bio: _bioController.text.trim(),
          yearsOfExperience:
              int.tryParse(_yearsOfExperienceController.text.trim()) ?? 0,
          hourlyRate: double.tryParse(_hourlyRateController.text.trim()),
        );
      }
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
      if (widget.requireBankSetup || shouldGoToStudentHomeAfterSave) {
        _navigateToRoleHome(updatedProfile);
      } else {
        Navigator.pop(context);
      }
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
    ref.listen(myProfileViewModelProvider, (_, next) {
      if (!widget.requireBankSetup || _handledBankSetupCompletionRedirect) {
        return;
      }
      final profile = next.profile;
      if (!_isBankSetupComplete(profile)) {
        return;
      }
      _navigateToRoleHome(profile!);
    });

    final state = ref.watch(myProfileViewModelProvider);
    final profile = state.profile;
    final isBankSetupOnly =
        widget.requireBankSetup &&
        profile != null &&
        _supportsBankAccount(profile);

    if (state.isLoading && profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (profile == null) {
      return const Scaffold(
        body: Center(
          child: Text('Kh\u00F4ng c\u00F3 d\u1EEF li\u1EC7u h\u1ED3 s\u01A1'),
        ),
      );
    }

    _initializeForm(profile);

    return PopScope(
      canPop: !widget.requireBankSetup,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: !widget.requireBankSetup,
          title: Text(
            widget.requireBankSetup
                ? 'Thiết lập tài khoản ngân hàng'
                : 'Ch\u1EC9nh s\u1EEDa h\u1ED3 s\u01A1 c\u1EE7a t\u00F4i',
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                if (!widget.requireBankSetup) ...[
                  _buildAvatarSection(profile, state.isUploadingAvatar),
                  const SizedBox(height: 16),
                ] else ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      'Bạn cần bổ sung tài khoản ngân hàng để tiếp tục dùng tài khoản Tutor và nhận payout sau các buổi học.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (!isBankSetupOnly) ...[
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
                ],
                if (!isBankSetupOnly && profile is StudentMyProfileModel) ...[
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
                if (profile is StudentMyProfileModel) ...[
                  const SizedBox(height: 12),
                  _buildBankAccountSection(profile),
                ],
                if (profile is TeacherMyProfileModel) ...[
                  if (!isBankSetupOnly) ...[
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
                            label:
                                'Chứng chỉ, bằng cấp (phân tách bằng dấu phẩy)',
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
                  ],
                  _buildSectionCard(
                    title: 'Tài khoản ngân hàng',
                    subtitle: widget.requireBankSetup
                        ? 'Thiết lập ngân hàng nhận payout. Nếu ngân hàng của bạn chưa có trong danh sách, hãy chuyển sang nhập thủ công.'
                        : 'Chọn ngân hàng để app tự điền tên ngân hàng và mã BIN. Nếu ngân hàng của bạn chưa có trong danh sách, hãy chuyển sang nhập thủ công.',
                    child: Column(
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: _selectedPayoutBankId,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'Ngân hàng nhận payout',
                            helperText:
                                'Danh sách đang ưu tiên các ngân hàng payout phổ biến của payOS.',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          items: PayoutBankCatalog.options
                              .map(
                                (option) => DropdownMenuItem<String>(
                                  value: option.id,
                                  child: Text(option.label),
                                ),
                              )
                              .toList(),
                          validator: (value) =>
                              _validateBankSelection(value, profile),
                          onChanged: (value) =>
                              _onPayoutBankChanged(value, profile),
                        ),
                        if (_selectedPayoutBankId == null) ...[
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Chọn một ngân hàng trong danh sách để app tự điền thông tin payout.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ] else if (_selectedPayoutBankId ==
                            PayoutBankCatalog.manual.id) ...[
                          const SizedBox(height: 12),
                          _buildField(
                            controller: _bankNameController,
                            label: 'Ngân hàng',
                            validator: (value) => _validateBankRequired(
                              value,
                              'tên ngân hàng',
                              profile,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildField(
                            controller: _bankBinController,
                            label: 'Mã ngân hàng (BIN)',
                            keyboardType: TextInputType.number,
                            onChanged: (_) =>
                                _scheduleBankVerification(profile),
                            validator: (value) =>
                                _validateManualBankBin(value, profile),
                          ),
                        ] else ...[
                          const SizedBox(height: 12),
                          _buildReadOnlyField(
                            label: 'Ngân hàng',
                            value: _bankNameController.text,
                          ),
                          const SizedBox(height: 12),
                          _buildReadOnlyField(
                            label: 'Mã ngân hàng (BIN)',
                            value: _bankBinController.text,
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Thông tin payout đã được điền tự động theo ngân hàng bạn chọn.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        _buildField(
                          controller: _bankAccountNumberController,
                          label: 'Số tài khoản',
                          keyboardType: TextInputType.number,
                          onChanged: (_) => _scheduleBankVerification(profile),
                          validator: (value) => _validateBankRequired(
                            value,
                            'số tài khoản',
                            profile,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildField(
                          fieldKey: const Key('bankAccountHolderField'),
                          controller: _bankAccountHolderController,
                          label: 'Chủ tài khoản',
                          textCapitalization: TextCapitalization.characters,
                          inputFormatters: const [
                            _BankAccountHolderInputFormatter(),
                          ],
                          helperText:
                              'Nhập tên chủ tài khoản bằng CHỮ IN HOA, KHÔNG DẤU.',
                          validator: (value) => _validateBankRequired(
                            value,
                            'chủ tài khoản',
                            profile,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Hệ thống sẽ tự kiểm tra sơ bộ tài khoản nhận payout với payOS sau khi bạn nhập đủ mã BIN và số tài khoản.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        if (_isVerifyingBankAccount ||
                            (_bankVerificationDebounce?.isActive ?? false)) ...[
                          const SizedBox(height: 12),
                          _buildPendingVerificationBanner(),
                        ],
                        if (_bankVerificationMessage != null) ...[
                          const SizedBox(height: 12),
                          _buildVerificationBanner(
                            isSuccess: _isBankAccountVerified == true,
                            message: _bankVerificationMessage!,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (!isBankSetupOnly) ...[
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
                                final isDeleting =
                                    _deletingDocUrl == entry.value;
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
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    key: const Key('saveProfileButton'),
                    onPressed: state.isSaving ? null : () => _submit(profile),
                    child: state.isSaving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            widget.requireBankSetup
                                ? 'Lưu tài khoản ngân hàng'
                                : 'L\u01B0u thay \u0111\u1ED5i',
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBankAccountSection(UserModel profile) {
    final isTeacher = profile is TeacherMyProfileModel;
    final dropdownLabel = isTeacher ? 'Ngân hàng nhận payout' : 'Ngân hàng';
    final subtitle = widget.requireBankSetup && isTeacher
        ? 'Thiết lập ngân hàng nhận payout. Nếu ngân hàng của bạn chưa có trong danh sách, hãy chuyển sang nhập thủ công.'
        : 'Chọn ngân hàng để app tự điền tên ngân hàng và mã BIN. Nếu ngân hàng của bạn chưa có trong danh sách, hãy chuyển sang nhập thủ công.';

    return _buildSectionCard(
      title: 'Tài khoản ngân hàng',
      subtitle: subtitle,
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            initialValue: _selectedPayoutBankId,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: dropdownLabel,
              helperText:
                  'Danh sách đang ưu tiên các ngân hàng phổ biến mà app đã cấu hình sẵn.',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            items: PayoutBankCatalog.options
                .map(
                  (option) => DropdownMenuItem<String>(
                    value: option.id,
                    child: Text(option.label),
                  ),
                )
                .toList(),
            validator: (value) => _validateBankSelection(value, profile),
            onChanged: (value) => _onPayoutBankChanged(value, profile),
          ),
          if (_selectedPayoutBankId == null) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Chọn một ngân hàng trong danh sách để app tự điền thông tin tài khoản.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ] else if (_selectedPayoutBankId == PayoutBankCatalog.manual.id) ...[
            const SizedBox(height: 12),
            _buildField(
              controller: _bankNameController,
              label: 'Ngân hàng',
              validator: (value) =>
                  _validateBankRequired(value, 'tên ngân hàng', profile),
            ),
            const SizedBox(height: 12),
            _buildField(
              controller: _bankBinController,
              label: 'Mã ngân hàng (BIN)',
              keyboardType: TextInputType.number,
              onChanged: (_) => _scheduleBankVerification(profile),
              validator: (value) => _validateManualBankBin(value, profile),
            ),
          ] else ...[
            const SizedBox(height: 12),
            _buildReadOnlyField(
              label: 'Ngân hàng',
              value: _bankNameController.text,
            ),
            const SizedBox(height: 12),
            _buildReadOnlyField(
              label: 'Mã ngân hàng (BIN)',
              value: _bankBinController.text,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Thông tin ngân hàng đã được điền tự động theo ngân hàng bạn chọn.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
          const SizedBox(height: 12),
          _buildField(
            controller: _bankAccountNumberController,
            label: 'Số tài khoản',
            keyboardType: TextInputType.number,
            onChanged: (_) => _scheduleBankVerification(profile),
            validator: (value) =>
                _validateBankRequired(value, 'số tài khoản', profile),
          ),
          const SizedBox(height: 12),
          _buildField(
            fieldKey: const Key('bankAccountHolderField'),
            controller: _bankAccountHolderController,
            label: 'Chủ tài khoản',
            textCapitalization: TextCapitalization.characters,
            inputFormatters: const [_BankAccountHolderInputFormatter()],
            helperText: 'Nhập tên chủ tài khoản bằng CHỮ IN HOA, KHÔNG DẤU.',
            validator: (value) =>
                _validateBankRequired(value, 'chủ tài khoản', profile),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Hệ thống sẽ tự kiểm tra sơ bộ tài khoản ngân hàng với payOS sau khi bạn nhập đủ mã BIN và số tài khoản.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          if (_isVerifyingBankAccount ||
              (_bankVerificationDebounce?.isActive ?? false)) ...[
            const SizedBox(height: 12),
            _buildPendingVerificationBanner(),
          ],
          if (_bankVerificationMessage != null) ...[
            const SizedBox(height: 12),
            _buildVerificationBanner(
              isSuccess: _isBankAccountVerified == true,
              message: _bankVerificationMessage!,
            ),
          ],
        ],
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
    Key? fieldKey,
    required TextEditingController controller,
    required String label,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    ValueChanged<String>? onChanged,
    List<TextInputFormatter>? inputFormatters,
    TextCapitalization textCapitalization = TextCapitalization.none,
    String? helperText,
  }) {
    return TextFormField(
      key: fieldKey,
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      onChanged: onChanged,
      inputFormatters: inputFormatters,
      textCapitalization: textCapitalization,
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildReadOnlyField({required String label, required String value}) {
    return TextFormField(
      key: ValueKey('readonly-$label-$value'),
      initialValue: value,
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        suffixIcon: const Icon(Icons.lock_outline_rounded),
      ),
    );
  }

  Widget _buildVerificationBanner({
    required bool isSuccess,
    required String message,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final backgroundColor = isSuccess
        ? colorScheme.secondaryContainer
        : colorScheme.errorContainer;
    final foregroundColor = isSuccess
        ? colorScheme.onSecondaryContainer
        : colorScheme.onErrorContainer;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isSuccess ? Icons.info_outline : Icons.error_outline,
            color: foregroundColor,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: foregroundColor,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingVerificationBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Đang tự động kiểm tra sơ bộ tài khoản ngân hàng với payOS...',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSecondaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
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

class _BankAccountHolderInputFormatter extends TextInputFormatter {
  const _BankAccountHolderInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final normalized = _normalizeBankAccountHolderForInput(newValue.text);
    return newValue.copyWith(
      text: normalized,
      selection: TextSelection.collapsed(offset: normalized.length),
      composing: TextRange.empty,
    );
  }
}

String _normalizeBankAccountHolderForInput(String value) {
  if (value.isEmpty) {
    return value;
  }

  final buffer = StringBuffer();
  for (final rune in value.runes) {
    final character = String.fromCharCode(rune);
    buffer.write(_bankAccountHolderCharMap[character] ?? character);
  }
  return buffer.toString().toUpperCase();
}

String _normalizeBankAccountHolderForStorage(String value) {
  final normalized = _normalizeBankAccountHolderForInput(value);
  return normalized.replaceAll(RegExp(r'\s+'), ' ').trim();
}

const Map<String, String> _bankAccountHolderCharMap = {
  'à': 'a',
  'á': 'a',
  'ả': 'a',
  'ã': 'a',
  'ạ': 'a',
  'ă': 'a',
  'ằ': 'a',
  'ắ': 'a',
  'ẳ': 'a',
  'ẵ': 'a',
  'ặ': 'a',
  'â': 'a',
  'ầ': 'a',
  'ấ': 'a',
  'ẩ': 'a',
  'ẫ': 'a',
  'ậ': 'a',
  'À': 'A',
  'Á': 'A',
  'Ả': 'A',
  'Ã': 'A',
  'Ạ': 'A',
  'Ă': 'A',
  'Ằ': 'A',
  'Ắ': 'A',
  'Ẳ': 'A',
  'Ẵ': 'A',
  'Ặ': 'A',
  'Â': 'A',
  'Ầ': 'A',
  'Ấ': 'A',
  'Ẩ': 'A',
  'Ẫ': 'A',
  'Ậ': 'A',
  'đ': 'd',
  'Đ': 'D',
  'è': 'e',
  'é': 'e',
  'ẻ': 'e',
  'ẽ': 'e',
  'ẹ': 'e',
  'ê': 'e',
  'ề': 'e',
  'ế': 'e',
  'ể': 'e',
  'ễ': 'e',
  'ệ': 'e',
  'È': 'E',
  'É': 'E',
  'Ẻ': 'E',
  'Ẽ': 'E',
  'Ẹ': 'E',
  'Ê': 'E',
  'Ề': 'E',
  'Ế': 'E',
  'Ể': 'E',
  'Ễ': 'E',
  'Ệ': 'E',
  'ì': 'i',
  'í': 'i',
  'ỉ': 'i',
  'ĩ': 'i',
  'ị': 'i',
  'Ì': 'I',
  'Í': 'I',
  'Ỉ': 'I',
  'Ĩ': 'I',
  'Ị': 'I',
  'ò': 'o',
  'ó': 'o',
  'ỏ': 'o',
  'õ': 'o',
  'ọ': 'o',
  'ô': 'o',
  'ồ': 'o',
  'ố': 'o',
  'ổ': 'o',
  'ỗ': 'o',
  'ộ': 'o',
  'ơ': 'o',
  'ờ': 'o',
  'ớ': 'o',
  'ở': 'o',
  'ỡ': 'o',
  'ợ': 'o',
  'Ò': 'O',
  'Ó': 'O',
  'Ỏ': 'O',
  'Õ': 'O',
  'Ọ': 'O',
  'Ô': 'O',
  'Ồ': 'O',
  'Ố': 'O',
  'Ổ': 'O',
  'Ỗ': 'O',
  'Ộ': 'O',
  'Ơ': 'O',
  'Ờ': 'O',
  'Ớ': 'O',
  'Ở': 'O',
  'Ỡ': 'O',
  'Ợ': 'O',
  'ù': 'u',
  'ú': 'u',
  'ủ': 'u',
  'ũ': 'u',
  'ụ': 'u',
  'ư': 'u',
  'ừ': 'u',
  'ứ': 'u',
  'ử': 'u',
  'ữ': 'u',
  'ự': 'u',
  'Ù': 'U',
  'Ú': 'U',
  'Ủ': 'U',
  'Ũ': 'U',
  'Ụ': 'U',
  'Ư': 'U',
  'Ừ': 'U',
  'Ứ': 'U',
  'Ử': 'U',
  'Ữ': 'U',
  'Ự': 'U',
  'ỳ': 'y',
  'ý': 'y',
  'ỷ': 'y',
  'ỹ': 'y',
  'ỵ': 'y',
  'Ỳ': 'Y',
  'Ý': 'Y',
  'Ỷ': 'Y',
  'Ỹ': 'Y',
  'Ỵ': 'Y',
};
