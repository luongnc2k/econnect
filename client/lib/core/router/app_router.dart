import 'package:client/core/providers/current_user_notifier.dart';
import 'package:client/features/auth/view/screens/login_screen.dart';
import 'package:client/features/notifications/view/screens/notifications_screen.dart';
import 'package:client/features/auth/view/screens/signup_screen.dart';
import 'package:client/features/profile/model/student_my_profile_model.dart';
import 'package:client/features/profile/model/teacher_my_profile_model.dart';
import 'package:client/features/profile/view/screens/edit_my_profile_screen.dart';
import 'package:client/features/profile/view/screens/my_profile_screen.dart';
import 'package:client/features/profile/view/screens/user_profile_screen.dart';
import 'package:client/features/profile/viewmodel/my_profile_viewmodel.dart';
import 'package:client/features/profile/view/widgets/student_bank_account_gate.dart';
import 'package:client/features/profile/view/widgets/teacher_bank_account_gate.dart';
import 'package:client/features/search/view/screens/user_search_screen.dart';
import 'package:client/features/student/model/class_session.dart';
import 'package:client/features/student/view/screens/class_detail_screen.dart';
import 'package:client/features/student/view/screens/student_nav_shell.dart';
import 'package:client/features/tutor/view/screens/create_class_screen.dart';
import 'package:client/features/tutor/view/screens/tutor_class_detail_screen.dart';
import 'package:client/features/tutor/view/screens/tutor_class_summary_screen.dart';
import 'package:client/features/tutor/view/screens/tutor_home_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

abstract class AppRoutes {
  static const login = '/login';
  static const signup = '/signup';
  static const notifications = '/notifications';

  static const studentHome = '/student';
  static const studentBankSetup = '/student/bank-setup';
  static const studentSearch = '/student/search';
  static const classDetail = '/student/class';
  static const studentMyProfile = '/student/profile';
  static const studentEditMyProfile = '/student/profile/edit';
  static const userProfile = '/user/:userId';

  static const teacherHome = '/teacher';
  static const teacherBankSetup = '/teacher/bank-setup';
  static const teacherClassSummary = '/teacher/class-summary/:classCode';
  static const teacherMyProfile = '/teacher/profile';
  static const teacherEditMyProfile = '/teacher/profile/edit';
  static const teacherCreateClass = '/teacher/create-class';
  static const teacherClassDetail = '/teacher/class';

  static String homeForRole(String? role) {
    return role == 'teacher' ? teacherHome : studentHome;
  }
}

class _RouterRefreshNotifier extends ChangeNotifier {
  void refresh() {
    notifyListeners();
  }
}

final _routerRefreshNotifierProvider = Provider<_RouterRefreshNotifier>((ref) {
  final notifier = _RouterRefreshNotifier();

  ref.listen(currentUserProvider, (previous, next) {
    notifier.refresh();
  });
  ref.listen(
    myProfileViewModelProvider.select((state) => state.profile),
    (previous, next) {
      notifier.refresh();
    },
  );
  ref.onDispose(notifier.dispose);

  return notifier;
});

final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshListenable = ref.watch(_routerRefreshNotifierProvider);

  final router = GoRouter(
    debugLogDiagnostics: false,
    refreshListenable: refreshListenable,
    initialLocation: AppRoutes.homeForRole(ref.read(currentUserProvider)?.role),
    redirect: (context, state) {
      final currentUser = ref.read(currentUserProvider);
      final profile = ref.read(
        myProfileViewModelProvider.select((state) => state.profile),
      );
      final loggedIn = currentUser != null;
      final path = state.uri.path;
      final onAuth = path == AppRoutes.login || path == AppRoutes.signup;

      if (!loggedIn && !onAuth) return AppRoutes.login;

      if (loggedIn) {
        final isTeacher = currentUser.role == 'teacher';
        final onTeacherBankSetup = path == AppRoutes.teacherBankSetup;
        final onStudentBankSetup = path == AppRoutes.studentBankSetup;
        final requiresTeacherBankSetup =
            profile is TeacherMyProfileModel && !profile.hasPayoutBankAccount;
        final requiresStudentBankSetup =
            profile is StudentMyProfileModel && !profile.hasBankAccount;

        if (onAuth) {
          return AppRoutes.homeForRole(currentUser.role);
        }
        if (requiresTeacherBankSetup && !onTeacherBankSetup) {
          return AppRoutes.teacherBankSetup;
        }
        if (requiresStudentBankSetup && !onStudentBankSetup) {
          return AppRoutes.studentBankSetup;
        }
        if (isTeacher && onTeacherBankSetup && !requiresTeacherBankSetup) {
          return AppRoutes.teacherHome;
        }
        if (!isTeacher && onStudentBankSetup && !requiresStudentBankSetup) {
          return AppRoutes.studentHome;
        }

        // teacher bị vào route student → redirect về teacher home
        if (isTeacher && path.startsWith('/student')) {
          return AppRoutes.teacherHome;
        }

        // student bị vào route teacher → redirect về student home
        if (!isTeacher && path.startsWith('/teacher')) {
          return AppRoutes.studentHome;
        }
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
      GoRoute(
        path: AppRoutes.notifications,
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: AppRoutes.userProfile,
        builder: (context, state) {
          final userId = state.pathParameters['userId'] ?? '';
          return UserProfileScreen(userId: userId);
        },
      ),
      GoRoute(
        path: AppRoutes.teacherBankSetup,
        builder: (context, state) =>
            const EditMyProfileScreen(requireBankSetup: true),
      ),
      GoRoute(
        path: AppRoutes.studentBankSetup,
        builder: (context, state) =>
            const EditMyProfileScreen(requireBankSetup: true),
      ),
      GoRoute(
        path: AppRoutes.studentHome,
        builder: (context, state) => StudentBankAccountGate(
          redirectPath: AppRoutes.studentBankSetup,
          child: const StudentNavShell(),
        ),
        routes: [
          GoRoute(
            path: 'search',
            builder: (context, state) => const UserSearchScreen(),
          ),
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
                path: 'edit',
                builder: (context, state) => const EditMyProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.teacherHome,
        builder: (context, state) => TeacherBankAccountGate(
          redirectPath: AppRoutes.teacherBankSetup,
          child: const TutorNavShell(),
        ),
        routes: [
          GoRoute(
            path: 'create-class',
            builder: (context, state) => const CreateClassScreen(),
          ),
          GoRoute(
            path: 'class-summary/:classCode',
            builder: (context, state) {
              final classCode = state.pathParameters['classCode'] ?? '';
              return TutorClassSummaryScreen(classCode: classCode);
            },
          ),
          GoRoute(
            path: 'class',
            builder: (context, state) {
              final session = state.extra as ClassSession;
              return TutorClassDetailScreen(session: session);
            },
          ),
          GoRoute(
            path: 'profile',
            builder: (context, state) => const MyProfileScreen(),
            routes: [
              GoRoute(
                path: 'edit',
                builder: (context, state) => const EditMyProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );

  ref.onDispose(router.dispose);
  return router;
});
