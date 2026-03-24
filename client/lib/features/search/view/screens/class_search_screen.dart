import 'package:client/core/providers/current_user_notifier.dart';
import 'package:client/core/router/app_router.dart';
import 'package:client/features/student/model/class_session.dart';
import 'package:client/features/student/repositories/student_remote_repository.dart';
import 'package:client/features/student/view/widgets/upcoming_classlist_widget.dart';
import 'package:client/features/search/view/widgets/search_bar_widget.dart';
import 'package:client/testing/manual_test_mocks.dart';
import 'package:fpdart/fpdart.dart' show Left, Right;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ClassSearchScreen extends ConsumerStatefulWidget {
  const ClassSearchScreen({super.key});

  @override
  ConsumerState<ClassSearchScreen> createState() => _ClassSearchScreenState();
}

class _ClassSearchScreenState extends ConsumerState<ClassSearchScreen> {
  final _controller = TextEditingController();
  List<ClassSession> _classes = const [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _loadClasses());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadClasses([String query = '']) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final normalized = query.trim();
    final token = ref.read(currentUserProvider)?.token ?? '';
    final repository = ref.read(studentRemoteRepositoryProvider);
    final isClassCodeQuery = _looksLikeClassCode(normalized);

    if (isClassCodeQuery) {
      final result = await repository.getClassByCode(token, normalized);
      switch (result) {
        case Left(value: final failure):
          final fallback = ManualTestMocks.enabled
              ? ManualTestMocks.mockClasses.where((item) {
                  return (item.classCode ?? '').toUpperCase() ==
                      normalized.toUpperCase();
                }).toList()
              : const <ClassSession>[];

          if (!mounted) return;
          setState(() {
            _classes = fallback;
            _error = fallback.isEmpty ? failure.message : null;
            _isLoading = false;
          });
        case Right(value: final foundClass):
          if (!mounted) return;
          setState(() {
            _classes = [foundClass];
            _isLoading = false;
          });
      }
      return;
    }

    final result = await repository.getUpcomingClasses(
      token,
      query: normalized,
    );

    switch (result) {
      case Left(value: final failure):
        final fallback = ManualTestMocks.enabled
            ? ManualTestMocks.mockClasses.where((item) {
                final keyword = normalized.toLowerCase();
                if (keyword.isEmpty) return true;
                return item.title.toLowerCase().contains(keyword) ||
                    (item.classCode ?? '').toLowerCase().contains(keyword) ||
                    item.tags.any((tag) => tag.toLowerCase().contains(keyword));
              }).toList()
            : const <ClassSession>[];

        if (!mounted) return;
        setState(() {
          _classes = fallback;
          _error = fallback.isEmpty ? failure.message : null;
          _isLoading = false;
        });
      case Right(value: final classes):
        if (!mounted) return;
        setState(() {
          _classes = classes;
          _isLoading = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SearchBarWidget(
              controller: _controller,
              hintText: 'Tìm theo mã lớp hoặc tên lớp',
              onChanged: _loadClasses,
            ),
            const SizedBox(height: 12),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _classes.isEmpty
                  ? const Center(child: Text('Không tìm thấy lớp học'))
                  : UpcomingClassListWidget(
                      classes: _classes,
                      onClassTap: (session) =>
                          context.push(AppRoutes.classDetail, extra: session),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  bool _looksLikeClassCode(String value) {
    final normalized = value.trim().toUpperCase();
    return normalized.startsWith('CLS-') && normalized.length >= 8;
  }
}
