import 'package:client/core/providers/current_user_notifier.dart';
import 'package:client/core/router/app_router.dart';
import 'package:client/features/student/model/class_session.dart';
import 'package:client/features/student/repositories/student_remote_repository.dart';
import 'package:client/features/student/view/widgets/upcoming_classlist_widget.dart';
import 'package:client/testing/manual_test_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart' show Left, Right;
import 'package:go_router/go_router.dart';

class StudentScheduleScreen extends ConsumerStatefulWidget {
  const StudentScheduleScreen({super.key});

  @override
  ConsumerState<StudentScheduleScreen> createState() =>
      _StudentScheduleScreenState();
}

class _StudentScheduleScreenState extends ConsumerState<StudentScheduleScreen> {
  bool _showPast = false;
  bool _isLoading = true;
  String? _error;
  List<ClassSession> _classes = const [];

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _loadClasses());
  }

  Future<void> _loadClasses({bool? past}) async {
    final resolvedPast = past ?? _showPast;
    final token = ref.read(currentUserProvider)?.token;
    if (token == null || token.isEmpty) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Không tìm thấy thông tin đăng nhập';
        _classes = const [];
      });
      return;
    }

    setState(() {
      _showPast = resolvedPast;
      _isLoading = true;
      _error = null;
    });

    final result = await ref
        .read(studentRemoteRepositoryProvider)
        .getRegisteredClasses(token, past: resolvedPast);

    if (!mounted) return;

    switch (result) {
      case Left(value: final failure):
        final fallback = !resolvedPast && ManualTestMocks.enabled
            ? ManualTestMocks.mockClasses
            : const <ClassSession>[];
        setState(() {
          _classes = fallback;
          _error = fallback.isEmpty ? failure.message : null;
          _isLoading = false;
        });
      case Right(value: final classes):
        setState(() {
          _classes = classes;
          _isLoading = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Text(
              'Lịch học',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              'Theo dõi các buổi học bạn đã đăng ký và mở lại chi tiết khi cần.',
              style: TextStyle(color: cs.onSurfaceVariant, height: 1.4),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                        value: false,
                        icon: Icon(Icons.upcoming_outlined),
                        label: Text('Sắp học'),
                      ),
                      ButtonSegment(
                        value: true,
                        icon: Icon(Icons.history_rounded),
                        label: Text('Đã học'),
                      ),
                    ],
                    selected: {_showPast},
                    onSelectionChanged: (selection) {
                      final next = selection.first;
                      if (next == _showPast) {
                        return;
                      }
                      _loadClasses(past: next);
                    },
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                Text(
                  _showPast ? 'Buổi đã học' : 'Buổi sắp học',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                if (!_isLoading)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${_classes.length} buổi',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: cs.onPrimaryContainer,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: () => _loadClasses(),
                    child: _buildBody(context),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Không thể tải lịch học',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(_error!),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => _loadClasses(),
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (_classes.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Icon(
                  _showPast
                      ? Icons.history_toggle_off_rounded
                      : Icons.calendar_month_outlined,
                  size: 36,
                ),
                const SizedBox(height: 12),
                Text(
                  _showPast
                      ? 'Bạn chưa có buổi học đã hoàn thành.'
                      : 'Bạn chưa đăng ký buổi học nào sắp diễn ra.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      );
    }

    return UpcomingClassListWidget(
      classes: _classes,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      onClassTap: (session) =>
          context.push(AppRoutes.classDetail, extra: session),
    );
  }
}
