import 'package:client/core/failure/failure.dart';
import 'package:client/core/providers/current_user_notifier.dart';
import 'package:client/core/providers/theme_notifier.dart';
import 'package:client/features/auth/viewmodel/auth_viewmodel.dart';
import 'package:client/features/payments/model/payment_summary.dart';
import 'package:client/features/payments/repositories/payments_remote_repository.dart';
import 'package:fpdart/fpdart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TutorNavShell extends StatefulWidget {
  const TutorNavShell({super.key});

  @override
  State<TutorNavShell> createState() => _TutorNavShellState();
}

class _TutorNavShellState extends State<TutorNavShell> {
  int _currentIndex = 0;

  static const _screens = [
    _TutorHomeTab(),
    _TutorPaymentTab(),
    _PlaceholderTab(label: 'Hoc vien'),
    _ProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Trang chu',
          ),
          NavigationDestination(
            icon: Icon(Icons.payments_outlined),
            selectedIcon: Icon(Icons.payments_rounded),
            label: 'Thanh toan',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline_rounded),
            selectedIcon: Icon(Icons.people_rounded),
            label: 'Hoc vien',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Ho so',
          ),
        ],
      ),
    );
  }
}

class _TutorHomeTab extends ConsumerWidget {
  const _TutorHomeTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final cs = Theme.of(context).colorScheme;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Trang chu gia su',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                onPressed: () => ref.read(themeModeProvider.notifier).toggle(),
                icon: Icon(isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: [cs.primary, cs.secondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Xin chao, ${user?.fullName ?? ''}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tab Thanh toan ben duoi giup theo doi creation fee, escrow va payout theo ma lop. Khi backend dang o mock mode, ban co the test full flow tren browser local.',
                  style: TextStyle(color: Colors.white, height: 1.45),
                ),
              ],
            ),
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
      setState(() => _error = 'Nhap ma lop de tra cuu thanh toan.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await ref.read(paymentsRemoteRepositoryProvider).getSummaryByClassCode(
          token: user.token,
          classCode: code,
        );
    if (!mounted) return;

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
            'Theo doi thanh toan',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Nhap ma lop de xem creation fee, so tien dang escrow, payout cho tutor va dispute hien tai.',
            style: TextStyle(color: cs.onSurfaceVariant, height: 1.45),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: 'Ma lop',
              hintText: 'VD: CLS-260315-ABCD',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _loading ? null : _loadSummary,
            child: Text(_loading ? 'Dang tai...' : 'Xem trang thai'),
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
            'Tong quan doi soat',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          _SummaryRow(label: 'Trang thai lop', value: summary.classStatus),
          _SummaryRow(label: 'Creation fee', value: '${summary.creationFeeAmount} VND'),
          _SummaryRow(label: 'Creation payment', value: summary.creationPaymentStatus),
          _SummaryRow(label: 'Hoc vien hien tai', value: summary.currentParticipants.toString()),
          _SummaryRow(label: 'Tong escrow', value: '${summary.totalEscrowHeld} VND'),
          _SummaryRow(label: 'Payout tutor', value: summary.tutorPayoutStatus),
          _SummaryRow(label: 'So tien payout', value: '${summary.tutorPayoutAmount} VND'),
          _SummaryRow(label: 'Dispute dang mo', value: summary.activeDisputes.toString()),
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
              style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600),
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
    return Center(
      child: FilledButton.tonal(
        onPressed: () => ref.read(authViewModelProvider.notifier).logout(),
        style: FilledButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.errorContainer,
          foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
        ),
        child: const Text('Dang xuat'),
      ),
    );
  }
}
