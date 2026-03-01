import 'package:client/features/profile/model/user_model.dart';
import 'package:client/features/profile/viewmodel/profile_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class CreateProfileScreen extends ConsumerStatefulWidget {
  const CreateProfileScreen({super.key});

  @override
  ConsumerState<CreateProfileScreen> createState() =>
      _CreateProfileScreenState();
}

class _CreateProfileScreenState
    extends ConsumerState<CreateProfileScreen> {

  final name = TextEditingController();
  final education = TextEditingController();
  final job = TextEditingController();
  final nationality = TextEditingController();

  UserRole role = UserRole.student;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Create Profile")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: name),
            TextField(controller: education),
            TextField(controller: job),
            TextField(controller: nationality),
            DropdownButton<UserRole>(
              value: role,
              items: const [
                DropdownMenuItem(
                    value: UserRole.student,
                    child: Text("Student")),
                DropdownMenuItem(
                    value: UserRole.tutor,
                    child: Text("Tutor")),
              ],
              onChanged: (v) => setState(() => role = v!),
            ),
            ElevatedButton(
              onPressed: () async {
                final user = UserModel(
                  id: "1",
                  fullName: name.text,
                  dob: DateTime(2000),
                  education: education.text,
                  job: job.text,
                  nationality: nationality.text,
                  role: role,
                );

                await ref
                    .read(myProfileProvider.notifier)
                    .createProfile(user);

                context.go('/home');
              },
              child: const Text("Create"),
            )
          ],
        ),
      ),
    );
  }
}