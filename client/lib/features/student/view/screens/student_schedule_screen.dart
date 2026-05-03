import 'package:client/core/providers/current_user_notifier.dart';
import 'package:client/core/router/app_router.dart';
import 'package:client/features/schedule/view/widgets/schedule_calendar.dart';
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
  late DateTime _selectedDate;
  var _calendarMode = ScheduleCalendarViewMode.week;
  bool _showPast = false;
  bool _isLoading = true;
  String? _error;
  List<ClassSession> _classes = const [];

  @override
  void initState() {
    super.initState();
    _selectedDate = ScheduleCalendar.dateOnly(DateTime.now());
    Future.microtask(() => _loadClasses());
  }

  Future<void> _loadClasses({bool? past}) async {
    final resolvedPast = past ?? _showPast;
    final isSwitchingRange = past != null && past != _showPast;
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
      if (isSwitchingRange) {
        _selectedDate = ScheduleCalendar.dateOnly(DateTime.now());
      }
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

  List<ClassSession> _selectedDateClasses() {
    final hasDatedClass = _classes.any(
      (session) => session.startDateTime != null,
    );
    if (!hasDatedClass) {
      return _classes;
    }
    return ScheduleCalendar.classesForDate(_classes, _selectedDate);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final visibleClasses = _showPast ? _selectedDateClasses() : _classes;

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
          if (_showPast)
            ScheduleCalendar(
              margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              classes: _classes,
              selectedDate: _selectedDate,
              mode: _calendarMode,
              onDateSelected: (date) {
                setState(() => _selectedDate = ScheduleCalendar.dateOnly(date));
              },
              onModeChanged: (mode) {
                setState(() => _calendarMode = mode);
              },
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _showPast
                        ? ScheduleCalendar.selectedDateLabel(_selectedDate)
                        : 'Buổi sắp học',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (!_isLoading)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: visibleClasses.isEmpty
                          ? cs.surfaceContainerHighest
                          : cs.errorContainer,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${visibleClasses.length} buổi',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: visibleClasses.isEmpty
                            ? cs.onSurfaceVariant
                            : cs.onErrorContainer,
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
                    child: _buildBody(context, visibleClasses),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, List<ClassSession> selectedClasses) {
    if (_error != null && _classes.isEmpty) {
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
      return _EmptyScheduleMessage(
        icon: _showPast
            ? Icons.history_toggle_off_rounded
            : Icons.calendar_month_outlined,
        message: _showPast
            ? 'Bạn chưa có buổi học đã hoàn thành.'
            : 'Bạn chưa đăng ký buổi học nào sắp diễn ra.',
      );
    }

    if (selectedClasses.isEmpty) {
      return const _EmptyScheduleMessage(
        icon: Icons.event_available_outlined,
        message: 'Ngày này chưa có lịch học.',
      );
    }

    return UpcomingClassListWidget(
      classes: selectedClasses,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      physics: const AlwaysScrollableScrollPhysics(),
      onClassTap: (session) =>
          context.push(AppRoutes.classDetail, extra: session),
    );
  }
}

class _EmptyScheduleMessage extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyScheduleMessage({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
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
              Icon(icon, size: 36),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
            ],
          ),
        ),
      ],
    );
  }
}
