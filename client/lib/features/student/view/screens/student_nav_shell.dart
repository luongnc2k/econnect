import 'package:client/core/localization/app_language.dart';
import 'package:client/core/router/app_router.dart';
import 'package:client/features/profile/view/widgets/my_profile_view.dart';
import 'package:client/features/search/view/screens/class_search_screen.dart';
import 'package:client/features/student/view/screens/student_home_screen.dart';
import 'package:client/features/student/view/screens/student_schedule_screen.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class StudentNavShell extends StatefulWidget {
  const StudentNavShell({super.key});

  @override
  State<StudentNavShell> createState() => _StudentNavShellState();
}

class _StudentNavShellState extends State<StudentNavShell> {
  int _currentIndex = 0;
  int _scheduleRefreshToken = 0;

  void _selectTab(int index) {
    setState(() {
      _currentIndex = index;
      if (index == 1) {
        _scheduleRefreshToken++;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(Localizations.localeOf(context).languageCode);
    final screens = [
      StudentHomeScreen(
        onAvatarTap: () => _selectTab(3),
        onSearchTap: () => context.push(AppRoutes.studentSearch),
        onClassesTap: () => _selectTab(2),
      ),
      StudentScheduleScreen(refreshToken: _scheduleRefreshToken),
      const ClassSearchScreen(),
      const MyProfileTab(),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _selectTab,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home_rounded),
            label: strings.text(en: 'Home', vi: 'Trang chủ'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.calendar_month_outlined),
            selectedIcon: const Icon(Icons.calendar_month_rounded),
            label: strings.text(en: 'Schedule', vi: 'Lịch học'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.menu_book_outlined),
            selectedIcon: const Icon(Icons.menu_book_rounded),
            label: strings.text(en: 'Classes', vi: 'Buổi học'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline_rounded),
            selectedIcon: const Icon(Icons.person_rounded),
            label: strings.text(en: 'Profile', vi: 'Hồ sơ'),
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
