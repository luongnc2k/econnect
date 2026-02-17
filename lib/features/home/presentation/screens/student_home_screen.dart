import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:econnect_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:econnect_app/core/widget/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  SecureStorage._();

  static const _storage = FlutterSecureStorage();
  static const _kToken = 'auth_token';
  static const _kRole = 'auth_role';
  static const _kName = 'auth_name';

  static Future<void> saveAuth({required String token, required String role, String? name}) async {
    await _storage.write(key: _kToken, value: token);
    await _storage.write(key: _kRole, value: role);
    if (name != null) await _storage.write(key: _kName, value: name);
  }

  static Future<String?> readToken() => _storage.read(key: _kToken);
  static Future<String?> readRole() => _storage.read(key: _kRole);
  static Future<String?> readName() => _storage.read(key: _kName);

  static Future<void> clearAuth() async {
    await _storage.delete(key: _kToken);
    await _storage.delete(key: _kRole);
    await _storage.delete(key: _kName);
  }
}

class StudentHomeScreen extends ConsumerWidget {
  const StudentHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Home'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authControllerProvider.notifier).logout();
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Chào Học viên 👋', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                const Text('Demo: Học viên có thể tìm nhóm, đăng ký học, xem lịch.'),
                const SizedBox(height: 16),
                AppButton(
                  label: 'Tìm nhóm ',
                  leadingIcon: Icons.search,
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Demo: mở Search Groups')),
                    );
                  },
                ),
                const SizedBox(height: 12),
                AppButton(
                  label: 'Nhóm tôi đã đăng ký (demo)',
                  variant: AppButtonVariant.outline,
                  trailingIcon: Icons.chevron_right,
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
