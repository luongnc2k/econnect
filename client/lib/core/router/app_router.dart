import 'package:client/core/providers/current_user_notifier.dart';
import 'package:client/features/auth/view/screens/login_screen.dart';
import 'package:client/features/auth/view/screens/signup_screen.dart';
import 'package:client/features/student/model/class_session.dart';
import 'package:client/features/student/view/screens/class_detail_screen.dart';
import 'package:client/features/student/view/screens/student_nav_shell.dart';
import 'package:client/features/tutor/view/screens/tutor_home_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// ── Route names ───────────────────────────────────────────────────────────────

abstract class AppRoutes {
  static const login        = '/login';
  static const signup       = '/signup';
  static const studentHome  = '/student';
  static const classDetail  = '/student/class';
  static const teacherHome  = '/teacher';
}

// ── Router provider ───────────────────────────────────────────────────────────

final appRouterProvider = Provider<GoRouter>((ref) {
  final currentUser = ref.watch(currentUserProvider);

  return GoRouter(
    debugLogDiagnostics: false,
    initialLocation: AppRoutes.studentHome,
    redirect: (context, state) {
      final loggedIn = currentUser != null;
      final onAuth = state.uri.path == AppRoutes.login ||
          state.uri.path == AppRoutes.signup;

      if (!loggedIn && !onAuth) return AppRoutes.login;
      if (loggedIn && onAuth) {
        return currentUser.role == 'teacher'
            ? AppRoutes.teacherHome
            : AppRoutes.studentHome;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.login,
        builder: (context, _) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.signup,
        builder: (context, _) => const SignupScreen(),
      ),
      GoRoute(
        path: AppRoutes.studentHome,
        builder: (context, _) => const StudentNavShell(),
        routes: [
          GoRoute(
            path: 'class',
            builder: (context, state) {
              final session = state.extra as ClassSession;
              return ClassDetailScreen(session: session);
            },
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.teacherHome,
        builder: (context, _) => const TutorNavShell(),
      ),
    ],
  );
});
