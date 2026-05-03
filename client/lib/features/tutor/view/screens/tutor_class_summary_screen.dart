import 'package:client/core/failure/failure.dart';
import 'package:client/core/providers/current_user_notifier.dart';
import 'package:client/features/payments/model/payment_summary.dart';
import 'package:client/features/payments/repositories/payments_remote_repository.dart';
import 'package:fpdart/fpdart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TutorClassSummaryScreen extends ConsumerStatefulWidget {
  final String classCode;

  const TutorClassSummaryScreen({required this.classCode, super.key});

  @override
  ConsumerState<TutorClassSummaryScreen> createState() =>
      _TutorClassSummaryScreenState();
}

class _TutorClassSummaryScreenState
    extends ConsumerState<TutorClassSummaryScreen> {
  PaymentSummary? _summary;
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await ref
        .read(paymentsRemoteRepositoryProvider)
        .getSummaryByClassCode(token: user.token, classCode: widget.classCode);
    if (!mounted) {
      return;
    }

    setState(() => _loading = false);
    if (result is Left<AppFailure, PaymentSummary>) {
      setState(() {
        _summary = null;
        _error = result.value.message;
      });
      return;
    }

    if (result is Right<AppFailure, PaymentSummary>) {
      setState(() {
        _summary = result.value;
        _error = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Chi tiết lớp của Tutor')),
      body: RefreshIndicator(
        onRefresh: _loadSummary,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.classCode,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Màn hình này tối ưu cho deeplink từ thông báo để Tutor mở nhanh tình trạng lớp và payout.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            if (_loading && _summary == null) ...[
              const SizedBox(height: 32),
              const Center(child: CircularProgressIndicator()),
            ] else if (_error != null && _summary == null) ...[
              const SizedBox(height: 20),
              _TutorSummaryMessageCard(
                icon: Icons.error_outline_rounded,
                message: _error!,
                actionLabel: 'Tải lại',
                onPressed: _loading ? null : _loadSummary,
              ),
            ] else if (_summary != null) ...[
              const SizedBox(height: 20),
              _TutorSummaryCard(summary: _summary!),
            ],
          ],
        ),
      ),
    );
  }
}

class _TutorSummaryCard extends StatelessWidget {
  final PaymentSummary summary;

  const _TutorSummaryCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tổng quan thanh toán',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          _TutorSummaryRow(label: 'Trạng thái lớp', value: summary.classStatus),
          _TutorSummaryRow(
            label: 'Creation fee',
            value: '${summary.creationFeeAmount} VND',
          ),
          _TutorSummaryRow(
            label: 'Creation payment',
            value: summary.creationPaymentStatusLabel,
          ),
          _TutorSummaryRow(
            label: 'Học viên hiện tại',
            value: '${summary.currentParticipants}/${summary.maxParticipants}',
          ),
          _TutorSummaryRow(
            label: 'Ngưỡng tối thiểu',
            value: summary.minParticipants.toString(),
          ),
          _TutorSummaryRow(
            label: 'Đã đủ học viên tối thiểu',
            value: summary.minimumParticipantsReached ? 'Có' : 'Chưa',
          ),
          _TutorSummaryRow(
            label: 'Tutor xác nhận dạy',
            value: summary.tutorConfirmationStatus,
          ),
          _TutorSummaryRow(
            label: 'Tổng escrow',
            value: '${summary.totalEscrowHeld} VND',
          ),
          _TutorSummaryRow(
            label: 'Trạng thái payout',
            value: summary.tutorPayoutStatus,
          ),
          _TutorSummaryRow(
            label: 'Số tiền payout',
            value: '${summary.tutorPayoutAmount} VND',
          ),
          _TutorSummaryRow(
            label: 'Khiếu nại đang mở',
            value: summary.activeDisputes.toString(),
          ),
        ],
      ),
    );
  }
}

class _TutorSummaryRow extends StatelessWidget {
  final String label;
  final String value;

  const _TutorSummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _TutorSummaryMessageCard extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? actionLabel;
  final Future<void> Function()? onPressed;

  const _TutorSummaryMessageCard({
    required this.icon,
    required this.message,
    required this.actionLabel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Icon(icon, color: cs.onSurfaceVariant, size: 32),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          if (actionLabel != null && onPressed != null) ...[
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () => onPressed!.call(),
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}
