import 'package:client/core/providers/current_user_notifier.dart';
import 'package:client/core/providers/theme_notifier.dart';
import 'package:client/features/auth/viewmodel/auth_viewmodel.dart';
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
    _PlaceholderTab(label: 'Lịch dạy'),
    _PlaceholderTab(label: 'Học viên'),
    _ProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) =>
            setState(() => _currentIndex = index),
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

class _TutorHomeTab extends ConsumerWidget {
  const _TutorHomeTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;

    return SafeArea(
      child: Column(
        children: [
          AppBar(
            title: const Text('Trang chủ gia sư'),
            actions: [
              IconButton(
                onPressed: () =>
                    ref.read(themeModeProvider.notifier).toggle(),
                icon: Icon(
                  isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                ),
              ),
            ],
          ),
          Expanded(
            child: Center(child: Text('Xin chào, ${user?.fullName ?? ''}!')),
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
        child: const Text('Đăng xuất'),
      ),
    );
  }
}
