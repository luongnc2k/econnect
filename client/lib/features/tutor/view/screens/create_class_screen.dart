import 'dart:async';

import 'package:client/core/providers/current_user_notifier.dart';
import 'package:client/features/payments/model/payment_transaction_status.dart';
import 'package:client/features/payments/repositories/payments_remote_repository.dart';
import 'package:client/features/tutor/model/create_class_state.dart';
import 'package:client/features/tutor/model/learning_location.dart';
import 'package:client/features/tutor/repositories/tutor_remote_repository.dart';
import 'package:client/features/tutor/viewmodel/create_class_viewmodel.dart';
import 'package:client/features/tutor/viewmodel/tutor_home_viewmodel.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart' show Left, Right;
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

class CreateClassScreen extends ConsumerStatefulWidget {
  const CreateClassScreen({super.key});

  @override
  ConsumerState<CreateClassScreen> createState() => _CreateClassScreenState();
}

class _CreateClassScreenState extends ConsumerState<CreateClassScreen> {
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
  PaymentTransactionStatus? _transaction;
  Timer? _pollTimer;
  bool _pollingPayment = false;
  int _pollAttempts = 0;
  int _consecutivePollErrors = 0;

  List<LearningLocation> _locations = const [];
  String? _selectedLocationId;
  bool _isLoadingLocations = false;
  String? _locationError;
  static const _maxPollAttempts = 90;
  static const _maxConsecutivePollErrors = 3;

  static const _levels = [
    ('beginner', 'Cơ bản'),
    ('intermediate', 'Trung cấp'),
    ('advanced', 'Nâng cao'),
  ];

  LearningLocation? get _selectedLocation {
    for (final location in _locations) {
      if (location.id == _selectedLocationId) {
        return location;
      }
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _loadLearningLocations();
  }

  @override
  void dispose() {
    _topicController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _minParticipantsController.dispose();
    _maxParticipantsController.dispose();
    _priceController.dispose();
    _pollTimer?.cancel();
    _pollTimer = null;
    super.dispose();
  }

  Future<void> _loadLearningLocations() async {
    final token = ref.read(currentUserProvider)?.token;
    if (token == null) {
      setState(() {
        _locationError =
            'Vui lòng đăng nhập lại để tải danh sách địa điểm học.';
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
          _locationError = locations.isEmpty
              ? 'Chưa tải được danh sách địa điểm học. Vui lòng thử lại.'
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
    );
    if (picked == null) {
      return;
    }

    final bytes = await picked.readAsBytes();
    setState(() {
      _thumbnailBytes = bytes;
      _thumbnailFileName = picked.name;
      _thumbnailFilePath = kIsWeb ? null : picked.path;
    });
  }

  Future<void> _submit(CreateClassState vmState) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_isLoadingLocations) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Danh sách địa điểm đang được tải, vui lòng chờ một chút.',
          ),
        ),
      );
      return;
    }

    if (_selectedLocationId == null || _selectedLocationId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn địa điểm học do hệ thống cung cấp.'),
        ),
      );
      return;
    }

    if (_startTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn giờ bắt đầu')),
      );
      return;
    }

    if (_endTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn giờ kết thúc')),
      );
      return;
    }

    if (!_endTime!.isAfter(_startTime!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Giờ kết thúc phải sau giờ bắt đầu')),
      );
      return;
    }

    final minParticipants = int.tryParse(_minParticipantsController.text) ?? 1;
    final maxParticipants = int.tryParse(_maxParticipantsController.text) ?? 0;
    if (maxParticipants < minParticipants) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Số học viên tối đa phải lớn hơn hoặc bằng tối thiểu'),
        ),
      );
      return;
    }

    setState(() => _transaction = null);

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
        );

    if (!mounted || payment == null) {
      return;
    }

    setState(() => _transaction = payment);
    _beginPolling(payment.transactionRef);

    final redirectUrl = payment.redirectUrl;
    if (redirectUrl == null || redirectUrl.isEmpty) {
      _stopPolling();
      _showMessage('Khong nhan duoc URL thanh toan phi tao lop tu he thong.');
      return;
    }

    final launched = await launchUrl(
      Uri.parse(redirectUrl),
      mode: LaunchMode.platformDefault,
      webOnlyWindowName: kIsWeb ? '_blank' : null,
    );

    if (!launched && mounted) {
      _stopPolling();
      _showMessage('Khong mo duoc cong thanh toan. Vui long thu lai.');
    }
    return;
  }

  void _beginPolling(String transactionRef) {
    _pollTimer?.cancel();
    setState(() {
      _pollingPayment = true;
      _pollAttempts = 0;
      _consecutivePollErrors = 0;
    });

    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      final user = ref.read(currentUserProvider);
      if (user == null) {
        _stopPolling();
        return;
      }

      _pollAttempts += 1;
      if (_pollAttempts > _maxPollAttempts) {
        _stopPolling();
        _showMessage(
          'Da het thoi gian doi ket qua thanh toan. Ban hay mo lai trang thai giao dich sau.',
        );
        return;
      }

      final result = await ref
          .read(paymentsRemoteRepositoryProvider)
          .getTransactionStatus(
            token: user.token,
            transactionRef: transactionRef,
          );
      if (!mounted) {
        return;
      }

      switch (result) {
        case Right(value: final status):
          setState(() {
            _transaction = status;
            _consecutivePollErrors = 0;
          });

          if (!status.isTerminal) {
            return;
          }

          _stopPolling();
          if (status.isSuccessLike && status.classStatus == 'scheduled') {
            await ref.read(tutorHomeViewModelProvider.notifier).refresh();
            if (!mounted) {
              return;
            }
            _showMessage('Thanh toan thanh cong, buoi hoc da duoc tao.');
            context.pop();
            return;
          }

          _showMessage(
            status.message ?? 'Thanh toan phi tao lop khong thanh cong.',
          );
        case Left(value: final failure):
          _consecutivePollErrors += 1;
          if (_consecutivePollErrors >= _maxConsecutivePollErrors) {
            _stopPolling();
            _showMessage(failure.message);
          }
      }
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    if (mounted) {
      setState(() => _pollingPayment = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final vmState = ref.watch(createClassViewModelProvider);
    final colorScheme = Theme.of(context).colorScheme;

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
      appBar: AppBar(title: const Text('Tạo buổi học mới'), centerTitle: true),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _ThumbnailPicker(
              thumbnailBytes: _thumbnailBytes,
              onPick: _pickThumbnail,
            ),
            const SizedBox(height: 20),
            const _SectionLabel('Thông tin buổi học'),
            const SizedBox(height: 12),
            _FormField(
              controller: _titleController,
              label: 'Tiêu đề buổi học *',
              hint: 'Ví dụ: Luyện giao tiếp tiếng Anh cơ bản',
              maxLength: 100,
              inputFormatters: [LengthLimitingTextInputFormatter(100)],
              validator: (value) {
                final trimmed = value?.trim() ?? '';
                if (trimmed.isEmpty) {
                  return 'Không được để trống';
                }
                if (trimmed.length > 100) {
                  return 'Tiêu đề buổi học không được quá 100 ký tự';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            _FormField(
              controller: _topicController,
              label: 'Chủ đề buổi học *',
              hint: 'Ví dụ: Giao tiếp cho người đi làm',
              maxLength: 100,
              inputFormatters: [LengthLimitingTextInputFormatter(100)],
              validator: (value) {
                final trimmed = value?.trim() ?? '';
                if (trimmed.isEmpty) {
                  return 'Không được để trống';
                }
                if (trimmed.length > 100) {
                  return 'Chủ đề buổi học không được quá 100 ký tự';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            _LevelDropdown(
              selected: _selectedLevel,
              levels: _levels,
              onChanged: (value) => setState(() => _selectedLevel = value!),
            ),
            const SizedBox(height: 12),
            _FormField(
              controller: _descriptionController,
              label: 'Mô tả (tùy chọn)',
              hint: 'Nội dung sẽ học, mục tiêu buổi học, yêu cầu học viên...',
              maxLines: 3,
              maxLength: 300,
              inputFormatters: [LengthLimitingTextInputFormatter(300)],
              validator: (value) {
                final trimmed = value?.trim() ?? '';
                if (trimmed.length > 300) {
                  return 'Mô tả không được quá 300 ký tự';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            const _SectionLabel('Địa điểm'),
            const SizedBox(height: 12),
            _LocationSection(
              locations: _locations,
              selectedLocationId: _selectedLocationId,
              selectedLocation: _selectedLocation,
              isLoading: _isLoadingLocations,
              error: _locationError,
              onRetry: _loadLearningLocations,
              onChanged: (value) => setState(() => _selectedLocationId = value),
            ),
            const SizedBox(height: 20),
            const _SectionLabel('Thời gian'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _DateTimeButton(
                    label: 'Bắt đầu *',
                    value: _startTime,
                    onTap: () => _pickDateTime(isStart: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DateTimeButton(
                    label: 'Kết thúc *',
                    value: _endTime,
                    onTap: () => _pickDateTime(isStart: false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const _SectionLabel('Học viên và học phí'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _FormField(
                    controller: _minParticipantsController,
                    label: 'Tối thiểu *',
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (value) {
                      final parsed = int.tryParse(value ?? '');
                      if (parsed == null || parsed < 1) {
                        return 'Tối thiểu 1';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _FormField(
                    controller: _maxParticipantsController,
                    label: 'Tối đa *',
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (value) {
                      final parsed = int.tryParse(value ?? '');
                      if (parsed == null || parsed < 1) {
                        return 'Tối thiểu 1';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _FormField(
              controller: _priceController,
              label: 'Học phí (VNĐ) *',
              hint: 'Ví dụ: 150000',
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (value) {
                final parsed = double.tryParse(value ?? '');
                if (parsed == null || parsed < 0) {
                  return 'Học phí không hợp lệ';
                }
                return null;
              },
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: vmState.isSubmitting || _pollingPayment
                  ? null
                  : () => _submit(vmState),
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
                          ? 'Dang cho thanh toan phi tao lop...'
                          : 'Tao buoi hoc va thanh toan',
                      style: const TextStyle(fontSize: 16),
                    ),
            ),
            if (_transaction != null) ...[
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

    if (isLoading) {
      return const _StatusCard(
        icon: Icons.location_searching_rounded,
        message: 'Đang tải danh sách địa điểm học...',
      );
    }

    if (locations.isEmpty) {
      return _StatusCard(
        icon: Icons.location_off_outlined,
        message: error ?? 'Chưa có địa điểm học khả dụng.',
        actionLabel: 'Tải lại',
        onPressed: onRetry,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          key: ValueKey('location-$selectedLocationId-${locations.length}'),
          initialValue: selectedLocationId,
          decoration: const InputDecoration(
            labelText: 'Địa điểm học *',
            border: OutlineInputBorder(),
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
              return 'Vui lòng chọn địa điểm học';
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
          label: const Text('Tải lại địa điểm'),
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

  String _labelForStatus(String status) {
    switch (status) {
      case 'pending':
        return 'Dang cho thanh toan';
      case 'paid':
        return 'Da thanh toan';
      case 'released':
        return 'Da doi soat';
      case 'failed':
        return 'Thanh toan that bai';
      case 'refunded':
        return 'Da hoan tien';
      default:
        return status;
    }
  }

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
          Text(
            'Trang thai thanh toan',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text('Ma giao dich: ${transaction.transactionRef}'),
          const SizedBox(height: 4),
          Text('Trang thai: ${_labelForStatus(transaction.status)}'),
          const SizedBox(height: 4),
          Text('So tien: ${transaction.amount} VND'),
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
  final TextEditingController controller;
  final String label;
  final String? hint;
  final int maxLines;
  final int? maxLength;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;

  const _FormField({
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
    return DropdownButtonFormField<String>(
      initialValue: selected,
      decoration: const InputDecoration(
        labelText: 'Trình độ *',
        border: OutlineInputBorder(),
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
          value != null ? _format(value!) : 'Chọn ngày giờ',
          style: TextStyle(
            color: value != null ? null : colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _ThumbnailPicker extends StatelessWidget {
  final Uint8List? thumbnailBytes;
  final VoidCallback onPick;

  const _ThumbnailPicker({required this.thumbnailBytes, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onPick,
      child: Container(
        height: 160,
        width: double.infinity,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          image: thumbnailBytes != null
              ? DecorationImage(
                  image: MemoryImage(thumbnailBytes!),
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: thumbnailBytes == null
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
                    'Thêm ảnh bìa (tùy chọn)',
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
