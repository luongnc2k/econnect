import 'dart:async';

import 'package:client/core/providers/current_user_notifier.dart';
import 'package:client/features/payments/repositories/payments_remote_repository.dart';
import 'package:client/features/student/model/class_session.dart';
import 'package:client/features/tutor/model/enrolled_student.dart';
import 'package:client/features/tutor/viewmodel/tutor_class_detail_viewmodel.dart';
import 'package:client/features/tutor/viewmodel/tutor_home_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart' show Left, Right;

class TutorClassDetailScreen extends ConsumerStatefulWidget {
  final ClassSession session;

  const TutorClassDetailScreen({super.key, required this.session});

  @override
  ConsumerState<TutorClassDetailScreen> createState() =>
      _TutorClassDetailScreenState();
}

class _TutorClassDetailScreenState extends ConsumerState<TutorClassDetailScreen> {
  bool _isCancelling = false;
  bool _isCancelled = false;
  late String _statusLabel;

  @override
  void initState() {
    super.initState();
    _statusLabel = widget.session.statusText;
    _isCancelled = _statusLabel.toUpperCase() == 'HUỶ';
  }

  bool get _canCancelClass {
    if (_isCancelled) {
      return false;
    }
    final classId = widget.session.id;
    if (classId == null || classId.isEmpty) {
      return false;
    }

    final normalizedStatus = _statusLabel.toUpperCase();
    if (normalizedStatus == 'HUỶ' || normalizedStatus == 'DONE') {
      return false;
    }

    final startTime = widget.session.startDateTime;
    return startTime == null || startTime.isAfter(DateTime.now());
  }

  Future<void> _confirmCancelClass() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final cs = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          title: const Text('Hủy buổi học này?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Khi xác nhận hủy, hệ thống sẽ tự động xử lý như sau:',
                style: TextStyle(
                  fontSize: 14,
                  color: cs.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              const Text('• Học viên đã đăng ký thành công sẽ được thông báo.'),
              const SizedBox(height: 6),
              const Text('• Học phí của các học viên đã đăng ký sẽ được hoàn lại.'),
              const SizedBox(height: 6),
              const Text('• Bạn sẽ không được hoàn lại phí tạo buổi học.'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Quay lại'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: cs.error,
                foregroundColor: cs.onError,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Xác nhận hủy'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _cancelClass();
    }
  }

  Future<void> _cancelClass() async {
    final classId = widget.session.id;
    final user = ref.read(currentUserProvider);
    if (classId == null || classId.isEmpty || user == null) {
      _showSnackBar('Không thể hủy buổi học lúc này.');
      return;
    }

    setState(() {
      _isCancelling = true;
    });

    final repo = ref.read(paymentsRemoteRepositoryProvider);
    final result = await repo.cancelClass(token: user.token, classId: classId);

    if (!mounted) {
      return;
    }

    switch (result) {
      case Left(value: final failure):
        setState(() {
          _isCancelling = false;
        });
        _showSnackBar(failure.message);
      case Right(value: final summary):
        setState(() {
          _isCancelling = false;
          _isCancelled = summary.classStatus == 'cancelled';
          _statusLabel = _isCancelled ? 'HUỶ' : _statusLabel;
        });
        ref.invalidate(enrolledStudentsProvider(classId));
        unawaited(
          ref.read(tutorHomeViewModelProvider.notifier).refresh(silent: true),
        );
        _showSnackBar(
          'Đã hủy buổi học. Học viên đã đăng ký sẽ được thông báo và hoàn học phí.',
        );
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final classId = widget.session.id ?? '';
    final enrolledAsync = ref.watch(enrolledStudentsProvider(classId));

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: cs.surface,
            flexibleSpace: FlexibleSpaceBar(
              background:
                  widget.session.imageUrl != null &&
                      widget.session.imageUrl!.isNotEmpty
                  ? Image.network(
                      widget.session.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _ThumbnailPlaceholder(cs: cs),
                    )
                  : _ThumbnailPlaceholder(cs: cs),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (widget.session.tags.isNotEmpty)
                        _Chip(
                          label: widget.session.tags.first,
                          color: cs.primaryContainer,
                          textColor: cs.onPrimaryContainer,
                        ),
                      if (widget.session.tags.isNotEmpty) const SizedBox(width: 8),
                      _Chip(
                        label: _statusLabel,
                        color: _isCancelled
                            ? cs.errorContainer
                            : cs.secondaryContainer,
                        textColor: _isCancelled
                            ? cs.onErrorContainer
                            : cs.onSecondaryContainer,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.session.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _InfoGrid(session: widget.session),
                  const SizedBox(height: 20),
                  _ClassCodeCard(code: widget.session.classCode, cs: cs),
                  if (_canCancelClass || _isCancelled) ...[
                    const SizedBox(height: 16),
                    _CancelClassCard(
                      cs: cs,
                      isCancelled: _isCancelled,
                      isLoading: _isCancelling,
                      onCancel: _canCancelClass ? _confirmCancelClass : null,
                    ),
                  ],
                  const SizedBox(height: 24),
                  if (widget.session.description != null &&
                      widget.session.description!.isNotEmpty) ...[
                    _SectionTitle(title: 'Mô tả', cs: cs),
                    const SizedBox(height: 8),
                    Text(
                      widget.session.description!,
                      style: TextStyle(
                        fontSize: 14,
                        color: cs.onSurfaceVariant,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  _SectionTitle(
                    title: 'Học viên đăng ký',
                    trailing: enrolledAsync.maybeWhen(
                      data: (list) => Text(
                        '${list.length} học viên',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: cs.primary,
                        ),
                      ),
                      orElse: () => null,
                    ),
                    cs: cs,
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
          enrolledAsync.when(
            loading: () => const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
            error: (e, _) => SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                child: Text(
                  'Không thể tải danh sách học viên',
                  style: TextStyle(color: cs.error, fontSize: 13),
                ),
              ),
            ),
            data: (students) => students.isEmpty
                ? SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      child: _EmptyStudents(cs: cs),
                    ),
                  )
                : SliverList.separated(
                    itemCount: students.length,
                    separatorBuilder: (_, _) => Divider(
                      indent: 72,
                      height: 1,
                      color: cs.outlineVariant,
                    ),
                    itemBuilder: (_, i) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _StudentTile(student: students[i], cs: cs),
                    ),
                  ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}

class _ThumbnailPlaceholder extends StatelessWidget {
  final ColorScheme cs;

  const _ThumbnailPlaceholder({required this.cs});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: cs.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.image_outlined,
          size: 48,
          color: cs.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;

  const _Chip({
    required this.label,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final ColorScheme cs;

  const _SectionTitle({required this.title, this.trailing, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
          ),
        ),
        const Spacer(),
        trailing ?? const SizedBox.shrink(),
      ],
    );
  }
}

class _InfoGrid extends StatelessWidget {
  final ClassSession session;

  const _InfoGrid({required this.session});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        children: [
          _InfoRow(
            icon: Icons.calendar_today_outlined,
            label: 'Ngày',
            value: session.dateText ?? '--',
            cs: cs,
          ),
          const SizedBox(height: 12),
          _InfoRow(
            icon: Icons.schedule_rounded,
            label: 'Bắt đầu',
            value: session.displayStartTimeText,
            cs: cs,
          ),
          if (session.displayEndTimeText != null) ...[
            const SizedBox(height: 12),
            _InfoRow(
              icon: Icons.timer_outlined,
              label: 'Kết thúc',
              value: session.displayEndTimeText!,
              cs: cs,
            ),
          ],
          const SizedBox(height: 12),
          _InfoRow(
            icon: Icons.location_on_outlined,
            label: 'Địa điểm',
            value: session.location,
            cs: cs,
          ),
          const SizedBox(height: 12),
          _InfoRow(
            icon: Icons.people_outline_rounded,
            label: 'Học viên',
            value: session.slotText ?? '--',
            cs: cs,
          ),
          const SizedBox(height: 12),
          _InfoRow(
            icon: Icons.payments_outlined,
            label: 'Tổng học phí',
            value: session.totalPriceText ?? session.priceText,
            cs: cs,
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final ColorScheme cs;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: cs.primary),
        const SizedBox(width: 12),
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}

class _ClassCodeCard extends StatelessWidget {
  final String? code;
  final ColorScheme cs;

  const _ClassCodeCard({required this.code, required this.cs});

  @override
  Widget build(BuildContext context) {
    if (code == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.qr_code_rounded, size: 22, color: cs.onPrimaryContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mã lớp học',
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onPrimaryContainer.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  code!,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: cs.onPrimaryContainer,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: code!));
              if (!context.mounted) {
                return;
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Đã sao chép mã lớp $code')),
              );
            },
            icon: Icon(
              Icons.copy_rounded,
              size: 20,
              color: cs.onPrimaryContainer,
            ),
            tooltip: 'Sao chép mã lớp',
          ),
        ],
      ),
    );
  }
}

class _CancelClassCard extends StatelessWidget {
  final ColorScheme cs;
  final bool isCancelled;
  final bool isLoading;
  final VoidCallback? onCancel;

  const _CancelClassCard({
    required this.cs,
    required this.isCancelled,
    required this.isLoading,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCancelled ? cs.errorContainer : cs.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCancelled
              ? cs.error.withValues(alpha: 0.2)
              : cs.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isCancelled ? 'Buổi học đã được hủy' : 'Hủy buổi học',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: isCancelled ? cs.onErrorContainer : cs.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isCancelled
                ? 'Các học viên đã đăng ký sẽ nhận được thông báo và hoàn lại học phí.'
                : 'Nếu bạn hủy buổi học, các học viên đã đăng ký thành công sẽ được thông báo và hoàn lại học phí. Phí tạo buổi học sẽ không được hoàn.',
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: isCancelled
                  ? cs.onErrorContainer.withValues(alpha: 0.85)
                  : cs.onSurfaceVariant,
            ),
          ),
          if (!isCancelled) ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: isLoading ? null : onCancel,
              style: OutlinedButton.styleFrom(
                foregroundColor: cs.error,
                side: BorderSide(color: cs.error.withValues(alpha: 0.35)),
              ),
              icon: isLoading
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: cs.error,
                      ),
                    )
                  : const Icon(Icons.cancel_outlined),
              label: Text(
                isLoading ? 'Đang hủy buổi học...' : 'Hủy buổi học',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StudentTile extends StatelessWidget {
  final EnrolledStudent student;
  final ColorScheme cs;

  const _StudentTile({required this.student, required this.cs});

  Color _statusColor() {
    switch (student.status) {
      case 'confirmed':
        return Colors.green;
      case 'completed':
        return Colors.blue;
      case 'no_show':
        return Colors.orange;
      default:
        return cs.onSurfaceVariant;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: cs.surfaceContainerHighest,
            backgroundImage: student.avatarUrl != null
                ? NetworkImage(student.avatarUrl!)
                : null,
            child: student.avatarUrl == null
                ? Text(
                    student.fullName.isNotEmpty
                        ? student.fullName[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: cs.onSurfaceVariant,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.fullName,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  student.statusLabel,
                  style: TextStyle(
                    fontSize: 12,
                    color: _statusColor(),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyStudents extends StatelessWidget {
  final ColorScheme cs;

  const _EmptyStudents({required this.cs});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(
            Icons.people_outline_rounded,
            size: 36,
            color: cs.onSurfaceVariant,
          ),
          const SizedBox(height: 8),
          Text(
            'Chưa có học viên đăng ký',
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
