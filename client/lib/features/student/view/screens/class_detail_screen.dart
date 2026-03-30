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
import 'package:client/features/student/model/student_tutor_review_status.dart';
import 'package:client/features/student/repositories/student_remote_repository.dart';
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

class _ClassDetailScreenState extends ConsumerState<ClassDetailScreen>
    with WidgetsBindingObserver {
  static const int _maxPollAttempts = 60;
  static const int _maxConsecutivePollErrors = 3;
  static const String _fallbackHotline = '0335837165';

  bool _submitting = false;
  bool _polling = false;
  PaymentTransactionStatus? _transaction;
  StudentClassBookingStatus? _bookingStatus;
  StudentTutorReviewStatus? _reviewStatus;
  Timer? _pollTimer;
  int _pollAttempts = 0;
  int _consecutivePollErrors = 0;
  bool _loadingBookingStatus = false;
  bool _loadingReviewStatus = false;
  bool _savingReview = false;
  bool _pollRequestInFlight = false;
  bool _awaitingExternalPaymentReturn = false;
  bool _paymentAppWasBackgrounded = false;
  bool _resumeStatusCheckInFlight = false;
  int _selectedReviewRating = 0;
  final _reviewCommentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadBookingStatus();
    _loadTutorReviewStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    _reviewCommentController.dispose();
    super.dispose();
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
    final redirectUrl = payment.redirectUrl;
    if (redirectUrl == null || redirectUrl.isEmpty) {
      _showMessage('Không nhận được URL thanh toán từ hệ thống.');
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
    );
    if (!launched && mounted) {
      _stopPolling();
      _awaitingExternalPaymentReturn = false;
      _showMessage(
        'Không mở được cổng thanh toán. Bạn có thể thử mở lại giao dịch sau.',
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
      _showMessage('Không tìm thấy link thanh toán để mở lại.');
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
      _polling = true;
      _pollAttempts = 0;
      _consecutivePollErrors = 0;
    });
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
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
        _showMessage(
          'Đã hết thời gian đợi kết quả thanh toán. Bạn hãy thử tải lại trạng thái sau.',
        );
        return;
      }

      _pollRequestInFlight = true;
      try {
        final result = await _fetchTransactionStatus(
          token: user.token,
          transactionRef: transactionRef,
        );
        if (!mounted) return;

        if (result is Right<AppFailure, PaymentTransactionStatus>) {
          final status = result.value;
          _handleTransactionStatusUpdate(status);
          _consecutivePollErrors = 0;
        } else if (result is Left<AppFailure, PaymentTransactionStatus>) {
          _consecutivePollErrors += 1;
          if (_consecutivePollErrors >= _maxConsecutivePollErrors) {
            _stopPolling();
            _showMessage(result.value.message);
          }
        }
      } finally {
        _pollRequestInFlight = false;
      }
    });
  }

  Future<void> _loadTutorReviewStatus() async {
    final user = ref.read(currentUserProvider);
    final classId = widget.session.id;
    if (user == null || classId == null || classId.isEmpty) {
      return;
    }

    setState(() => _loadingReviewStatus = true);
    final result = await ref
        .read(studentRemoteRepositoryProvider)
        .getMyTutorReview(token: user.token, classId: classId);

    if (!mounted) {
      return;
    }

    setState(() {
      _loadingReviewStatus = false;
      if (result is Right<AppFailure, StudentTutorReviewStatus>) {
        _reviewStatus = result.value;
        _selectedReviewRating = result.value.review?.rating ?? 0;
        final comment = result.value.review?.comment ?? '';
        _reviewCommentController.value = TextEditingValue(
          text: comment,
          selection: TextSelection.collapsed(offset: comment.length),
        );
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

      if (result is Right<AppFailure, PaymentTransactionStatus>) {
        final status = result.value;
        _handleTransactionStatusUpdate(status);
        if (!status.isTerminal) {
          _stopPolling();
          _showMessage(
            'Bạn đã đóng cửa sổ thanh toán. App sẽ dừng chờ thanh toán; bạn có thể bấm "Tiếp tục thanh toán" để mở lại QR.',
          );
        }
      } else {
        _stopPolling();
        _showMessage(
          'Bạn đã đóng cửa sổ thanh toán. App sẽ dừng chờ thanh toán; bạn có thể bấm "Tiếp tục thanh toán" để mở lại QR.',
        );
      }
    } finally {
      _awaitingExternalPaymentReturn = false;
      _resumeStatusCheckInFlight = false;
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

  void _handleTransactionStatusUpdate(PaymentTransactionStatus status) {
    if (!mounted) {
      return;
    }

    setState(() {
      _transaction = status;
    });

    if (status.isTerminal) {
      _awaitingExternalPaymentReturn = false;
      _stopPolling();
    }
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _pollRequestInFlight = false;
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

  bool get _canResumePendingTransaction {
    final transaction = _transaction;
    final redirectUrl = transaction?.redirectUrl;
    return transaction != null &&
        _transactionShowsPending(transaction) &&
        !_polling &&
        redirectUrl != null &&
        redirectUrl.isNotEmpty;
  }

  bool get _shouldHidePaymentAction {
    final transaction = _transaction;
    if (transaction != null) {
      if (_transactionShowsRegistered(transaction)) {
        return true;
      }
      if (_transactionShowsPending(transaction)) {
        return !_canResumePendingTransaction;
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
        ? 'Bạn đã đăng ký buổi học thành công'
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

  int get _reviewCommentWordCount => _countWords(_reviewCommentController.text);

  String get _reviewHotline {
    final hotline = _reviewStatus?.hotline.trim() ?? '';
    return hotline.isEmpty ? _fallbackHotline : hotline;
  }

  String? get _reviewValidationMessage {
    if ((_reviewStatus?.canReview ?? false) == false) {
      return _reviewStatus?.reason;
    }
    if (_reviewCommentWordCount > 100) {
      return 'Nhận xét không được vượt quá 100 từ.';
    }
    return null;
  }

  Future<void> _submitTutorReview() async {
    final user = ref.read(currentUserProvider);
    final classId = widget.session.id;
    final reviewStatus = _reviewStatus;
    if (user == null || classId == null || classId.isEmpty) {
      _showMessage('Không tìm thấy buổi học để gửi đánh giá.');
      return;
    }
    if (reviewStatus == null) {
      _showMessage('Không tải được trạng thái đánh giá tutor.');
      return;
    }
    if (!reviewStatus.canReview) {
      _showMessage(
        reviewStatus.reason ??
            'Bạn chưa thể gửi đánh giá cho tutor vào lúc này.',
      );
      return;
    }
    if (_reviewCommentWordCount > 100) {
      _showMessage('Nhận xét không được vượt quá 100 từ.');
      return;
    }

    setState(() => _savingReview = true);
    final result = await ref
        .read(studentRemoteRepositoryProvider)
        .submitTutorReview(
          token: user.token,
          classId: classId,
          rating: _selectedReviewRating,
          comment: _reviewCommentController.text.trim(),
        );

    if (!mounted) {
      return;
    }

    setState(() => _savingReview = false);
    if (result is Right<AppFailure, StudentTutorReviewStatus>) {
      setState(() {
        _reviewStatus = result.value;
        _selectedReviewRating =
            result.value.review?.rating ?? _selectedReviewRating;
      });
      _showMessage(
        result.value.alreadyReviewed
            ? 'Đánh giá tutor đã được lưu thành công.'
            : 'Đã gửi đánh giá tutor thành công.',
      );
      return;
    }

    if (result is Left<AppFailure, StudentTutorReviewStatus>) {
      _showMessage(result.value.message);
    }
  }

  Future<void> _callReviewHotline() async {
    final launched = await launchUrl(Uri.parse('tel:$_reviewHotline'));
    if (!launched && mounted) {
      _showMessage(
        'Không mở được trình gọi điện. Hotline EConnect: $_reviewHotline',
      );
    }
  }

  int _countWords(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return 0;
    }
    return normalized
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .length;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hPad = responsiveHPad(context);
    final session = widget.session;
    final statusCardData = _resolveStatusCardData();
    final shouldShowPaymentAction =
        !_loadingBookingStatus && !_shouldHidePaymentAction;
    final paymentActionLabel = _canResumePendingTransaction
        ? 'Tiếp tục thanh toán'
        : 'Đăng ký và thanh toán';

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
                      onSubmit: _submitting
                          ? null
                          : _canResumePendingTransaction
                          ? _resumePendingPayment
                          : _startPayment,
                      submitting: _submitting,
                      polling: _polling,
                      transaction: _transaction,
                      sessionPriceText: session.priceText,
                      submitLabel: paymentActionLabel,
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
              const SizedBox(height: 14),
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
                                fontSize: 12,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 10),
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
                      const SizedBox(height: 6),
                      Text(
                        session.description!,
                        style: TextStyle(
                          fontSize: 14,
                          color: cs.onSurfaceVariant,
                          height: 1.55,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    ClassDetailInfoGrid(session: session),
                    const SizedBox(height: 16),
                    if (statusCardData != null)
                      _StudentRegistrationStatusCard(data: statusCardData),
                    const SizedBox(height: 18),
                    Text(
                      'Giảng viên',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 10),
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
                    const SizedBox(height: 18),
                    if (_loadingReviewStatus || _reviewStatus != null)
                      _TutorReviewSection(
                        loading: _loadingReviewStatus,
                        saving: _savingReview,
                        status: _reviewStatus,
                        selectedRating: _selectedReviewRating,
                        wordCount: _reviewCommentWordCount,
                        validationMessage: _reviewValidationMessage,
                        commentController: _reviewCommentController,
                        onSelectRating: (rating) {
                          setState(() => _selectedReviewRating = rating);
                        },
                        onCommentChanged: (_) => setState(() {}),
                        onSubmit: _submitTutorReview,
                        onCallHotline: _callReviewHotline,
                      ),
                    if (session.enrolledInitials.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      Text(
                        'Học viên đã đăng ký (${session.slotText?.split(' ').first ?? ''})',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: cs.onSurface,
                            ),
                      ),
                      const SizedBox(height: 10),
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
                    const SizedBox(height: 16),
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
  final String submitLabel;

  const _PaymentActionCard({
    required this.onSubmit,
    required this.submitting,
    required this.polling,
    required this.transaction,
    required this.sessionPriceText,
    required this.submitLabel,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
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
            'Thanh toán sẽ được mở bằng payOS trong browser, app sẽ tự động kiểm tra trạng thái giao dịch.',
            style: TextStyle(color: cs.onSurfaceVariant, height: 1.4),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.account_balance_wallet_rounded, color: cs.primary),
                const SizedBox(width: 8),
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
          const SizedBox(height: 10),
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
          const SizedBox(height: 10),
          FilledButton(
            onPressed: submitting || polling ? null : onSubmit,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(submitting ? 'Đang tạo giao dịch...' : submitLabel),
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

class _BookingStatusLoadingCard extends StatelessWidget {
  const _BookingStatusLoadingCard();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 10),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tone,
        borderRadius: BorderRadius.circular(14),
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
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: data.badgeLabels
                  .map((label) => StatusBadge(label: label))
                  .toList(),
            ),
          ],
          const SizedBox(height: 8),
          Text(data.message),
          if (data.amount != null) ...[
            const SizedBox(height: 6),
            Text('Số tiền: ${data.amount} VND'),
          ],
          if ((data.reference ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
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

class _TutorReviewSection extends StatelessWidget {
  final bool loading;
  final bool saving;
  final StudentTutorReviewStatus? status;
  final int selectedRating;
  final int wordCount;
  final String? validationMessage;
  final TextEditingController commentController;
  final ValueChanged<int> onSelectRating;
  final ValueChanged<String> onCommentChanged;
  final VoidCallback onSubmit;
  final VoidCallback onCallHotline;

  const _TutorReviewSection({
    required this.loading,
    required this.saving,
    required this.status,
    required this.selectedRating,
    required this.wordCount,
    required this.validationMessage,
    required this.commentController,
    required this.onSelectRating,
    required this.onCommentChanged,
    required this.onSubmit,
    required this.onCallHotline,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final reviewStatus = status;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Đánh giá tutor',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Sau mỗi buổi học đã kết thúc, bạn có thể chấm từ 0 đến 5 sao và để lại nhận xét ngắn cho tutor.',
            style: TextStyle(color: cs.onSurfaceVariant, height: 1.4),
          ),
          if (loading && reviewStatus == null) ...[
            const SizedBox(height: 12),
            const Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 10),
                Expanded(child: Text('Đang tải trạng thái đánh giá...')),
              ],
            ),
          ] else if (reviewStatus != null) ...[
            const SizedBox(height: 14),
            if (reviewStatus.canReview) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton(
                    key: const Key('tutorReviewStar-0'),
                    onPressed: () => onSelectRating(0),
                    child: const Text('0 sao'),
                  ),
                  ...List.generate(5, (index) {
                    final rating = index + 1;
                    return IconButton(
                      key: Key('tutorReviewStar-$rating'),
                      onPressed: () => onSelectRating(rating),
                      icon: Icon(
                        rating <= selectedRating
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        color: const Color(0xFFFCC419),
                      ),
                      tooltip: '$rating sao',
                    );
                  }),
                ],
              ),
              Text(
                'Mức đánh giá hiện tại: $selectedRating/5 sao',
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('tutorReviewCommentField'),
                controller: commentController,
                minLines: 3,
                maxLines: 4,
                enabled: !saving,
                onChanged: onCommentChanged,
                decoration: InputDecoration(
                  labelText: 'Nhận xét của bạn',
                  hintText: 'Nhập nhận xét ngắn, tối đa 100 từ.',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      validationMessage ??
                          (reviewStatus.alreadyReviewed
                              ? 'Bạn có thể cập nhật lại đánh giá này bất cứ lúc nào.'
                              : 'Nhận xét không bắt buộc, nhưng sẽ giúp tutor cải thiện chất lượng dạy.'),
                      style: TextStyle(
                        fontSize: 12,
                        color: validationMessage == null
                            ? cs.onSurfaceVariant
                            : cs.error,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '$wordCount/100 từ',
                    style: TextStyle(
                      fontSize: 12,
                      color: wordCount > 100 ? cs.error : cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FilledButton(
                key: const Key('tutorReviewSubmitButton'),
                onPressed: !saving ? onSubmit : null,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        reviewStatus.alreadyReviewed
                            ? 'Cập nhật đánh giá'
                            : 'Gửi đánh giá',
                      ),
              ),
            ],
            if ((reviewStatus.reason ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                reviewStatus.reason!,
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ],
          ],
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Row(
              children: [
                Icon(Icons.support_agent_rounded, color: cs.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Nếu cần khiếu nại trực tiếp với admin, vui lòng gọi hotline EConnect ${reviewStatus?.hotline ?? '0335837165'}.',
                    style: TextStyle(
                      fontSize: 13,
                      color: cs.onSurface,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: onCallHotline,
                  child: const Text('Gọi'),
                ),
              ],
            ),
          ),
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
