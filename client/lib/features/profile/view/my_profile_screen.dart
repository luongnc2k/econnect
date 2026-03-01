import 'package:client/features/profile/viewmodel/profile_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class MyProfileScreen extends ConsumerWidget {
  const MyProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text("My Profile")),
      body: profile.when(
        data: (user) {
          if (user == null) {
            return const Center(child: Text("No profile"));
          }

          return Column(
            children: [
              Text(user.fullName,
                  style: const TextStyle(fontSize: 22)),
              Text(user.education),
              ElevatedButton(
                onPressed: () {
                  context.push(
                    '/edit-profile',
                    extra: user,
                  );
                },
                child: const Text("Edit"),
              ),
            ],
          );
        },
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Text(e.toString()),
      ),
    );
  }
}