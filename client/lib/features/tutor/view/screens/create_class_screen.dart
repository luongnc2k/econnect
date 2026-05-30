import 'dart:async';
import 'dart:io';

import 'package:client/core/failure/failure.dart';
import 'package:client/core/localization/app_language.dart';
import 'package:client/core/providers/current_user_notifier.dart';
import 'package:client/features/payments/model/payment_transaction_status.dart';
import 'package:client/features/payments/repositories/payments_remote_repository.dart';
import 'package:client/features/tutor/model/create_class_state.dart';
import 'package:client/features/tutor/model/learning_location.dart';
import 'package:client/features/tutor/repositories/tutor_remote_repository.dart';
import 'package:client/features/tutor/viewmodel/create_class_viewmodel.dart';
import 'package:client/features/tutor/viewmodel/tutor_home_viewmodel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart' show Either, Left, Right;
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

class CreateClassScreen extends ConsumerStatefulWidget {
  const CreateClassScreen({super.key});

  @override
  ConsumerState<CreateClassScreen> createState() => _CreateClassScreenState();
}

class _CreateClassScreenState extends ConsumerState<CreateClassScreen>
    with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();

  final _topicController = TextEditingController();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _minParticipantsController = TextEditingController(text: '1');
  final _maxParticipantsController = TextEditingController();
  final _priceController = TextEditingController();

  String _selectedLevel = 'beginner';
  DateTime? _startTime;
  DateTime? _endTime;

  Uint8List? _thumbnailBytes;
  String? _thumbnailFileName;
  String? _thumbnailFilePath;
  Uint8List? _materialBytes;
  String? _materialFileName;
  String? _materialFilePath;
  int? _materialFileSize;
  PaymentTransactionStatus? _transaction;
  _CreateClassDraftSnapshot? _pendingPaymentDraft;
  Timer? _pollTimer;
  bool _pollingPayment = false;
  int _pollAttempts = 0;
  int _consecutivePollErrors = 0;
  bool _pollRequestInFlight = false;
  bool _awaitingExternalPaymentReturn = false;
  bool _paymentAppWasBackgrounded = false;
  bool _resumeStatusCheckInFlight = false;

  List<LearningLocation> _locations = const [];
  String? _selectedLocationId;
  bool _isLoadingLocations = false;
  String? _locationError;
  static const _maxPollAttempts = 90;
  static const _maxConsecutivePollErrors = 3;
  static const _maxMaterialFileBytes = 3 * 1024 * 1024;
  static const _allowedMaterialExtensions = {'pdf', 'doc', 'docx'};

  String get _draftChangedMessage {
    final strings = ref.read(appStringsProvider);
    return strings.text(
      en: 'Class information has changed. The app will create a new payment code to save the correct details.',
      vi: 'Thông tin buổi học đã thay đổi. App sẽ tạo mã thanh toán mới để lưu đúng nội dung.',
    );
  }

  List<(String, String)> _localizedLevels(AppStrings strings) => [
    ('beginner', strings.text(en: 'Beginner', vi: 'Cơ bản')),
    ('intermediate', strings.text(en: 'Intermediate', vi: 'Trung cấp')),
    ('advanced', strings.text(en: 'Advanced', vi: 'Nâng cao')),
  ];

  LearningLocation? get _selectedLocation {
    for (final location in _locations) {
      if (location.id == _selectedLocationId) {
        return location;
      }
    }
    return null;
  }

  bool get _hasPendingPaymentTransaction {
    final transaction = _transaction;
    return transaction != null &&
        !transaction.isTerminal &&
        (transaction.status == 'pending' || transaction.status == 'processing');
  }

  bool get _pendingPaymentMatchesCurrentDraft {
    final pendingDraft = _pendingPaymentDraft;
    return _hasPendingPaymentTransaction &&
        pendingDraft != null &&
        pendingDraft == _currentDraftSnapshot();
  }

  _CreateClassDraftSnapshot _currentDraftSnapshot() {
    final description = _descriptionController.text.trim();
    return _CreateClassDraftSnapshot(
      topic: _topicController.text.trim(),
      title: _titleController.text.trim(),
      description: description.isEmpty ? null : description,
      level: _selectedLevel,
      locationId: _selectedLocationId,
      startTimeUtcIso: _startTime?.toUtc().toIso8601String(),
      endTimeUtcIso: _endTime?.toUtc().toIso8601String(),
      minParticipants: int.tryParse(_minParticipantsController.text) ?? 1,
      maxParticipants: int.tryParse(_maxParticipantsController.text) ?? 0,
      price: int.tryParse(_priceController.text.replaceAll(',', '')) ?? 0,
      thumbnailFileName: _thumbnailFileName,
      thumbnailFilePath: _thumbnailFilePath,
      materialFileName: _materialFileName,
      materialFilePath: _materialFilePath,
      materialFileSize: _materialFileSize,
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _topicController.addListener(_handleDraftChanged);
    _titleController.addListener(_handleDraftChanged);
    _descriptionController.addListener(_handleDraftChanged);
    _minParticipantsController.addListener(_handleDraftChanged);
    _maxParticipantsController.addListener(_handleDraftChanged);
    _priceController.addListener(_handleDraftChanged);
    _loadLearningLocations();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _topicController.removeListener(_handleDraftChanged);
    _titleController.removeListener(_handleDraftChanged);
    _descriptionController.removeListener(_handleDraftChanged);
    _minParticipantsController.removeListener(_handleDraftChanged);
    _maxParticipantsController.removeListener(_handleDraftChanged);
    _priceController.removeListener(_handleDraftChanged);
    _topicController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _minParticipantsController.dispose();
    _maxParticipantsController.dispose();
    _priceController.dispose();
    _pollTimer?.cancel();
    _pollTimer = null;
    _thumbnailBytes = null;
    _materialBytes = null;
    super.dispose();
  }

  void _handleDraftChanged() {
    if (!_hasPendingPaymentTransaction || !mounted) {
      return;
    }

    _discardPendingPaymentForChangedDraft();
  }

  void _discardPendingPaymentForChangedDraft({bool showMessage = true}) {
    _pollTimer?.cancel();
    _pollTimer = null;
    _pollRequestInFlight = false;
    _awaitingExternalPaymentReturn = false;
    _paymentAppWasBackgrounded = false;
    _resumeStatusCheckInFlight = false;

    setState(() {
      _transaction = null;
      _pendingPaymentDraft = null;
      _pollingPayment = false;
    });
    if (showMessage) {
      _showMessage(_draftChangedMessage);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_awaitingExternalPaymentReturn) {
      return;
    }

    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
        _paymentAppWasBackgrounded = true;
        break;
      case AppLifecycleState.resumed:
        if (_paymentAppWasBackgrounded && !_resumeStatusCheckInFlight) {
          _paymentAppWasBackgrounded = false;
          unawaited(_handleExternalPaymentReturn());
        }
        break;
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        break;
    }
  }

  Future<void> _loadLearningLocations() async {
    final token = ref.read(currentUserProvider)?.token;
    if (token == null) {
      final strings = ref.read(appStringsProvider);
      setState(() {
        _locationError = strings.text(
          en: 'Please sign in again to load learning locations.',
          vi: 'Vui lòng đăng nhập lại để tải danh sách địa điểm học.',
        );
        _selectedLocationId = null;
        _locations = const [];
        _isLoadingLocations = false;
      });
      return;
    }

    setState(() {
      _isLoadingLocations = true;
      _locationError = null;
    });

    final result = await ref
        .read(tutorRemoteRepositoryProvider)
        .getLearningLocations(token);
    if (!mounted) {
      return;
    }

    switch (result) {
      case Left(value: final failure):
        setState(() {
          _isLoadingLocations = false;
          _locationError = failure.message;
          _locations = const [];
          _selectedLocationId = null;
        });
      case Right(value: final locations):
        final selectedStillExists = locations.any(
          (item) => item.id == _selectedLocationId,
        );
        setState(() {
          _isLoadingLocations = false;
          _locations = locations;
          _selectedLocationId = selectedStillExists
              ? _selectedLocationId
              : null;
          final strings = ref.read(appStringsProvider);
          _locationError = locations.isEmpty
              ? strings.text(
                  en: 'Could not load learning locations. Please try again.',
                  vi: 'Chưa tải được danh sách địa điểm học. Vui lòng thử lại.',
                )
              : null;
        });
    }
  }

  Future<void> _pickDateTime({required bool isStart}) async {
    final now = DateTime.now();
    final initialDate = isStart
        ? (_startTime ?? now.add(const Duration(hours: 1)))
        : (_endTime ?? (_startTime ?? now).add(const Duration(hours: 1)));

    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) {
      return;
    }

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
    );
    if (time == null || !mounted) {
      return;
    }

    final picked = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    _handleDraftChanged();
    setState(() {
      if (isStart) {
        _startTime = picked;
        if (_endTime != null && !_endTime!.isAfter(picked)) {
          _endTime = null;
        }
      } else {
        _endTime = picked;
      }
    });
  }

  Future<void> _pickThumbnail() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1200,
    );
    if (picked == null || !mounted) {
      return;
    }

    final bytes = kIsWeb ? await picked.readAsBytes() : null;
    if (!mounted) {
      return;
    }

    _handleDraftChanged();
    setState(() {
      _thumbnailBytes = bytes;
      _thumbnailFileName = picked.name;
      _thumbnailFilePath = kIsWeb ? null : picked.path;
    });
  }

  Future<void> _pickMaterial() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: _allowedMaterialExtensions.toList(),
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty || !mounted) {
      return;
    }

    final file = result.files.single;
    final fileName = file.name.trim();
    final extension = _fileExtension(fileName);
    if (!_allowedMaterialExtensions.contains(extension)) {
      final strings = ref.read(appStringsProvider);
      _showMessage(
        strings.text(
          en: 'Only PDF, DOC, or DOCX materials are supported.',
          vi: 'Chỉ hỗ trợ tài liệu PDF, DOC hoặc DOCX.',
        ),
      );
      return;
    }

    final fileSize = await _resolvePickedMaterialSize(file);
    if (fileSize != null && fileSize >= _maxMaterialFileBytes) {
      final strings = ref.read(appStringsProvider);
      _showMessage(
        strings.text(
          en: 'The material must be smaller than 3 MB.',
          vi: 'Tài liệu phải nhỏ hơn 3 MB.',
        ),
      );
      return;
    }

    final bytes = file.bytes;
    final path = kIsWeb ? null : file.path;
    if (bytes == null && (path == null || path.trim().isEmpty)) {
      final strings = ref.read(appStringsProvider);
      _showMessage(
        strings.text(
          en: 'Could not read the selected material.',
          vi: 'Không đọc được tài liệu đã chọn.',
        ),
      );
      return;
    }

    _handleDraftChanged();
    setState(() {
      _materialBytes = bytes;
      _materialFileName = fileName;
      _materialFilePath = path;
      _materialFileSize = fileSize;
    });
  }

  Future<int?> _resolvePickedMaterialSize(PlatformFile file) async {
    if (file.size > 0) {
      return file.size;
    }
    final path = file.path;
    if (!kIsWeb && path != null && path.trim().isNotEmpty) {
      try {
        return await File(path).length();
      } catch (_) {
        return null;
      }
    }
    return file.bytes?.length;
  }

  String _fileExtension(String fileName) {
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex == -1 || dotIndex == fileName.length - 1) {
      return '';
    }
    return fileName.substring(dotIndex + 1).toLowerCase();
  }

  void _clearMaterial() {
    _handleDraftChanged();
    setState(() {
      _materialBytes = null;
      _materialFileName = null;
      _materialFilePath = null;
      _materialFileSize = null;
    });
  }

  Future<void> _handlePrimaryPaymentAction(CreateClassState vmState) async {
    if (_hasPendingPaymentTransaction && !_pollingPayment) {
      if (_pendingPaymentMatchesCurrentDraft) {
        await _resumePendingPayment();
        return;
      }
      _discardPendingPaymentForChangedDraft(showMessage: false);
    }

    final confirmed = await _confirmCreationPaymentDisclaimer();
    if (!confirmed) {
      return;
    }

    await _submit(vmState);
  }

  Future<bool> _confirmCreationPaymentDisclaimer() async {
    final strings = ref.read(appStringsProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          strings.text(
            en: 'Confirm before payment',
            vi: 'Xác nhận trước khi thanh toán',
          ),
        ),
        content: Text(
          strings.text(
            en: 'After payment, the class creation fee is non-refundable if you cancel the class. Do you want to continue?',
            vi: 'Sau khi thanh toán sẽ không được hoàn phí tạo lớp nếu hủy lớp. Bạn có muốn tiếp tục không?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(strings.text(en: 'Back', vi: 'Quay lại')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(strings.text(en: 'I understand', vi: 'Tôi đã hiểu')),
          ),
        ],
      ),
    );

    return confirmed == true;
  }

  Future<void> _submit(CreateClassState vmState) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_isLoadingLocations) {
      final strings = ref.read(appStringsProvider);
      _showMessage(
        strings.text(
          en: 'Learning locations are loading. Please wait a moment.',
          vi: 'Danh sách địa điểm đang được tải, vui lòng chờ một chút.',
        ),
      );
      return;
    }

    if (_selectedLocationId == null || _selectedLocationId!.isEmpty) {
      final strings = ref.read(appStringsProvider);
      _showMessage(
        strings.text(
          en: 'Please select a learning location provided by the system.',
          vi: 'Vui lòng chọn địa điểm học do hệ thống cung cấp.',
        ),
      );
      return;
    }

    if (_startTime == null) {
      final strings = ref.read(appStringsProvider);
      _showMessage(
        strings.text(
          en: 'Please select a start time.',
          vi: 'Vui lòng chọn giờ bắt đầu',
        ),
      );
      return;
    }

    if (_endTime == null) {
      final strings = ref.read(appStringsProvider);
      _showMessage(
        strings.text(
          en: 'Please select an end time.',
          vi: 'Vui lòng chọn giờ kết thúc',
        ),
      );
      return;
    }

    if (!_endTime!.isAfter(_startTime!)) {
      final strings = ref.read(appStringsProvider);
      _showMessage(
        strings.text(
          en: 'End time must be after start time.',
          vi: 'Giờ kết thúc phải sau giờ bắt đầu',
        ),
      );
      return;
    }

    if (!_startTime!.isAfter(DateTime.now())) {
      final strings = ref.read(appStringsProvider);
      _showMessage(
        strings.text(
          en: 'Start time must be after the current time.',
          vi: 'Giờ bắt đầu phải sau thời điểm hiện tại',
        ),
      );
      return;
    }

    final minParticipants = int.tryParse(_minParticipantsController.text) ?? 1;
    final maxParticipants = int.tryParse(_maxParticipantsController.text) ?? 0;
    if (maxParticipants < minParticipants) {
      final strings = ref.read(appStringsProvider);
      _showMessage(
        strings.text(
          en: 'Maximum students must be greater than or equal to the minimum.',
          vi: 'Số học viên tối đa phải lớn hơn hoặc bằng tối thiểu',
        ),
      );
      return;
    }

    final submittedDraft = _currentDraftSnapshot();

    setState(() {
      _transaction = null;
      _pendingPaymentDraft = null;
    });

    final payment = await ref
        .read(createClassViewModelProvider.notifier)
        .submitClass(
          topic: _topicController.text.trim(),
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          level: _selectedLevel,
          locationId: _selectedLocationId!,
          startTime: _startTime!,
          endTime: _endTime!,
          minParticipants: minParticipants,
          maxParticipants: maxParticipants,
          price:
              double.tryParse(_priceController.text.replaceAll(',', '')) ?? 0,
          thumbnailBytes: _thumbnailBytes,
          thumbnailFileName: _thumbnailFileName,
          thumbnailFilePath: _thumbnailFilePath,
          materialBytes: _materialBytes,
          materialFileName: _materialFileName,
          materialFilePath: _materialFilePath,
        );

    if (!mounted || payment == null) {
      return;
    }

    if (submittedDraft != _currentDraftSnapshot()) {
      _discardPendingPaymentForChangedDraft(showMessage: false);
      _showMessage(_draftChangedMessage);
      return;
    }

    setState(() {
      _transaction = payment;
      _pendingPaymentDraft = submittedDraft;
    });

    final redirectUrl = payment.redirectUrl;
    if (redirectUrl == null || redirectUrl.isEmpty) {
      final strings = ref.read(appStringsProvider);
      _showMessage(
        strings.text(
          en: 'The system did not return a class creation payment URL.',
          vi: 'Không nhận được URL thanh toán phí tạo lớp từ hệ thống.',
        ),
      );
      return;
    }

    await _launchPaymentWindow(
      redirectUrl: redirectUrl,
      transactionRef: payment.transactionRef,
    );
  }

  Future<void> _launchPaymentWindow({
    required String redirectUrl,
    required String transactionRef,
  }) async {
    _beginPolling(transactionRef);
    final launched = await launchUrl(
      Uri.parse(redirectUrl),
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: kIsWeb ? '_blank' : null,
    );

    if (!mounted) {
      return;
    }

    if (!launched) {
      _stopPolling();
      _awaitingExternalPaymentReturn = false;
      final strings = ref.read(appStringsProvider);
      _showMessage(
        strings.text(
          en: 'Could not open the payment gateway. Please try again.',
          vi: 'Không mở được cổng thanh toán. Vui lòng thử lại.',
        ),
      );
      return;
    }

    _awaitingExternalPaymentReturn = true;
    _paymentAppWasBackgrounded = false;
  }

  Future<void> _resumePendingPayment() async {
    final transaction = _transaction;
    final redirectUrl = transaction?.redirectUrl;
    if (transaction == null || redirectUrl == null || redirectUrl.isEmpty) {
      final strings = ref.read(appStringsProvider);
      _showMessage(
        strings.text(
          en: 'Could not find a payment link to reopen.',
          vi: 'Không tìm thấy link thanh toán để mở lại.',
        ),
      );
      return;
    }

    await _launchPaymentWindow(
      redirectUrl: redirectUrl,
      transactionRef: transaction.transactionRef,
    );
  }

  void _beginPolling(String transactionRef) {
    _pollTimer?.cancel();
    _pollRequestInFlight = false;
    setState(() {
      _pollingPayment = true;
      _pollAttempts = 0;
      _consecutivePollErrors = 0;
    });

    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (!mounted) {
        return;
      }

      if (_pollRequestInFlight) {
        return;
      }

      final user = ref.read(currentUserProvider);
      if (user == null) {
        _stopPolling();
        return;
      }

      _pollAttempts += 1;
      if (_pollAttempts > _maxPollAttempts) {
        _stopPolling();
        final strings = ref.read(appStringsProvider);
        _showMessage(
          strings.text(
            en: 'Timed out while waiting for the payment result. Please reopen the transaction status later.',
            vi: 'Đã hết thời gian đợi kết quả thanh toán. Bạn hãy mở lại trạng thái giao dịch sau.',
          ),
        );
        return;
      }

      _pollRequestInFlight = true;
      try {
        final result = await _fetchTransactionStatus(
          token: user.token,
          transactionRef: transactionRef,
        );
        if (!mounted) {
          return;
        }

        switch (result) {
          case Right(value: final status):
            _consecutivePollErrors = 0;
            await _handleTransactionStatusUpdate(status);
            break;
          case Left(value: final failure):
            _consecutivePollErrors += 1;
            if (_consecutivePollErrors >= _maxConsecutivePollErrors) {
              _stopPolling();
              _showMessage(failure.message);
            }
            break;
        }
      } finally {
        if (mounted) {
          _pollRequestInFlight = false;
        }
      }
    });
  }

  Future<void> _handleExternalPaymentReturn() async {
    final transactionRef = _transaction?.transactionRef;
    final user = ref.read(currentUserProvider);
    if (transactionRef == null || transactionRef.isEmpty || user == null) {
      _awaitingExternalPaymentReturn = false;
      return;
    }

    _resumeStatusCheckInFlight = true;
    try {
      final result = await _fetchTransactionStatus(
        token: user.token,
        transactionRef: transactionRef,
      );
      if (!mounted) {
        return;
      }

      switch (result) {
        case Right(value: final status):
          await _handleTransactionStatusUpdate(status);
          if (mounted && !status.isTerminal) {
            _stopPolling();
            final strings = ref.read(appStringsProvider);
            _showMessage(
              strings.text(
                en: 'You closed the payment window. The app will stop waiting; tap "Continue class creation payment" to reopen the QR code.',
                vi: 'Bạn đã đóng cửa sổ thanh toán. App sẽ dừng chờ kết quả; bạn có thể bấm "Tiếp tục thanh toán tạo lớp" để mở lại QR.',
              ),
            );
          }
          break;
        case Left():
          _stopPolling();
          if (mounted) {
            final strings = ref.read(appStringsProvider);
            _showMessage(
              strings.text(
                en: 'You closed the payment window. The app will stop waiting; tap "Continue class creation payment" to reopen the QR code.',
                vi: 'Bạn đã đóng cửa sổ thanh toán. App sẽ dừng chờ kết quả; bạn có thể bấm "Tiếp tục thanh toán tạo lớp" để mở lại QR.',
              ),
            );
          }
          break;
      }
    } finally {
      if (mounted) {
        _awaitingExternalPaymentReturn = false;
        _resumeStatusCheckInFlight = false;
      }
    }
  }

  Future<Either<AppFailure, PaymentTransactionStatus>> _fetchTransactionStatus({
    required String token,
    required String transactionRef,
  }) {
    return ref
        .read(paymentsRemoteRepositoryProvider)
        .getTransactionStatus(token: token, transactionRef: transactionRef);
  }

  Future<void> _handleTransactionStatusUpdate(
    PaymentTransactionStatus status,
  ) async {
    if (!mounted) {
      return;
    }

    final currentTransaction = _transaction;
    if (currentTransaction == null ||
        currentTransaction.transactionRef != status.transactionRef ||
        !_pendingPaymentMatchesCurrentDraft) {
      return;
    }

    setState(() => _transaction = status);
    if (!status.isTerminal) {
      return;
    }

    _awaitingExternalPaymentReturn = false;
    _stopPolling();
    if (status.isSuccessLike && status.classStatus == 'scheduled') {
      await ref.read(tutorHomeViewModelProvider.notifier).refresh();
      if (!mounted) {
        return;
      }
      final strings = ref.read(appStringsProvider);
      _showMessage(
        strings.text(
          en: 'Payment successful. The class has been created.',
          vi: 'Thanh toán thành công, buổi học đã được tạo.',
        ),
      );
      context.pop();
      return;
    }

    final strings = ref.read(appStringsProvider);
    _showMessage(
      status.message ??
          strings.text(
            en: 'Class creation payment was unsuccessful.',
            vi: 'Thanh toán phí tạo lớp không thành công.',
          ),
    );
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _pollRequestInFlight = false;
    if (mounted) {
      setState(() => _pollingPayment = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final vmState = ref.watch(createClassViewModelProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final strings = ref.watch(appStringsProvider);
    final levels = _localizedLevels(strings);
    final canResumePendingPayment =
        _pendingPaymentMatchesCurrentDraft && !_pollingPayment;
    final shouldShowTransactionStatus =
        _transaction != null &&
        (!_hasPendingPaymentTransaction || _pendingPaymentMatchesCurrentDraft);
    final primaryActionLabel = canResumePendingPayment
        ? strings.text(
            en: 'Continue class creation payment',
            vi: 'Tiếp tục thanh toán tạo lớp',
          )
        : strings.text(
            en: 'Create class and pay',
            vi: 'Tạo buổi học và thanh toán',
          );

    ref.listen(createClassViewModelProvider, (_, next) {
      if (next.error == null) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(next.error!),
          backgroundColor: colorScheme.error,
        ),
      );
      ref.read(createClassViewModelProvider.notifier).clearError();
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(
          strings.text(en: 'Create new class', vi: 'Tạo buổi học mới'),
        ),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _ThumbnailPicker(
              thumbnailBytes: _thumbnailBytes,
              thumbnailFilePath: _thumbnailFilePath,
              onPick: _pickThumbnail,
            ),
            const SizedBox(height: 20),
            _SectionLabel(
              strings.text(en: 'Class information', vi: 'Thông tin buổi học'),
            ),
            const SizedBox(height: 12),
            _FormField(
              fieldKey: const ValueKey('create-class-title'),
              controller: _titleController,
              label: strings.text(
                en: 'Class title *',
                vi: 'Tiêu đề buổi học *',
              ),
              hint: strings.text(
                en: 'Example: Basic English conversation practice',
                vi: 'Ví dụ: Luyện giao tiếp tiếng Anh cơ bản',
              ),
              maxLength: 100,
              inputFormatters: [LengthLimitingTextInputFormatter(100)],
              validator: (value) {
                final trimmed = value?.trim() ?? '';
                if (trimmed.isEmpty) {
                  return strings.text(
                    en: 'Required',
                    vi: 'Không được để trống',
                  );
                }
                if (trimmed.length > 100) {
                  return strings.text(
                    en: 'Class title must not exceed 100 characters',
                    vi: 'Tiêu đề buổi học không được quá 100 ký tự',
                  );
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            _FormField(
              fieldKey: const ValueKey('create-class-topic'),
              controller: _topicController,
              label: strings.text(en: 'Class topic *', vi: 'Chủ đề buổi học *'),
              hint: strings.text(
                en: 'Example: Business conversation',
                vi: 'Ví dụ: Giao tiếp cho người đi làm',
              ),
              maxLength: 100,
              inputFormatters: [LengthLimitingTextInputFormatter(100)],
              validator: (value) {
                final trimmed = value?.trim() ?? '';
                if (trimmed.isEmpty) {
                  return strings.text(
                    en: 'Required',
                    vi: 'Không được để trống',
                  );
                }
                if (trimmed.length > 100) {
                  return strings.text(
                    en: 'Class topic must not exceed 100 characters',
                    vi: 'Chủ đề buổi học không được quá 100 ký tự',
                  );
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            _LevelDropdown(
              selected: _selectedLevel,
              levels: levels,
              onChanged: (value) {
                _handleDraftChanged();
                setState(() => _selectedLevel = value!);
              },
            ),
            const SizedBox(height: 12),
            _FormField(
              fieldKey: const ValueKey('create-class-description'),
              controller: _descriptionController,
              label: strings.text(
                en: 'Description (optional)',
                vi: 'Mô tả (tùy chọn)',
              ),
              hint: strings.text(
                en: 'What students will learn, class goals, student requirements...',
                vi: 'Nội dung sẽ học, mục tiêu buổi học, yêu cầu học viên...',
              ),
              maxLines: 3,
              maxLength: 300,
              inputFormatters: [LengthLimitingTextInputFormatter(300)],
              validator: (value) {
                final trimmed = value?.trim() ?? '';
                if (trimmed.length > 300) {
                  return strings.text(
                    en: 'Description must not exceed 300 characters',
                    vi: 'Mô tả không được quá 300 ký tự',
                  );
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            _SectionLabel(
              strings.text(en: 'Class material', vi: 'Tài liệu buổi học'),
            ),
            const SizedBox(height: 12),
            _MaterialPicker(
              fileName: _materialFileName,
              fileSize: _materialFileSize,
              onPick: _pickMaterial,
              onRemove: _clearMaterial,
            ),
            const SizedBox(height: 20),
            _SectionLabel(strings.text(en: 'Location', vi: 'Địa điểm')),
            const SizedBox(height: 12),
            _LocationSection(
              locations: _locations,
              selectedLocationId: _selectedLocationId,
              selectedLocation: _selectedLocation,
              isLoading: _isLoadingLocations,
              error: _locationError,
              onRetry: _loadLearningLocations,
              onChanged: (value) {
                _handleDraftChanged();
                setState(() => _selectedLocationId = value);
              },
            ),
            const SizedBox(height: 20),
            _SectionLabel(strings.text(en: 'Time', vi: 'Thời gian')),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _DateTimeButton(
                    label: strings.text(en: 'Start *', vi: 'Bắt đầu *'),
                    value: _startTime,
                    onTap: () => _pickDateTime(isStart: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DateTimeButton(
                    label: strings.text(en: 'End *', vi: 'Kết thúc *'),
                    value: _endTime,
                    onTap: () => _pickDateTime(isStart: false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _SectionLabel(
              strings.text(
                en: 'Students and tuition',
                vi: 'Học viên và học phí',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _FormField(
                    fieldKey: const ValueKey('create-class-min-participants'),
                    controller: _minParticipantsController,
                    label: strings.text(en: 'Minimum *', vi: 'Tối thiểu *'),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (value) {
                      final parsed = int.tryParse(value ?? '');
                      if (parsed == null || parsed < 1) {
                        return strings.text(en: 'Minimum 1', vi: 'Tối thiểu 1');
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _FormField(
                    fieldKey: const ValueKey('create-class-max-participants'),
                    controller: _maxParticipantsController,
                    label: strings.text(en: 'Maximum *', vi: 'Tối đa *'),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (value) {
                      final parsed = int.tryParse(value ?? '');
                      if (parsed == null || parsed < 1) {
                        return strings.text(en: 'Minimum 1', vi: 'Tối thiểu 1');
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _FormField(
              fieldKey: const ValueKey('create-class-price'),
              controller: _priceController,
              label: strings.text(
                en: 'Total class tuition (VND) *',
                vi: 'Tổng học phí buổi học (VNĐ) *',
              ),
              hint: strings.text(
                en: 'Example: 200000 for the whole class',
                vi: 'Ví dụ: 200000 cho cả lớp',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (value) {
                final parsed = double.tryParse(value ?? '');
                if (parsed == null || parsed < 0) {
                  return strings.text(
                    en: 'Invalid tuition amount',
                    vi: 'Học phí không hợp lệ',
                  );
                }
                return null;
              },
            ),
            const SizedBox(height: 32),
            FilledButton(
              key: const ValueKey('create-class-submit'),
              onPressed: vmState.isSubmitting || _pollingPayment
                  ? null
                  : () => _handlePrimaryPaymentAction(vmState),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              child: vmState.isSubmitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : Text(
                      _pollingPayment
                          ? strings.text(
                              en: 'Waiting for class creation payment...',
                              vi: 'Đang chờ thanh toán phí tạo lớp...',
                            )
                          : primaryActionLabel,
                      style: const TextStyle(fontSize: 16),
                    ),
            ),
            if (shouldShowTransactionStatus) ...[
              const SizedBox(height: 16),
              _PaymentStatusCard(
                transaction: _transaction!,
                isPolling: _pollingPayment,
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

@immutable
class _CreateClassDraftSnapshot {
  final String topic;
  final String title;
  final String? description;
  final String level;
  final String? locationId;
  final String? startTimeUtcIso;
  final String? endTimeUtcIso;
  final int minParticipants;
  final int maxParticipants;
  final int price;
  final String? thumbnailFileName;
  final String? thumbnailFilePath;
  final String? materialFileName;
  final String? materialFilePath;
  final int? materialFileSize;

  const _CreateClassDraftSnapshot({
    required this.topic,
    required this.title,
    required this.description,
    required this.level,
    required this.locationId,
    required this.startTimeUtcIso,
    required this.endTimeUtcIso,
    required this.minParticipants,
    required this.maxParticipants,
    required this.price,
    required this.thumbnailFileName,
    required this.thumbnailFilePath,
    required this.materialFileName,
    required this.materialFilePath,
    required this.materialFileSize,
  });

  @override
  bool operator ==(Object other) {
    return other is _CreateClassDraftSnapshot &&
        other.topic == topic &&
        other.title == title &&
        other.description == description &&
        other.level == level &&
        other.locationId == locationId &&
        other.startTimeUtcIso == startTimeUtcIso &&
        other.endTimeUtcIso == endTimeUtcIso &&
        other.minParticipants == minParticipants &&
        other.maxParticipants == maxParticipants &&
        other.price == price &&
        other.thumbnailFileName == thumbnailFileName &&
        other.thumbnailFilePath == thumbnailFilePath &&
        other.materialFileName == materialFileName &&
        other.materialFilePath == materialFilePath &&
        other.materialFileSize == materialFileSize;
  }

  @override
  int get hashCode => Object.hashAll([
    topic,
    title,
    description,
    level,
    locationId,
    startTimeUtcIso,
    endTimeUtcIso,
    minParticipants,
    maxParticipants,
    price,
    thumbnailFileName,
    thumbnailFilePath,
    materialFileName,
    materialFilePath,
    materialFileSize,
  ]);
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        color: Theme.of(context).colorScheme.primary,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _LocationSection extends StatelessWidget {
  final List<LearningLocation> locations;
  final String? selectedLocationId;
  final LearningLocation? selectedLocation;
  final bool isLoading;
  final String? error;
  final VoidCallback onRetry;
  final ValueChanged<String?> onChanged;

  const _LocationSection({
    required this.locations,
    required this.selectedLocationId,
    required this.selectedLocation,
    required this.isLoading,
    required this.error,
    required this.onRetry,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final strings = AppStrings(Localizations.localeOf(context).languageCode);

    if (isLoading) {
      return _StatusCard(
        icon: Icons.location_searching_rounded,
        message: strings.text(
          en: 'Loading learning locations...',
          vi: 'Đang tải danh sách địa điểm học...',
        ),
      );
    }

    if (locations.isEmpty) {
      return _StatusCard(
        icon: Icons.location_off_outlined,
        message:
            error ??
            strings.text(
              en: 'No learning locations are available.',
              vi: 'Chưa có địa điểm học khả dụng.',
            ),
        actionLabel: strings.text(en: 'Reload', vi: 'Tải lại'),
        onPressed: onRetry,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          key: ValueKey('location-$selectedLocationId-${locations.length}'),
          initialValue: selectedLocationId,
          decoration: InputDecoration(
            labelText: strings.text(
              en: 'Learning location *',
              vi: 'Địa điểm học *',
            ),
            border: const OutlineInputBorder(),
          ),
          items: locations
              .map(
                (location) => DropdownMenuItem<String>(
                  value: location.id,
                  child: Text(location.name, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: onChanged,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return strings.text(
                en: 'Please select a learning location.',
                vi: 'Vui lòng chọn địa điểm học',
              );
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        if (selectedLocation != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  selectedLocation!.name,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.place_outlined,
                      size: 18,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        selectedLocation!.address,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
                if (selectedLocation!.notes != null &&
                    selectedLocation!.notes!.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    selectedLocation!.notes!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        const SizedBox(height: 10),
        TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: Text(
            strings.text(en: 'Reload locations', vi: 'Tải lại địa điểm'),
          ),
        ),
      ],
    );
  }
}

class _StatusCard extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onPressed;

  const _StatusCard({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colorScheme.onSurfaceVariant),
          const SizedBox(height: 10),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          if (actionLabel != null && onPressed != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onPressed, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

class _PaymentStatusCard extends StatelessWidget {
  final PaymentTransactionStatus transaction;
  final bool isPolling;

  const _PaymentStatusCard({
    required this.transaction,
    required this.isPolling,
  });

  String _labelForStatus(String status, AppStrings strings) {
    switch (status) {
      case 'pending':
        return strings.text(en: 'Pending payment', vi: 'Đang chờ thanh toán');
      case 'paid':
        return strings.text(en: 'Paid', vi: 'Đã thanh toán');
      case 'released':
        return strings.text(en: 'Released', vi: 'Đã đối soát');
      case 'failed':
        return strings.text(en: 'Payment failed', vi: 'Thanh toán thất bại');
      case 'refunded':
        return strings.text(en: 'Refunded', vi: 'Đã hoàn tiền');
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final strings = AppStrings(Localizations.localeOf(context).languageCode);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            strings.text(en: 'Payment status', vi: 'Trạng thái thanh toán'),
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            strings.text(
              en: 'Transaction code: ${transaction.transactionRef}',
              vi: 'Mã giao dịch: ${transaction.transactionRef}',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            strings.text(
              en: 'Status: ${_labelForStatus(transaction.status, strings)}',
              vi: 'Trạng thái: ${_labelForStatus(transaction.status, strings)}',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            strings.text(
              en: 'Amount: ${transaction.amount} VND',
              vi: 'Số tiền: ${transaction.amount} VND',
            ),
          ),
          if (transaction.message != null &&
              transaction.message!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              transaction.message!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (isPolling) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
          ],
        ],
      ),
    );
  }
}

class _FormField extends StatelessWidget {
  final Key? fieldKey;
  final TextEditingController controller;
  final String label;
  final String? hint;
  final int maxLines;
  final int? maxLength;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;

  const _FormField({
    this.fieldKey,
    required this.controller,
    required this.label,
    this.hint,
    this.maxLines = 1,
    this.maxLength,
    this.keyboardType,
    this.inputFormatters,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: fieldKey,
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
      ),
    );
  }
}

class _LevelDropdown extends StatelessWidget {
  final String selected;
  final List<(String, String)> levels;
  final ValueChanged<String?> onChanged;

  const _LevelDropdown({
    required this.selected,
    required this.levels,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(Localizations.localeOf(context).languageCode);

    return DropdownButtonFormField<String>(
      initialValue: selected,
      decoration: InputDecoration(
        labelText: strings.text(en: 'Level *', vi: 'Trình độ *'),
        border: const OutlineInputBorder(),
      ),
      items: levels
          .map(
            (level) => DropdownMenuItem(value: level.$1, child: Text(level.$2)),
          )
          .toList(),
      onChanged: onChanged,
    );
  }
}

class _DateTimeButton extends StatelessWidget {
  final String label;
  final DateTime? value;
  final VoidCallback onTap;

  const _DateTimeButton({
    required this.label,
    required this.value,
    required this.onTap,
  });

  String _format(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    return '$hour:$minute $day/$month/${dateTime.year}';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final strings = AppStrings(Localizations.localeOf(context).languageCode);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.calendar_month_outlined),
        ),
        child: Text(
          value != null
              ? _format(value!)
              : strings.text(en: 'Select date and time', vi: 'Chọn ngày giờ'),
          style: TextStyle(
            color: value != null ? null : colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _MaterialPicker extends StatelessWidget {
  final String? fileName;
  final int? fileSize;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  const _MaterialPicker({
    required this.fileName,
    required this.fileSize,
    required this.onPick,
    required this.onRemove,
  });

  bool get _hasFile => fileName != null && fileName!.trim().isNotEmpty;

  String _formatFileSize(int bytes) {
    final mb = bytes / (1024 * 1024);
    if (mb >= 1) {
      return '${mb.toStringAsFixed(1)} MB';
    }
    final kb = bytes / 1024;
    return '${kb.toStringAsFixed(0)} KB';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final strings = AppStrings(Localizations.localeOf(context).languageCode);
    final title = _hasFile
        ? strings.text(en: 'Material selected', vi: 'Đã chọn tài liệu')
        : strings.text(
            en: 'Learning material (optional)',
            vi: 'Tài liệu học (tùy chọn)',
          );
    final subtitle = _hasFile
        ? [
            fileName!.trim(),
            if (fileSize != null) _formatFileSize(fileSize!),
          ].join(' · ')
        : strings.text(
            en: 'PDF, DOC, or DOCX, under 3 MB.',
            vi: 'PDF, DOC hoặc DOCX, dưới 3 MB.',
          );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.description_outlined,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              if (_hasFile)
                IconButton(
                  tooltip: strings.text(
                    en: 'Remove material',
                    vi: 'Xóa tài liệu',
                  ),
                  onPressed: onRemove,
                  icon: const Icon(Icons.close_rounded),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              key: const ValueKey('create-class-material-picker'),
              onPressed: onPick,
              icon: Icon(
                _hasFile ? Icons.swap_horiz_rounded : Icons.upload_file_rounded,
              ),
              label: Text(
                _hasFile
                    ? strings.text(en: 'Change material', vi: 'Đổi tài liệu')
                    : strings.text(en: 'Choose material', vi: 'Chọn tài liệu'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThumbnailPicker extends StatelessWidget {
  final Uint8List? thumbnailBytes;
  final String? thumbnailFilePath;
  final VoidCallback onPick;

  const _ThumbnailPicker({
    required this.thumbnailBytes,
    required this.thumbnailFilePath,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final strings = AppStrings(Localizations.localeOf(context).languageCode);
    final filePath = thumbnailFilePath?.trim();
    ImageProvider? imageProvider;
    if (thumbnailBytes != null) {
      imageProvider = MemoryImage(thumbnailBytes!);
    } else if (!kIsWeb && filePath != null && filePath.isNotEmpty) {
      imageProvider = FileImage(File(filePath));
    }
    final hasThumbnail = imageProvider != null;

    return GestureDetector(
      onTap: onPick,
      child: Container(
        height: 160,
        width: double.infinity,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          image: imageProvider != null
              ? DecorationImage(image: imageProvider, fit: BoxFit.cover)
              : null,
        ),
        child: !hasThumbnail
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 40,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    strings.text(
                      en: 'Add cover image (optional)',
                      vi: 'Thêm ảnh bìa (tùy chọn)',
                    ),
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              )
            : Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: CircleAvatar(
                    backgroundColor: colorScheme.surface.withValues(alpha: 0.8),
                    radius: 16,
                    child: Icon(
                      Icons.edit_outlined,
                      size: 16,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
