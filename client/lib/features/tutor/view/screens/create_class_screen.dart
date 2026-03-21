import 'package:client/features/tutor/model/topic_model.dart';
import 'package:client/features/tutor/viewmodel/create_class_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

class CreateClassScreen extends ConsumerStatefulWidget {
  const CreateClassScreen({super.key});

  @override
  ConsumerState<CreateClassScreen> createState() => _CreateClassScreenState();
}

class _CreateClassScreenState extends ConsumerState<CreateClassScreen> {
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationNameController = TextEditingController();
  final _locationAddressController = TextEditingController();
  final _minParticipantsController = TextEditingController(text: '1');
  final _maxParticipantsController = TextEditingController();
  final _priceController = TextEditingController();

  TopicModel? _selectedTopic;
  String _selectedLevel = 'beginner';
  DateTime? _startTime;
  DateTime? _endTime;

  Uint8List? _thumbnailBytes;
  String? _thumbnailFileName;
  String? _thumbnailFilePath;

  static const _levels = [
    ('beginner', 'Cơ bản'),
    ('intermediate', 'Trung cấp'),
    ('advanced', 'Nâng cao'),
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationNameController.dispose();
    _locationAddressController.dispose();
    _minParticipantsController.dispose();
    _maxParticipantsController.dispose();
    _priceController.dispose();
    super.dispose();
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
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
    );
    if (time == null || !mounted) return;

    final picked = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (isStart) {
        _startTime = picked;
        // reset end time if it's now invalid
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
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    setState(() {
      _thumbnailBytes = bytes;
      _thumbnailFileName = picked.name;
      _thumbnailFilePath = picked.path;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedTopic == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn chủ đề')),
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

    final minP = int.tryParse(_minParticipantsController.text) ?? 1;
    final maxP = int.tryParse(_maxParticipantsController.text) ?? 0;

    if (maxP < minP) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Số học viên tối đa phải >= tối thiểu')),
      );
      return;
    }

    final success = await ref.read(createClassViewModelProvider.notifier).submitClass(
          topicId: _selectedTopic!.id,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          level: _selectedLevel,
          locationName: _locationNameController.text.trim(),
          locationAddress: _locationAddressController.text.trim().isEmpty
              ? null
              : _locationAddressController.text.trim(),
          startTime: _startTime!,
          endTime: _endTime!,
          minParticipants: minP,
          maxParticipants: maxP,
          price: double.tryParse(_priceController.text.replaceAll(',', '')) ?? 0,
          thumbnailBytes: _thumbnailBytes,
          thumbnailFileName: _thumbnailFileName,
          thumbnailFilePath: _thumbnailFilePath,
        );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tạo lớp học thành công!')),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final vmState = ref.watch(createClassViewModelProvider);
    final colorScheme = Theme.of(context).colorScheme;

    ref.listen(createClassViewModelProvider, (_, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: colorScheme.error,
          ),
        );
        ref.read(createClassViewModelProvider.notifier).clearError();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tạo lớp học mới'),
        centerTitle: true,
      ),
      body: vmState.isLoadingTopics
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _ThumbnailPicker(
                    thumbnailBytes: _thumbnailBytes,
                    onPick: _pickThumbnail,
                  ),
                  const SizedBox(height: 20),
                  _SectionLabel('Thông tin lớp học'),
                  const SizedBox(height: 12),
                  _FormField(
                    controller: _titleController,
                    label: 'Tiêu đề lớp học *',
                    hint: 'Ví dụ: Luyện giao tiếp tiếng Anh cơ bản',
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Không được để trống' : null,
                  ),
                  const SizedBox(height: 12),
                  _TopicDropdown(
                    topics: vmState.topics,
                    selected: _selectedTopic,
                    onChanged: (t) => setState(() => _selectedTopic = t),
                  ),
                  const SizedBox(height: 12),
                  _LevelDropdown(
                    selected: _selectedLevel,
                    levels: _levels,
                    onChanged: (v) => setState(() => _selectedLevel = v!),
                  ),
                  const SizedBox(height: 12),
                  _FormField(
                    controller: _descriptionController,
                    label: 'Mô tả (tùy chọn)',
                    hint: 'Nội dung sẽ học, yêu cầu học viên...',
                    maxLines: 3,
                  ),
                  const SizedBox(height: 20),
                  _SectionLabel('Địa điểm'),
                  const SizedBox(height: 12),
                  _FormField(
                    controller: _locationNameController,
                    label: 'Tên địa điểm *',
                    hint: 'Ví dụ: Quận 1, TP.HCM',
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Không được để trống' : null,
                  ),
                  const SizedBox(height: 12),
                  _FormField(
                    controller: _locationAddressController,
                    label: 'Địa chỉ chi tiết (tùy chọn)',
                    hint: 'Số nhà, đường, phường...',
                  ),
                  const SizedBox(height: 20),
                  _SectionLabel('Thời gian'),
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
                  _SectionLabel('Học viên & Học phí'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _FormField(
                          controller: _minParticipantsController,
                          label: 'Tối thiểu *',
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          validator: (v) {
                            final n = int.tryParse(v ?? '');
                            if (n == null || n < 1) return 'Tối thiểu 1';
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
                          validator: (v) {
                            final n = int.tryParse(v ?? '');
                            if (n == null || n < 1) return 'Tối thiểu 1';
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
                    validator: (v) {
                      final n = double.tryParse(v ?? '');
                      if (n == null || n < 0) return 'Học phí không hợp lệ';
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),
                  FilledButton(
                    onPressed: vmState.isSubmitting ? null : _submit,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    child: vmState.isSubmitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        : const Text('Tạo lớp học', style: TextStyle(fontSize: 16)),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}

// ─── Private sub-widgets ───────────────────────────────────────────────────

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

class _FormField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final int maxLines;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;

  const _FormField({
    required this.controller,
    required this.label,
    this.hint,
    this.maxLines = 1,
    this.keyboardType,
    this.inputFormatters,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
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

class _TopicDropdown extends StatelessWidget {
  final List<TopicModel> topics;
  final TopicModel? selected;
  final ValueChanged<TopicModel?> onChanged;

  const _TopicDropdown({
    required this.topics,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<TopicModel>(
      value: selected,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Chủ đề *',
        border: OutlineInputBorder(),
      ),
      hint: const Text('Chọn chủ đề'),
      items: topics
          .map((t) => DropdownMenuItem(value: t, child: Text(t.name)))
          .toList(),
      onChanged: onChanged,
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
      value: selected,
      decoration: const InputDecoration(
        labelText: 'Trình độ *',
        border: OutlineInputBorder(),
      ),
      items: levels
          .map((l) => DropdownMenuItem(value: l.$1, child: Text(l.$2)))
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

  String _format(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final mo = dt.month.toString().padLeft(2, '0');
    return '$h:$m $d/$mo/${dt.year}';
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
                  Icon(Icons.add_photo_alternate_outlined,
                      size: 40, color: colorScheme.onSurfaceVariant),
                  const SizedBox(height: 8),
                  Text('Thêm ảnh bìa (tùy chọn)',
                      style: TextStyle(color: colorScheme.onSurfaceVariant)),
                ],
              )
            : Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: CircleAvatar(
                    backgroundColor: colorScheme.surface.withValues(alpha: 0.8),
                    radius: 16,
                    child: Icon(Icons.edit_outlined, size: 16, color: colorScheme.onSurface),
                  ),
                ),
              ),
      ),
    );
  }
}
