import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:econnect_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:econnect_app/core/widget/widgets.dart';

class TutorHomeScreen extends ConsumerWidget {
  const TutorHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tutor Home'),
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
                const Text('Chào Tutor 👋', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                const Text('Demo: Tutor có thể tạo nhóm, quản lý lịch, xác nhận dạy.'),
                const SizedBox(height: 16),
                AppButton(
                  label: 'Tạo nhóm',
                  leadingIcon: Icons.add,
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Demo: mở Create Group')),
                    );
                  },
                ),
                const SizedBox(height: 12),
                AppButton(
                  label: 'Xem nhóm của tôi (demo)',
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
