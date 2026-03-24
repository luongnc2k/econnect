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
import 'package:client/features/student/model/student_class_booking_status.dart';
import 'package:client/features/student/repositories/student_remote_repository.dart';
import 'package:client/features/student/view/widgets/class_detail_enrolled_avatars.dart';
import 'package:client/features/student/view/widgets/class_detail_info_grid.dart';
import 'package:client/features/student/view/widgets/class_detail_location_card.dart';
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
  static const int _maxPollAttempts = 60;
  static const int _maxConsecutivePollErrors = 3;

  bool _submitting = false;
  bool _polling = false;
  PaymentTransactionStatus? _transaction;
  StudentClassBookingStatus? _bookingStatus;
  Timer? _pollTimer;
  int _pollAttempts = 0;
  int _consecutivePollErrors = 0;
  bool _loadingBookingStatus = false;

  @override
  void initState() {
    super.initState();
    _loadBookingStatus();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadBookingStatus() async {
    final user = ref.read(currentUserProvider);
    final classId = widget.session.id;
    if (user == null || classId == null || classId.isEmpty) {
      return;
    }

    setState(() => _loadingBookingStatus = true);
    final result = await ref
        .read(studentRemoteRepositoryProvider)
        .getMyBookingStatus(token: user.token, classId: classId);

    if (!mounted) {
      return;
    }

    setState(() {
      _loadingBookingStatus = false;
      if (result is Right<AppFailure, StudentClassBookingStatus>) {
        _bookingStatus = result.value;
      }
    });
  }

  Future<void> _startPayment() async {
    if (_submitting || _polling) {
      return;
    }
    final user = ref.read(currentUserProvider);
    final classId = widget.session.id;
    if (user == null || classId == null || classId.isEmpty) {
      _showMessage('Không tìm thấy thông tin lớp học để thanh toán.');
      return;
    }

    setState(() => _submitting = true);
    final result = await ref
        .read(paymentsRemoteRepositoryProvider)
        .createJoinPayment(token: user.token, classId: classId);

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
      _showMessage('Không nhận được URL thanh toán từ hệ thống.');
      return;
    }

    final launched = await launchUrl(
      Uri.parse(redirectUrl),
      mode: LaunchMode.externalApplication,
    );
    if (!launched && mounted) {
      _stopPolling();
      _showMessage(
        'Không mở được cổng thanh toán. Bạn có thể copy URL từ log backend để test.',
      );
    }
  }

  void _beginPolling(String transactionRef) {
    _pollTimer?.cancel();
    setState(() {
      _polling = true;
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
          'Đã hết thời gian đợi kết quả thanh toán. Bạn hãy thử tải lại trạng thái sau.',
        );
        return;
      }

      final result = await ref
          .read(paymentsRemoteRepositoryProvider)
          .getTransactionStatus(
            token: user.token,
            transactionRef: transactionRef,
          );
      if (!mounted) return;

      if (result is Right<AppFailure, PaymentTransactionStatus>) {
        final status = result.value;
        setState(() {
          _transaction = status;
          _consecutivePollErrors = 0;
        });
        if (status.isTerminal) {
          _stopPolling();
        }
      } else if (result is Left<AppFailure, PaymentTransactionStatus>) {
        _consecutivePollErrors += 1;
        if (_consecutivePollErrors >= _maxConsecutivePollErrors) {
          _stopPolling();
          _showMessage(result.value.message);
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  bool _transactionShowsRegistered(PaymentTransactionStatus transaction) {
    return transaction.isSuccessLike &&
        {'confirmed', 'completed'}.contains(transaction.bookingStatus);
  }

  bool _transactionShowsPending(PaymentTransactionStatus transaction) {
    return !transaction.isTerminal &&
        (transaction.bookingStatus == 'payment_pending' ||
            transaction.status == 'pending' ||
            transaction.status == 'processing');
  }

  bool get _shouldHidePaymentAction {
    final transaction = _transaction;
    if (transaction != null) {
      if (_transactionShowsRegistered(transaction)) {
        return true;
      }
      if (_transactionShowsPending(transaction)) {
        return true;
      }
    }

    return _bookingStatus?.shouldHidePaymentAction ?? false;
  }

  _StudentRegistrationCardData? _resolveStatusCardData() {
    final transaction = _transaction;
    if (transaction != null) {
      final isRegistered = _transactionShowsRegistered(transaction);
      final isPending = _transactionShowsPending(transaction);
      final badgeLabels = <String>[
        transaction.status.toUpperCase(),
        if ((transaction.bookingStatus ?? '').isNotEmpty)
          'BOOKING ${transaction.bookingStatus!.toUpperCase()}',
        if ((transaction.escrowStatus ?? '').isNotEmpty)
          'ESCROW ${transaction.escrowStatus!.toUpperCase()}',
      ];

      return _StudentRegistrationCardData(
        title: isRegistered ? 'Đăng ký thành công' : 'Trạng thái thanh toán',
        message: isRegistered
            ? 'Bạn đã đăng ký buổi học thành công'
            : transaction.message ?? 'Đang cập nhật kết quả giao dịch.',
        amount: transaction.amount,
        reference: transaction.transactionRef,
        badgeLabels: badgeLabels,
        kind: isRegistered
            ? _StudentRegistrationCardKind.success
            : isPending
            ? _StudentRegistrationCardKind.pending
            : transaction.status == 'failed'
            ? _StudentRegistrationCardKind.error
            : _StudentRegistrationCardKind.neutral,
      );
    }

    final bookingStatus = _bookingStatus;
    if (bookingStatus == null || !bookingStatus.hasBooking) {
      return null;
    }

    final badgeLabels = <String>[
      if ((bookingStatus.bookingStatus ?? '').isNotEmpty)
        'BOOKING ${bookingStatus.bookingStatus!.toUpperCase()}',
      if ((bookingStatus.paymentStatus ?? '').isNotEmpty)
        'PAYMENT ${bookingStatus.paymentStatus!.toUpperCase()}',
      if ((bookingStatus.escrowStatus ?? '').isNotEmpty)
        'ESCROW ${bookingStatus.escrowStatus!.toUpperCase()}',
    ];

    final isRegistered = bookingStatus.isRegistered;
    final isPending = bookingStatus.hasPendingRegistration;
    final message = isRegistered
        ? 'Bạn đã đăng ký buổi học thành công. Không cần đăng ký và thanh toán lại.'
        : isPending
        ? 'Bạn đang có giao dịch đăng ký cho buổi học này. Vui lòng chờ hệ thống cập nhật trạng thái.'
        : 'Hệ thống đã ghi nhận giao dịch trước đó của bạn cho buổi học này.';

    return _StudentRegistrationCardData(
      title: isRegistered ? 'Đăng ký thành công' : 'Trạng thái đăng ký',
      message: message,
      amount: bookingStatus.tuitionAmount,
      reference: bookingStatus.paymentReference,
      badgeLabels: badgeLabels,
      kind: isRegistered
          ? _StudentRegistrationCardKind.success
          : isPending
          ? _StudentRegistrationCardKind.pending
          : _StudentRegistrationCardKind.neutral,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hPad = responsiveHPad(context);
    final session = widget.session;
    final statusCardData = _resolveStatusCardData();
    final shouldShowPaymentAction =
        !_loadingBookingStatus && !_shouldHidePaymentAction;

    return Scaffold(
      bottomNavigationBar: _loadingBookingStatus && statusCardData == null
          ? SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(hPad, 8, hPad, 12),
                child: const _BookingStatusLoadingCard(),
              ),
            )
          : shouldShowPaymentAction
          ? SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(hPad, 8, hPad, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _PaymentActionCard(
                      onSubmit: _submitting ? null : _startPayment,
                      submitting: _submitting,
                      polling: _polling,
                      transaction: _transaction,
                      sessionPriceText: session.priceText,
                    ),
                  ],
                ),
              ),
            )
          : null,
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
                    'Quay lại',
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
                            .map(
                              (t) => AppTagChip(
                                label: t,
                                fontSize: 13,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 5,
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Text(
                      session.title,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
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
                    const SizedBox(height: 16),
                    ClassDetailLocationCard(session: session),
                    const SizedBox(height: 20),
                    if (statusCardData != null)
                      _StudentRegistrationStatusCard(data: statusCardData),
                    const SizedBox(height: 24),
                    Text(
                      'Giảng viên',
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
                              AppRoutes.userProfile.replaceFirst(
                                ':userId',
                                session.teacherId!,
                              ),
                            ),
                    ),
                    if (session.enrolledInitials.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Text(
                        'Học viên đã đăng ký (${session.slotText?.split(' ').first ?? ''})',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
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
                          AppRoutes.userProfile.replaceFirst(
                            ':userId',
                            student.id,
                          ),
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
  final VoidCallback? onSubmit;
  final bool submitting;
  final bool polling;
  final PaymentTransactionStatus? transaction;
  final String sessionPriceText;

  const _PaymentActionCard({
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
            'Thanh toán học phí',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Thanh toán sẽ được mở bằng payOS trong browser, app sẽ tự động poll trạng thái giao dịch.',
            style: TextStyle(color: cs.onSurfaceVariant, height: 1.4),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.account_balance_wallet_rounded, color: cs.primary),
                const SizedBox(width: 10),
                Text(
                  'Cổng thanh toán: payOS',
                  style: TextStyle(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Học phí hiện tại: $sessionPriceText',
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
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
            onPressed: submitting || polling ? null : onSubmit,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              submitting ? 'Đang tạo giao dịch...' : 'Đăng ký và thanh toán',
            ),
          ),
          if (transaction != null) ...[
            const SizedBox(height: 10),
            Text(
              'Mã giao dịch: ${transaction!.transactionRef}',
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
            'Trạng thái thanh toán',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StatusBadge(label: transaction.status.toUpperCase()),
              if ((transaction.escrowStatus ?? '').isNotEmpty)
                StatusBadge(
                  label: 'ESCROW ${transaction.escrowStatus!.toUpperCase()}',
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(transaction.message ?? 'Đang cập nhật kết quả giao dịch'),
          const SizedBox(height: 8),
          Text('Số tiền: ${transaction.amount} VND'),
          if (transaction.bookingStatus != null)
            Text('Booking: ${transaction.bookingStatus}'),
        ],
      ),
    );
  }
}

class _BookingStatusLoadingCard extends StatelessWidget {
  const _BookingStatusLoadingCard();

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
      child: const Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Expanded(child: Text('Đang kiểm tra trạng thái đăng ký của bạn...')),
        ],
      ),
    );
  }
}

class _StudentRegistrationStatusCard extends StatelessWidget {
  final _StudentRegistrationCardData data;

  const _StudentRegistrationStatusCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tone = switch (data.kind) {
      _StudentRegistrationCardKind.success => cs.secondaryContainer,
      _StudentRegistrationCardKind.pending => cs.primaryContainer,
      _StudentRegistrationCardKind.error => cs.errorContainer,
      _StudentRegistrationCardKind.neutral => cs.surfaceContainerHighest,
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
            data.title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          if (data.badgeLabels.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: data.badgeLabels
                  .map((label) => StatusBadge(label: label))
                  .toList(),
            ),
          ],
          const SizedBox(height: 10),
          Text(data.message),
          if (data.amount != null) ...[
            const SizedBox(height: 8),
            Text('Số tiền: ${data.amount} VND'),
          ],
          if ((data.reference ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Mã giao dịch: ${data.reference}'),
          ],
        ],
      ),
    );
  }
}

enum _StudentRegistrationCardKind { success, pending, error, neutral }

class _StudentRegistrationCardData {
  final String title;
  final String message;
  final int? amount;
  final String? reference;
  final List<String> badgeLabels;
  final _StudentRegistrationCardKind kind;

  const _StudentRegistrationCardData({
    required this.title,
    required this.message,
    required this.amount,
    required this.reference,
    required this.badgeLabels,
    required this.kind,
  });
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
