import 'dart:async';

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
  static const _searchDebounceDuration = Duration(milliseconds: 350);

  final _controller = TextEditingController();
  Timer? _searchDebounce;
  List<UserModel> _results = const [];
  List<ClassSession> _classResults = const [];
  bool _isLoading = false;
  String _activeMode = 'user';
  int _activeSearchRequestId = 0;

  @override
  void dispose() {
    _searchDebounce?.cancel();
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

  void _scheduleSearch(String value) {
    _searchDebounce?.cancel();
    final query = value.trim();
    final requestId = ++_activeSearchRequestId;

    if (query.isEmpty) {
      setState(() {
        _results = const [];
        _classResults = const [];
        _isLoading = false;
        _activeMode = 'user';
      });
      return;
    }

    _searchDebounce = Timer(_searchDebounceDuration, () {
      unawaited(_search(query, requestId));
    });
  }

  Future<void> _search(String value, int requestId) async {
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
      if (!mounted || requestId != _activeSearchRequestId) return;

      switch (result) {
        case Left():
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
    if (!mounted || requestId != _activeSearchRequestId) return;

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
                hintText: 'Tìm người dùng hoặc nhập mã lớp',
                onChanged: _scheduleSearch,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _controller.text.trim().isEmpty
                    ? const Center(
                        child: Text(
                          'Nhập tên, số điện thoại hoặc mã lớp để tìm',
                        ),
                      )
                    : _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _activeMode == 'class'
                    ? _classResults.isEmpty
                          ? const Center(child: Text('Không tìm thấy lớp học'))
                          : UpcomingClassListWidget(
                              classes: _classResults,
                              onClassTap: (session) => context.push(
                                AppRoutes.classDetail,
                                extra: session,
                              ),
                            )
                    : _results.isEmpty
                    ? const Center(child: Text('Không tìm thấy người dùng'))
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
