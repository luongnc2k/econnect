import 'package:client/features/profile/view/widgets/my_profile_view.dart';
import 'package:flutter/material.dart';

class MyProfileScreen extends StatelessWidget {
  const MyProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return  Scaffold(
      appBar: AppBar(
        title: const Text('Hồ sơ của tôi'),
      ),
      body: const MyProfileView(
        showAppBarSpacing: true,
      ),
    );
  }
}