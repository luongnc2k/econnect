import 'dart:async';

import 'package:client/core/failure/failure.dart';
import 'package:client/core/providers/current_user_notifier.dart';
import 'package:client/core/router/app_router.dart';
import 'package:client/core/utils.dart';
import 'package:client/core/widgets/app_tag_chip.dart';
import 'package:client/core/widgets/status_badge.dart';
import 'package:client/features/payments/model/payment_transaction_status.dart';
import 'package:client/features/payments/repositories/payments_remote_repository.dart';
import 'package:client/features/student/model/class_session.dart';
import 'package:client/features/student/view/widgets/class_detail_enrolled_avatars.dart';
import 'package:client/features/student/view/widgets/class_detail_info_grid.dart';
import 'package:client/features/student/view/widgets/class_detail_teacher_card.dart';
import 'package:fpdart/fpdart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

class ClassDetailScreen extends ConsumerStatefulWidget {
  final ClassSession session;

  const ClassDetailScreen({super.key, required this.session});

  @override
  ConsumerState<ClassDetailScreen> createState() => _ClassDetailScreenState();
}

class _ClassDetailScreenState extends ConsumerState<ClassDetailScreen> {
  String _selectedProvider = 'momo';
  bool _submitting = false;
  bool _polling = false;
  PaymentTransactionStatus? _transaction;
  Timer? _pollTimer;

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _startPayment() async {
    final user = ref.read(currentUserProvider);
    final classId = widget.session.id;
    if (user == null || classId == null || classId.isEmpty) {
      _showMessage('Khong tim thay thong tin lop hoc de thanh toan.');
      return;
    }

    setState(() => _submitting = true);
    final result = await ref.read(paymentsRemoteRepositoryProvider).createJoinPayment(
          token: user.token,
          classId: classId,
          provider: _selectedProvider,
        );

    if (!mounted) return;
    setState(() => _submitting = false);

    PaymentTransactionStatus? payment;
    if (result is Left<AppFailure, PaymentTransactionStatus>) {
      _showMessage(result.value.message);
    } else if (result is Right<AppFailure, PaymentTransactionStatus>) {
      payment = result.value;
    }
    if (payment == null || !mounted) {
      return;
    }

    setState(() => _transaction = payment);
    _beginPolling(payment.transactionRef);
    final redirectUrl = payment.redirectUrl;
    if (redirectUrl == null || redirectUrl.isEmpty) {
      _showMessage('Khong nhan duoc URL thanh toan tu he thong.');
      return;
    }

    final launched = await launchUrl(
      Uri.parse(redirectUrl),
      mode: LaunchMode.externalApplication,
    );
    if (!launched && mounted) {
      _showMessage('Khong mo duoc cong thanh toan. Ban co the copy URL tu log backend de test.');
    }
  }

  void _beginPolling(String transactionRef) {
    _pollTimer?.cancel();
    setState(() => _polling = true);
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      final user = ref.read(currentUserProvider);
      if (user == null) {
        _stopPolling();
        return;
      }

      final result = await ref.read(paymentsRemoteRepositoryProvider).getTransactionStatus(
            token: user.token,
            transactionRef: transactionRef,
          );
      if (!mounted) return;

      if (result is Right<AppFailure, PaymentTransactionStatus>) {
        final status = result.value;
        setState(() => _transaction = status);
        if (status.isTerminal) {
          _stopPolling();
        }
      }
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    if (mounted) {
      setState(() => _polling = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hPad = responsiveHPad(context);
    final session = widget.session;

    return Scaffold(
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(hPad, 8, hPad, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PaymentActionCard(
                provider: _selectedProvider,
                onProviderChanged: (value) => setState(() => _selectedProvider = value),
                onSubmit: _submitting ? null : _startPayment,
                submitting: _submitting,
                polling: _polling,
                transaction: _transaction,
                sessionPriceText: session.priceText,
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(hPad - 8, 8, hPad, 0),
                child: TextButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.chevron_left, color: cs.primary),
                  label: Text(
                    'Quay lai',
                    style: TextStyle(color: cs.primary, fontSize: 16),
                  ),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(hPad, 4, hPad, 0),
                child: _HeroCard(
                  imageUrl: session.imageUrl,
                  statusText: session.statusText,
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: hPad),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (session.tags.isNotEmpty) ...[
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: session.tags
                            .map((t) => AppTagChip(
                                  label: t,
                                  fontSize: 13,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                ))
                            .toList(),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Text(
                      session.title,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: cs.onSurface,
                            height: 1.2,
                          ),
                    ),
                    if (session.description != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        session.description!,
                        style: TextStyle(
                          fontSize: 14,
                          color: cs.onSurfaceVariant,
                          height: 1.55,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    ClassDetailInfoGrid(session: session),
                    const SizedBox(height: 20),
                    if (_transaction != null)
                      _StudentPaymentStatusCard(transaction: _transaction!),
                    const SizedBox(height: 24),
                    Text(
                      'Giang vien',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface,
                          ),
                    ),
                    const SizedBox(height: 12),
                    ClassDetailTeacherCard(
                      name: session.teacherName,
                      avatarUrl: session.teacherAvatarUrl,
                      rating: session.teacherRating,
                      sessionCount: session.teacherSessionCount,
                      onTap: session.teacherId == null
                          ? null
                          : () => context.push(
                                AppRoutes.userProfile.replaceFirst(':userId', session.teacherId!),
                              ),
                    ),
                    if (session.enrolledInitials.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Text(
                        'Hoc vien da dang ky (${session.slotText?.split(' ').first ?? ''})',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: cs.onSurface,
                            ),
                      ),
                      const SizedBox(height: 12),
                      ClassDetailEnrolledAvatars(
                        students: session.enrolledStudents,
                        initials: session.enrolledInitials,
                        extra: session.extraEnrolled ?? 0,
                        onAvatarTap: (student) => context.push(
                          AppRoutes.userProfile.replaceFirst(':userId', student.id),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentActionCard extends StatelessWidget {
  final String provider;
  final ValueChanged<String> onProviderChanged;
  final VoidCallback? onSubmit;
  final bool submitting;
  final bool polling;
  final PaymentTransactionStatus? transaction;
  final String sessionPriceText;

  const _PaymentActionCard({
    required this.provider,
    required this.onProviderChanged,
    required this.onSubmit,
    required this.submitting,
    required this.polling,
    required this.transaction,
    required this.sessionPriceText,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Thanh toan hoc phi',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Mo cong thanh toan trong browser, app se tu dong poll trang thai giao dich.',
            style: TextStyle(color: cs.onSurfaceVariant, height: 1.4),
          ),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'momo', label: Text('MoMo')),
              ButtonSegment(value: 'vnpay', label: Text('VNPAY')),
            ],
            selected: {provider},
            onSelectionChanged: (values) => onProviderChanged(values.first),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Hoc phi hien tai: $sessionPriceText',
                  style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600),
                ),
              ),
              if (polling)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: onSubmit,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(submitting ? 'Dang tao giao dich...' : 'Dang ky va thanh toan'),
          ),
          if (transaction != null) ...[
            const SizedBox(height: 10),
            Text(
              'Transaction: ${transaction!.transactionRef}',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class _StudentPaymentStatusCard extends StatelessWidget {
  final PaymentTransactionStatus transaction;

  const _StudentPaymentStatusCard({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tone = switch (transaction.status) {
      'released' => cs.primaryContainer,
      'paid' => cs.secondaryContainer,
      'refunded' => cs.tertiaryContainer,
      'failed' => cs.errorContainer,
      _ => cs.surfaceContainerHighest,
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tone,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Trang thai thanh toan',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StatusBadge(label: transaction.status.toUpperCase()),
              if ((transaction.escrowStatus ?? '').isNotEmpty)
                StatusBadge(label: 'ESCROW ${transaction.escrowStatus!.toUpperCase()}'),
            ],
          ),
          const SizedBox(height: 10),
          Text(transaction.message ?? 'Dang cap nhat ket qua giao dich'),
          const SizedBox(height: 8),
          Text('So tien: ${transaction.amount} VND'),
          if (transaction.bookingStatus != null) Text('Booking: ${transaction.bookingStatus}'),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final String? imageUrl;
  final String statusText;

  const _HeroCard({this.imageUrl, required this.statusText});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            imageUrl != null && imageUrl!.isNotEmpty
                ? Image.network(
                    imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const _GradientPlaceholder(),
                  )
                : const _GradientPlaceholder(),
            Positioned(
              top: 12,
              left: 12,
              child: StatusBadge(label: statusText),
            ),
          ],
        ),
      ),
    );
  }
}

class _GradientPlaceholder extends StatelessWidget {
  const _GradientPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3B5BDB), Color(0xFF5C7CFA)],
        ),
      ),
      child: const Center(
        child: Icon(Icons.menu_book_rounded, size: 56, color: Colors.white54),
      ),
    );
  }
}
