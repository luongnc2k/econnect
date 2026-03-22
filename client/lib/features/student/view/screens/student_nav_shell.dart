import 'package:client/features/search/view/screens/class_search_screen.dart';
import 'package:client/features/search/view/screens/user_search_screen.dart';
import 'package:client/features/profile/view/widgets/my_profile_view.dart';
import 'package:client/features/student/view/screens/student_home_screen.dart';
import 'package:flutter/material.dart';

class StudentNavShell extends StatefulWidget {
  const StudentNavShell({super.key});

  @override
  State<StudentNavShell> createState() => _StudentNavShellState();
}

class _StudentNavShellState extends State<StudentNavShell> {
  int _currentIndex = 0;

  late final List<Widget> _screens = [
    StudentHomeScreen(
      onAvatarTap: () => setState(() => _currentIndex = 3),
      onSearchTap: () => setState(() => _currentIndex = 1),
      onClassesTap: () => setState(() => _currentIndex = 2),
    ),
    const UserSearchScreen(),
    const ClassSearchScreen(),
    const MyProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
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

class MyProfileTab extends StatelessWidget {
  const MyProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const SafeArea(child: MyProfileView());
  }
}
