import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:econnect_app/core/widget/app_button.dart';
import 'package:econnect_app/core/widget/app_text_field.dart';
import '../controllers/auth_controller.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  final String emailOrPhone;
  const ResetPasswordScreen({super.key, required this.emailOrPhone});

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _otpCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  @override
  void dispose() {
    _otpCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);

    ref.listen(authControllerProvider, (prev, next) {
      if (next.error != null && next.error != prev?.error) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(next.error!)));
      } else if (!next.loading && prev?.loading == true && next.error == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đặt lại mật khẩu thành công. Vui lòng đăng nhập.')),
        );
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Đặt lại mật khẩu')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Tài khoản: ${widget.emailOrPhone}'),
          const SizedBox(height: 8),
          const Text('Demo OTP: 123456'),
          const SizedBox(height: 12),
          AppTextField(
            controller: _otpCtrl,
            label: 'OTP',
            hintText: '123456',
            prefixIcon: Icons.lock_clock,
          ),
          const SizedBox(height: 12),
          AppTextField(
            controller: _passCtrl,
            label: 'Mật khẩu mới (>= 8 ký tự)',
            obscureText: true,
            prefixIcon: Icons.lock,
          ),
          const SizedBox(height: 12),
          AppTextField(
            controller: _confirmCtrl,
            label: 'Xác nhận mật khẩu mới',
            obscureText: true,
            prefixIcon: Icons.lock_outline,
          ),
          const SizedBox(height: 16),
          AppButton(
            label: 'Xác nhận',
            loading: state.loading,
            onPressed: () {
              ref.read(authControllerProvider.notifier).confirmPasswordReset(
                    emailOrPhone: widget.emailOrPhone,
                    otp: _otpCtrl.text,
                    newPassword: _passCtrl.text,
                    confirmPassword: _confirmCtrl.text,
                  );
            },
          ),
        ],
      ),
    );
  }
}
