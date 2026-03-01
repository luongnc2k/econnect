import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/view/screens/login_screen.dart';
import '../features/auth/view/screens/signup_screen.dart';
import '../features/profile/view/create_profile_screen.dart';
import '../features/profile/view/my_profile_screen.dart';
import '../features/profile/view/public_profile_screen.dart';
import '../features/home/view/screen/home_screen.dart';
import 'main_screen.dart';
import '../features/profile/viewmodel/profile_providers.dart';

/// Giả sử bạn có authProvider
final authProvider = Provider<bool>((ref) {
  /// TODO: thay bằng auth thật (Firebase / API)
  
  


});

final appRouterProvider = Provider<GoRouter>((ref) {
  final isLoggedIn = ref.watch(authProvider);
  final profileAsync = ref.watch(myProfileProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final location = state.uri.toString();

      /// Nếu chưa login → về login
      if (!isLoggedIn && location != '/login') {
        return '/login';
      }

      /// Nếu đã login nhưng chưa có profile
      if (isLoggedIn &&
          profileAsync.hasValue &&
          profileAsync.value == null &&
          location != '/create-profile') {
        return '/create-profile';
      }

      return null;
    },
    routes: [

      /// Splash
      GoRoute(
        path: '/',
        builder: (context, state) =>
            const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
      ),

      /// Login
      GoRoute(
        path: '/login',
        builder: (context, state) =>
            const LoginPage(),
      ),

      /// Register
      GoRoute(
        path: '/register',
        builder: (context, state) =>
            const SignupPage(),
      ),

      /// Create Profile
      GoRoute(
        path: '/create-profile',
        builder: (context, state) =>
            const CreateProfileScreen(),
      ),

      /// Shell Route (Bottom Navigation)
      ShellRoute(
        builder: (context, state, child) {
          return MainScreen(child: child);
        },
        routes: [

          /// Home
          GoRoute(
            path: '/home',
            builder: (context, state) =>
                const HomeScreen(),
          ),

          /// My Profile
          GoRoute(
            path: '/my-profile',
            builder: (context, state) =>
                const MyProfileScreen(),
          ),
        ],
      ),

      /// Public Profile
      GoRoute(
        path: '/profile/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return PublicProfileScreen(userId: id);
        },
      ),
    ],
  );
});