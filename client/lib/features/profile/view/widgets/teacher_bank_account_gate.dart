import 'package:client/core/providers/current_user_notifier.dart';
import 'package:client/features/profile/model/teacher_my_profile_model.dart';
import 'package:client/features/profile/viewmodel/my_profile_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class TeacherBankAccountGate extends ConsumerStatefulWidget {
  final Widget child;
  final String redirectPath;

  const TeacherBankAccountGate({
    super.key,
    required this.child,
    required this.redirectPath,
  });

  @override
  ConsumerState<TeacherBankAccountGate> createState() =>
      _TeacherBankAccountGateState();
}

class _TeacherBankAccountGateState
    extends ConsumerState<TeacherBankAccountGate> {
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(_ensureTeacherBankAccount);
  }

  Future<void> _ensureTeacherBankAccount() async {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser?.role != 'teacher') {
      if (mounted) {
        setState(() => _checking = false);
      }
      return;
    }

    final state = ref.read(myProfileViewModelProvider);
    if (state.profile == null || state.profile?.id != currentUser?.id) {
      await ref.read(myProfileViewModelProvider.notifier).fetchMyProfile();
    }
    if (!mounted) {
      return;
    }

    final nextState = ref.read(myProfileViewModelProvider);
    final profile = nextState.profile;
    final needsBankSetup =
        profile is TeacherMyProfileModel && !profile.hasPayoutBankAccount;

    setState(() => _checking = false);

    if (!needsBankSetup) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.go(widget.redirectPath);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return widget.child;
  }
}
