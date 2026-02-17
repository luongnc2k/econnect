/// Register screen for the authentication feature. This screen allows users to create a new account by entering their details.
/// It includes form validation and error handling to ensure a smooth user experience.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:econnect_app/core/widget/app_button.dart';
import 'package:econnect_app/core/widget/app_text_field.dart';
import 'package:econnect_app/features/auth/domain/entities/user.dart';
import 'package:econnect_app/features/auth/presentation/controllers/auth_controller.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  UserRole? _role;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);

    ref.listen(authControllerProvider, (prev, next) {
      if (next.error != null && next.error != prev?.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error!)),
        );
      } else if (!next.loading && prev?.loading == true && next.error == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đăng ký thành công. Vui lòng đăng nhập.')),
        );
        Navigator.of(context).pop();
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Đăng ký')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppTextField(
            controller: _nameCtrl,
            label: 'Họ tên',
            prefixIcon: Icons.badge,
          ),
          const SizedBox(height: 12),
          AppTextField(
            controller: _emailCtrl,
            label: 'Email / Số điện thoại',
            prefixIcon: Icons.alternate_email,
          ),
          const SizedBox(height: 12),
          _RolePicker(
            value: _role,
            onChanged: (r) => setState(() => _role = r),
          ),
          const SizedBox(height: 12),
          AppTextField(
            controller: _passCtrl,
            label: 'Mật khẩu (>= 8 ký tự)',
            obscureText: true,
            prefixIcon: Icons.lock,
          ),
          const SizedBox(height: 12),
          AppTextField(
            controller: _confirmCtrl,
            label: 'Xác nhận mật khẩu',
            obscureText: true,
            prefixIcon: Icons.lock_outline,
          ),
          const SizedBox(height: 16),
          AppButton(
            label: 'Tạo tài khoản',
            loading: state.loading,
            onPressed: () {
              ref.read(authControllerProvider.notifier).register(
                    fullName: _nameCtrl.text,
                    emailOrPhone: _emailCtrl.text,
                    password: _passCtrl.text,
                    confirmPassword: _confirmCtrl.text,
                    role: _role,
                  );
            },
          ),
        ],
      ),
    );
  }
}

class _RolePicker extends StatelessWidget {
  final UserRole? value;
  final ValueChanged<UserRole?> onChanged;

  const _RolePicker({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: const InputDecoration(
        labelText: 'Vai trò',
        helperText: 'Bắt buộc chọn Tutor hoặc Học viên',
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<UserRole>(
          value: value,
          isExpanded: true,
          hint: const Text('Chọn vai trò'),
          items: const [
            DropdownMenuItem(value: UserRole.tutor, child: Text('Tutor')),
            DropdownMenuItem(value: UserRole.student, child: Text('Học viên')),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}
