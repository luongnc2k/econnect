import 'package:client/core/localization/app_language.dart';
import 'package:client/features/profile/view/widgets/my_profile_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MyProfileScreen extends ConsumerWidget {
  const MyProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.text(en: 'My profile', vi: 'Hồ sơ của tôi')),
      ),
      body: const MyProfileView(showAppBarSpacing: true),
    );
  }
}
