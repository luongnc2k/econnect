/// App router configuration for handling navigation within the application. This file defines the routing structure and navigation behavior for the app, ensuring a consistent and predictable user experience across all screens. It is part of the app's main configuration and is used by the presentation layer to manage screen transitions and navigation states.
/// Dùng để chuyển giữa các màn hinh trong ứng dụng. Đây là nơi định nghĩa các tuyến đường (routes) và 
/// cách chúng liên kết với nhau, giúp người dùng có thể di chuyển dễ dàng giữa các phần khác nhau của ứng dụng.
///  Router này sử dụng gói go_router để quản lý các tuyến đường và điều hướng trong ứng dụng một cách hiệu quả và
///  linh hoạt.

library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppRouter {
  AppRouter._();

  static final GoRouter router = GoRouter(
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (BuildContext context, GoRouterState state) {
          return const Scaffold(
            body: Center(child: Text('Home')),
          );
        },
      ),
    ],
  );
}
