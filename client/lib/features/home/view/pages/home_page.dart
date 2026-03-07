import 'package:client/core/providers/current_user_notifier.dart';
import 'package:client/features/student/view/screens/student_nav_shell.dart';
import 'package:client/features/tutor/view/screens/tutor_home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user?.role == 'tutor') {
      return const TutorNavShell();
    }
    // Default to student shell (covers 'student' role and any unexpected values)
    return const StudentNavShell();
  }
}
