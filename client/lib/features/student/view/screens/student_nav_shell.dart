import 'package:client/features/auth/viewmodel/auth_viewmodel.dart';
import 'package:client/features/student/view/screens/student_home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class StudentNavShell extends StatefulWidget {
  const StudentNavShell({super.key});

  @override
  State<StudentNavShell> createState() => _StudentNavShellState();
}

class _StudentNavShellState extends State<StudentNavShell> {
  int _currentIndex = 0;

  List<Widget> get _screens => [
    StudentHomeScreen(onAvatarTap: () => setState(() => _currentIndex = 3)),
    const _PlaceholderTab(label: 'Tìm kiếm'),
    const _PlaceholderTab(label: 'Lớp học'),
    const _ProfileTab(),
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
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search_rounded),
            label: 'Tìm kiếm',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book_rounded),
            label: 'Lớp học',
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
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleMedium,
      ),
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
