import 'package:client/core/providers/current_user_notifier.dart';
import 'package:client/features/auth/view/screens/login_screen.dart';
import 'package:client/features/auth/view/screens/signup_screen.dart';
import 'package:client/features/profile/view/screens/create_profile_screen.dart';
import 'package:client/features/profile/view/screens/edit_my_profile_screen.dart';
import 'package:client/features/profile/view/screens/my_profile_screen.dart';
import 'package:client/features/student/model/class_session.dart';
import 'package:client/features/student/view/screens/class_detail_screen.dart';
import 'package:client/features/student/view/screens/student_nav_shell.dart';
import 'package:client/features/tutor/view/screens/tutor_home_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// ── Route names ───────────────────────────────────────────────────────────────

abstract class AppRoutes {
  static const login = '/login';
  static const signup = '/signup';

  static const studentHome = '/student';
  static const classDetail = '/student/class';

  static const teacherHome = '/teacher';

  static const studentMyProfile = '/student/profile';
  static const studentEditMyProfile = '/student/profile/edit';
  static const studentCreateProfile = '/student/profile/create';

  static const teacherMyProfile = '/teacher/profile';
  static const teacherEditMyProfile = '/teacher/profile/edit';
  static const teacherCreateProfile = '/teacher/profile/create';

  static const studentUserProfile = '/student/user';
  static const teacherUserProfile = '/teacher/user';
}

// ── Router provider ───────────────────────────────────────────────────────────

final appRouterProvider = Provider<GoRouter>((ref) {
  final currentUser = ref.watch(currentUserProvider);

  return GoRouter(
    debugLogDiagnostics: false,
    initialLocation: AppRoutes.studentHome,
    redirect: (context, state) {
      final loggedIn = currentUser != null;
      final onAuth =
          state.uri.path == AppRoutes.login ||
          state.uri.path == AppRoutes.signup;

      if (!loggedIn && !onAuth) {
        return AppRoutes.login;
      }

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
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.signup,
        builder: (context, state) => const SignupScreen(),
      ),

      // Student routes
      GoRoute(
        path: AppRoutes.studentHome,
        builder: (context, state) => const StudentNavShell(),
        routes: [
          GoRoute(
            path: 'class',
            builder: (context, state) {
              final session = state.extra as ClassSession;
              return ClassDetailScreen(session: session);
            },
          ),
          GoRoute(
            path: 'profile',
            builder: (context, state) => const MyProfileScreen(),
            routes: [
              GoRoute(
                path: 'create',
                builder: (context, state) => const CreateProfileScreen(),
              ),
              GoRoute(
                path: 'edit',
                builder: (context, state) => const EditMyProfileScreen(),
              ),
            ],
          ),

          // Khi bạn làm màn xem profile người khác thì mở lại đoạn này
          // GoRoute(
          //   path: 'user/:userId',
          //   builder: (context, state) {
          //     final userId = state.pathParameters['userId']!;
          //     return UserProfileScreen(userId: userId);
          //   },
          // ),
        ],
      ),

      // Teacher routes
      GoRoute(
        path: AppRoutes.teacherHome,
        builder: (context, state) => const TutorNavShell(),
        routes: [
          GoRoute(
            path: 'profile',
            builder: (context, state) => const MyProfileScreen(),
            routes: [
              GoRoute(
                path: 'create',
                builder: (context, state) => const CreateProfileScreen(),
              ),
              GoRoute(
                path: 'edit',
                builder: (context, state) => const EditMyProfileScreen(),
              ),
            ],
          ),

          // GoRoute(
          //   path: 'user/:userId',
          //   builder: (context, state) {
          //     final userId = state.pathParameters['userId']!;
          //     return UserProfileScreen(userId: userId);
          //   },
          // ),
        ],
      ),
    ],
  );
});