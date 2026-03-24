import 'package:client/core/providers/current_user_notifier.dart';
import 'package:client/core/router/app_router.dart';
import 'package:client/features/auth/model/user_model.dart';
import 'package:client/features/search/repositories/user_search_repository.dart';
import 'package:client/features/search/view/widgets/search_bar_widget.dart';
import 'package:client/features/student/model/class_session.dart';
import 'package:client/features/student/repositories/student_remote_repository.dart';
import 'package:client/features/student/view/widgets/upcoming_classlist_widget.dart';
import 'package:client/testing/manual_test_mocks.dart';
import 'package:fpdart/fpdart.dart' show Left, Right;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class UserSearchScreen extends ConsumerStatefulWidget {
  const UserSearchScreen({super.key});

  @override
  ConsumerState<UserSearchScreen> createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends ConsumerState<UserSearchScreen> {
  final _controller = TextEditingController();
  List<UserModel> _results = const [];
  List<ClassSession> _classResults = const [];
  bool _isLoading = false;
  String _activeMode = 'user';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleBack(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }
    context.go(AppRoutes.studentHome);
  }

  Future<void> _search(String value) async {
    final query = value.trim();
    if (query.isEmpty) {
      setState(() {
        _results = const [];
        _classResults = const [];
        _isLoading = false;
        _activeMode = 'user';
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    if (_looksLikeClassCode(query)) {
      final token = ref.read(currentUserProvider)?.token ?? '';
      final result = await ref
          .read(studentRemoteRepositoryProvider)
          .getClassByCode(token, query);
      if (!mounted) return;

      switch (result) {
        case Left(value: final _):
          final fallback = ManualTestMocks.enabled
              ? ManualTestMocks.mockClasses.where((item) {
                  return (item.classCode ?? '').toUpperCase() ==
                      query.toUpperCase();
                }).toList()
              : const <ClassSession>[];
          setState(() {
            _results = const [];
            _classResults = fallback;
            _activeMode = 'class';
            _isLoading = false;
          });
        case Right(value: final classSession):
          setState(() {
            _results = const [];
            _classResults = [classSession];
            _activeMode = 'class';
            _isLoading = false;
          });
      }
      return;
    }

    final results = await ref
        .read(userSearchRepositoryProvider)
        .searchUsers(query);
    if (!mounted) return;

    setState(() {
      _results = results;
      _classResults = const [];
      _activeMode = 'user';
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => _handleBack(context),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text('Tìm kiếm'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              SearchBarWidget(
                controller: _controller,
                hintText: 'Tim nguoi dung hoac nhap ma lop',
                onChanged: _search,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _controller.text.trim().isEmpty
                    ? const Center(
                        child: Text(
                          'Nhap ten, so dien thoai hoac ma lop de tim',
                        ),
                      )
                    : _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _activeMode == 'class'
                    ? _classResults.isEmpty
                          ? const Center(child: Text('Khong tim thay lop hoc'))
                          : UpcomingClassListWidget(
                              classes: _classResults,
                              onClassTap: (session) => context.push(
                                AppRoutes.classDetail,
                                extra: session,
                              ),
                            )
                    : _results.isEmpty
                    ? const Center(child: Text('Khong tim thay nguoi dung'))
                    : ListView.separated(
                        itemCount: _results.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final user = _results[index];
                          return ListTile(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            tileColor: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                            leading: CircleAvatar(
                              backgroundImage:
                                  user.avatarUrl != null &&
                                      user.avatarUrl!.isNotEmpty
                                  ? NetworkImage(user.avatarUrl!)
                                  : null,
                              child:
                                  user.avatarUrl == null ||
                                      user.avatarUrl!.isEmpty
                                  ? const Icon(Icons.person)
                                  : null,
                            ),
                            title: Text(user.fullName),
                            subtitle: Text(user.phone ?? user.email),
                            trailing: Text(
                              user.role == 'teacher' ? 'Tutor' : 'Student',
                            ),
                            onTap: () => context.push(
                              AppRoutes.userProfile.replaceFirst(
                                ':userId',
                                user.id,
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _looksLikeClassCode(String value) {
    final normalized = value.trim().toUpperCase();
    return normalized.startsWith('CLS-') && normalized.length >= 8;
  }
}
