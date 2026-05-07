import 'dart:async';

import 'package:client/core/failure/failure.dart';
import 'package:client/core/providers/current_user_notifier.dart';
import 'package:client/features/payments/model/payment_transaction_status.dart';
import 'package:client/features/payments/repositories/payments_remote_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import 'package:go_router/go_router.dart';

class PaymentReturnScreen extends ConsumerStatefulWidget {
  final String? transactionRef;
  final String? initialStatus;
  final String? providerOrderId;

  const PaymentReturnScreen({
    super.key,
    required this.transactionRef,
    this.initialStatus,
    this.providerOrderId,
  });

  @override
  ConsumerState<PaymentReturnScreen> createState() =>
      _PaymentReturnScreenState();
}

class _PaymentReturnScreenState extends ConsumerState<PaymentReturnScreen> {
  PaymentTransactionStatus? _transaction;
  Timer? _homeRedirectTimer;
  bool _loading = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPaymentStatus());
  }

  @override
  void dispose() {
    _homeRedirectTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadPaymentStatus() async {
    final transactionRef = widget.transactionRef?.trim() ?? '';
    if (transactionRef.isEmpty) {
      setState(() {
        _message = 'Không tìm thấy mã giao dịch để kiểm tra.';
      });
      return;
    }

    final user = ref.read(currentUserProvider);
    if (user == null) {
      setState(() {
        _message = 'Vui lòng đăng nhập lại để kiểm tra trạng thái thanh toán.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _message = null;
    });

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
      case Right<AppFailure, PaymentTransactionStatus>(value: final status):
        setState(() {
          _transaction = status;
          _loading = false;
          _message = status.message;
        });
        if (status.isSuccessLike) {
          _scheduleHomeRedirect();
        }
      case Left<AppFailure, PaymentTransactionStatus>(value: final failure):
        setState(() {
          _loading = false;
          _message = failure.message;
        });
    }
  }

  void _scheduleHomeRedirect() {
    _homeRedirectTimer?.cancel();
    _homeRedirectTimer = Timer(const Duration(seconds: 2), _goHome);
  }

  void _goHome() {
    if (!mounted) {
      return;
    }
    final user = ref.read(currentUserProvider);
    if (user == null) {
      context.go('/login');
      return;
    }
    context.go(user.role == 'teacher' ? '/teacher' : '/student');
  }

  String get _title {
    final transaction = _transaction;
    if (_loading) {
      return 'Đang kiểm tra thanh toán';
    }
    if (transaction == null) {
      return 'Kết quả thanh toán';
    }
    if (transaction.isSuccessLike) {
      return 'Thanh toán thành công';
    }
    if (transaction.status == 'failed') {
      return 'Thanh toán không thành công';
    }
    return 'Trạng thái thanh toán';
  }

  String _labelForStatus(String status) {
    switch (status) {
      case 'pending':
        return 'Đang chờ thanh toán';
      case 'processing':
        return 'Đang xử lý';
      case 'paid':
        return 'Đã thanh toán';
      case 'released':
        return 'Đã đối soát';
      case 'failed':
        return 'Thanh toán thất bại';
      case 'refunded':
        return 'Đã hoàn tiền';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final transaction = _transaction;
    final colorScheme = Theme.of(context).colorScheme;
    final transactionRef =
        transaction?.transactionRef ?? widget.transactionRef?.trim() ?? '';
    final initialStatus = widget.initialStatus?.trim();

    return Scaffold(
      appBar: AppBar(title: const Text('Thanh toán')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    transaction?.isSuccessLike == true
                        ? Icons.check_circle_rounded
                        : Icons.payments_rounded,
                    size: 56,
                    color: transaction?.isSuccessLike == true
                        ? Colors.green
                        : colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_loading) ...[
                    const Center(child: CircularProgressIndicator()),
                    const SizedBox(height: 16),
                  ],
                  if ((_message ?? '').isNotEmpty)
                    Text(
                      _message!,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  const SizedBox(height: 20),
                  if (transactionRef.isNotEmpty)
                    _InfoRow(label: 'Mã giao dịch', value: transactionRef),
                  if (transaction != null)
                    _InfoRow(
                      label: 'Trạng thái',
                      value: _labelForStatus(transaction.status),
                    )
                  else if (initialStatus != null && initialStatus.isNotEmpty)
                    _InfoRow(
                      label: 'Trạng thái',
                      value: _labelForStatus(initialStatus),
                    ),
                  if ((widget.providerOrderId ?? '').trim().isNotEmpty)
                    _InfoRow(
                      label: 'Mã payOS',
                      value: widget.providerOrderId!.trim(),
                    ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _goHome,
                    icon: const Icon(Icons.home_rounded),
                    label: const Text('Về trang chính'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
