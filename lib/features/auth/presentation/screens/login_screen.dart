/// Login screen for the authentication feature. This screen allows users to enter their credentials and log in to the application.
/// It includes form validation and error handling to ensure a smooth user experience.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:econnect_app/core/widget/widgets.dart';

import '../../presentation/controllers/auth_controller.dart';
import 'register_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);

    ref.listen(authControllerProvider, (prev, next) {
      if (next.error != null && next.error != prev?.error) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(next.error!)));
      }
      if (next.loggedIn && next.loggedIn != prev?.loggedIn) {
        // TODO: điều hướng theo role Tutor/Học viên
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đăng nhập thành công (${next.role})')),
        );
      }
    });

    return Scaffold(
      // appBar: AppBar(title: const Text('Đăng nhập')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 24),

          // ✅ Logo
          Center(
            child: Column(
              children: [
                Image.asset(
                  'assets/images/logo.png',
                  height: 200,
                  fit: BoxFit.scaleDown,
                ),
                const SizedBox(height: 1),
                const Text(
                  'EConnect',
                  style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Một ứng dụng giúp việc dạy và học trực tiếp trở nên dễ dàng hơn bao giờ hết.',
                  style: TextStyle(fontSize: 14, color: Colors.black54),
                ),
              ],
            ),
          ),

          const SizedBox(height: 25),

          // Form
          AppTextField(
            controller: _emailCtrl,
            label: 'Email / Số điện thoại',
            hintText: 'example@email.com',
            prefixIcon: Icons.person,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          AppTextField(
            controller: _passCtrl,
            label: 'Mật khẩu',
            obscureText: true,
            prefixIcon: Icons.lock,
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: 16),

          AppButton(
            label: 'Đăng nhập',
            loading: state.loading,
            onPressed: () {
              ref
                  .read(authControllerProvider.notifier)
                  .login(
                    emailOrPhone: _emailCtrl.text,
                    password: _passCtrl.text,
                  );
            },
          ),
          const SizedBox(height: 12),

          AppButton(
            label: 'Tạo tài khoản mới',
            variant: AppButtonVariant.outline,
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const RegisterScreen()));
            },
          ),
        ],
      ),
    );
  }
}
