import 'package:client/core/failure/failure.dart';
import 'package:client/core/providers/current_user_notifier.dart';
import 'package:client/core/router/app_router.dart';
import 'package:client/features/payments/model/payment_summary.dart';
import 'package:client/features/payments/repositories/payments_remote_repository.dart';
import 'package:client/features/profile/view/widgets/my_profile_view.dart';
import 'package:client/features/tutor/view/screens/tutor_home_tab.dart';
import 'package:client/features/tutor/view/screens/tutor_schedule_screen.dart';
import 'package:client/features/tutor/viewmodel/tutor_home_viewmodel.dart';
import 'package:fpdart/fpdart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class TutorNavShell extends ConsumerStatefulWidget {
  const TutorNavShell({super.key});

  @override
  ConsumerState<TutorNavShell> createState() => _TutorNavShellState();
}

class _TutorNavShellState extends ConsumerState<TutorNavShell> {
  int _currentIndex = 0;

  late final List<Widget> _screens = [
    TutorHomeTab(
      onProfileTap: () => setState(() => _currentIndex = 4),
      onScheduleTap: () => setState(() => _currentIndex = 1),
    ),
    const TutorScheduleScreen(),
    const _TutorPaymentTab(),
    const _PlaceholderTab(label: 'Học viên'),
    const _ProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton.extended(
              onPressed: () async {
                await context.push(AppRoutes.teacherCreateClass);
                if (!mounted) {
                  return;
                }
                await ref
                    .read(tutorHomeViewModelProvider.notifier)
                    .refresh(silent: true);
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Tạo buổi học'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Trang chủ',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month_rounded),
            label: 'Lịch dạy',
          ),
          NavigationDestination(
            icon: Icon(Icons.payments_outlined),
            selectedIcon: Icon(Icons.payments_rounded),
            label: 'Thanh toán',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline_rounded),
            selectedIcon: Icon(Icons.people_rounded),
            label: 'Học viên',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Hồ sơ',
          ),
        ],
      ),
    );
  }
}

class _TutorPaymentTab extends ConsumerStatefulWidget {
  const _TutorPaymentTab();

  @override
  ConsumerState<_TutorPaymentTab> createState() => _TutorPaymentTabState();
}

class _TutorPaymentTabState extends ConsumerState<_TutorPaymentTab> {
  final _controller = TextEditingController();
  PaymentSummary? _summary;
  String? _error;
  bool _loading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadSummary() async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      return;
    }
    final code = _controller.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() => _error = 'Nhập mã lớp để tra cứu thanh toán.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await ref
        .read(paymentsRemoteRepositoryProvider)
        .getSummaryByClassCode(token: user.token, classCode: code);
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

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Theo dõi thanh toán',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Nhập mã lớp để xem phí tạo lớp, số tiền đang escrow, payout cho tutor và dispute hiện tại.',
            style: TextStyle(color: cs.onSurfaceVariant, height: 1.45),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: 'Mã lớp',
              hintText: 'VD: CLS-260315-ABCD',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _loading ? null : _loadSummary,
            child: Text(_loading ? 'Đang tải...' : 'Xem trạng thái'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: cs.error)),
          ],
          if (_summary != null) ...[
            const SizedBox(height: 20),
            _SummaryCard(summary: _summary!),
          ],
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final PaymentSummary summary;

  const _SummaryCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tổng quan đối soát',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          _SummaryRow(label: 'Trạng thái lớp', value: summary.classStatus),
          _SummaryRow(
            label: 'Phí tạo lớp',
            value: '${summary.creationFeeAmount} VND',
          ),
          _SummaryRow(
            label: 'Thanh toán phí tạo lớp',
            value: summary.creationPaymentStatusLabel,
          ),
          _SummaryRow(
            label: 'Học viên hiện tại',
            value: '${summary.currentParticipants}/${summary.maxParticipants}',
          ),
          _SummaryRow(
            label: 'Ngưỡng tối thiểu',
            value: summary.minParticipants.toString(),
          ),
          _SummaryRow(
            label: 'Đã đủ học viên tối thiểu',
            value: summary.minimumParticipantsReached ? 'Có' : 'Chưa',
          ),
          _SummaryRow(
            label: 'Tutor xác nhận dạy',
            value: summary.tutorConfirmationStatus,
          ),
          _SummaryRow(
            label: 'Tổng escrow',
            value: '${summary.totalEscrowHeld} VND',
          ),
          _SummaryRow(label: 'Payout tutor', value: summary.tutorPayoutStatus),
          _SummaryRow(
            label: 'Số tiền payout',
            value: '${summary.tutorPayoutAmount} VND',
          ),
          _SummaryRow(
            label: 'Dispute đang mở',
            value: summary.activeDisputes.toString(),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryRow({required this.label, required this.value});

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

class _PlaceholderTab extends StatelessWidget {
  final String label;

  const _PlaceholderTab({required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(label, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

class _ProfileTab extends ConsumerWidget {
  const _ProfileTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const SafeArea(child: MyProfileView());
  }
}
