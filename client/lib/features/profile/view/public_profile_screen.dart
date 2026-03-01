import 'package:client/features/profile/viewmodel/profile_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PublicProfileScreen extends ConsumerWidget {
  final String userId;

  const PublicProfileScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile =
        ref.watch(publicProfileProvider(userId));

    return Scaffold(
      appBar: AppBar(title: const Text("Profile")),
      body: profile.when(
        data: (user) => Column(
          children: [
            Text(user.fullName),
            Text(user.education),
            if (user.isTutor)
              Text("Experience: ${user.experienceYears ?? 0}"),
          ],
        ),
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Text(e.toString()),
      ),
    );
  }
}