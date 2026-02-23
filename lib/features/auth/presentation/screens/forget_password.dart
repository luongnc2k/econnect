import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:econnect_app/core/widget/app_button.dart';
import 'package:econnect_app/core/widget/app_text_field.dart';
import '../controllers/auth_controller.dart';
import 'reset_password.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);

    ref.listen(authControllerProvider, (prev, next) {
      if (next.error != null && next.error != prev?.error) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(next.error!)));
      } else if (!next.loading && prev?.loading == true && next.error == null) {
        // gửi OTP thành công -> sang màn reset
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ResetPasswordScreen(emailOrPhone: _emailCtrl.text.trim()),
          ),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('OTP đã được gửi (demo OTP: 123456)')),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Quên mật khẩu')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Nhập email/số điện thoại để nhận OTP (demo).'),
          const SizedBox(height: 12),
          AppTextField(
            controller: _emailCtrl,
            label: 'Email / Số điện thoại',
            prefixIcon: Icons.alternate_email,
          ),
          const SizedBox(height: 16),
          AppButton(
            label: 'Gửi OTP',
            loading: state.loading,
            onPressed: () {
              ref.read(authControllerProvider.notifier).requestPasswordReset(
                    emailOrPhone: _emailCtrl.text,
                  );
            },
          ),
        ],
      ),
    );
  }
}
