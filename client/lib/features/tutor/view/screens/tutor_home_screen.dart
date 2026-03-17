import 'package:client/core/router/app_router.dart';
import 'package:client/features/auth/viewmodel/auth_viewmodel.dart';
import 'package:client/features/tutor/view/screens/tutor_home_tab.dart';
import 'package:client/features/tutor/view/screens/tutor_schedule_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class TutorNavShell extends StatefulWidget {
  const TutorNavShell({super.key});

  @override
  State<TutorNavShell> createState() => _TutorNavShellState();
}

class _TutorNavShellState extends State<TutorNavShell> {
  int _currentIndex = 0;

  late final List<Widget> _screens = [
    TutorHomeTab(
      onProfileTap: () => setState(() => _currentIndex = 3),
      onScheduleTap: () => setState(() => _currentIndex = 1),
    ),
    const TutorScheduleScreen(),
    const _PlaceholderTab(label: 'Học viên'),
    const _ProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton.extended(
              onPressed: () => context.push(AppRoutes.teacherCreateClass),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Tạo lớp học'),
            )
          : null,
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
