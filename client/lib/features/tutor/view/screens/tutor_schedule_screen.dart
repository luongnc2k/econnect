import 'package:client/core/localization/app_language.dart';
import 'package:client/core/router/app_router.dart';
import 'package:client/features/schedule/view/widgets/schedule_calendar.dart';
import 'package:client/features/student/model/class_session.dart';
import 'package:client/features/tutor/view/widgets/tutor_class_card_widget.dart';
import 'package:client/features/tutor/viewmodel/tutor_home_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class TutorScheduleScreen extends ConsumerStatefulWidget {
  const TutorScheduleScreen({super.key});

  @override
  ConsumerState<TutorScheduleScreen> createState() =>
      _TutorScheduleScreenState();
}

class _TutorScheduleScreenState extends ConsumerState<TutorScheduleScreen> {
  late DateTime _selectedDate;
  var _calendarMode = ScheduleCalendarViewMode.week;
  bool _showPast = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = ScheduleCalendar.dateOnly(DateTime.now());
  }

  List<ClassSession> _selectedDateClasses(List<ClassSession> classes) {
    final hasDatedClass = classes.any(
      (session) => session.startDateTime != null,
    );
    if (!hasDatedClass) {
      return classes;
    }
    return ScheduleCalendar.classesForDate(classes, _selectedDate);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tutorHomeViewModelProvider);
    final strings = ref.watch(appStringsProvider);
    final cs = Theme.of(context).colorScheme;
    final sourceClasses = _showPast ? state.pastClasses : state.upcomingClasses;
    final visibleClasses = _showPast
        ? _selectedDateClasses(sourceClasses)
        : sourceClasses;
    final isLoading = _showPast ? state.isLoadingPast : state.isLoading;
    final showError =
        !_showPast && state.error != null && sourceClasses.isEmpty;

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Text(
              strings.text(en: 'Teaching schedule', vi: 'Lịch dạy'),
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              strings.text(
                en: 'Track the classes you manage and review past teaching history by week or month.',
                vi: 'Theo dõi các lớp bạn phụ trách và xem lại lịch đã dạy theo tuần hoặc tháng.',
              ),
              style: TextStyle(color: cs.onSurfaceVariant, height: 1.4),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: SegmentedButton<bool>(
              segments: [
                ButtonSegment(
                  value: false,
                  label: Text(strings.text(en: 'Upcoming', vi: 'Sắp dạy')),
                  icon: const Icon(Icons.upcoming_outlined),
                ),
                ButtonSegment(
                  value: true,
                  label: Text(strings.text(en: 'Completed', vi: 'Đã dạy')),
                  icon: const Icon(Icons.history_rounded),
                ),
              ],
              selected: {_showPast},
              onSelectionChanged: (selection) {
                setState(() {
                  _showPast = selection.first;
                  _selectedDate = ScheduleCalendar.dateOnly(DateTime.now());
                });
              },
            ),
          ),
          if (_showPast)
            ScheduleCalendar(
              margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              classes: sourceClasses,
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
                        ? ScheduleCalendar.selectedDateLabel(
                            _selectedDate,
                            strings: strings,
                          )
                        : strings.text(
                            en: 'Upcoming teaching classes',
                            vi: 'Lớp sắp dạy',
                          ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (!isLoading)
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
                      strings.classCount(visibleClasses.length),
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
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: () =>
                        ref.read(tutorHomeViewModelProvider.notifier).refresh(),
                    child: _buildBody(
                      context,
                      strings,
                      sourceClasses: sourceClasses,
                      selectedClasses: visibleClasses,
                      showError: showError,
                      error: state.error,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppStrings strings, {
    required List<ClassSession> sourceClasses,
    required List<ClassSession> selectedClasses,
    required bool showError,
    required String? error,
  }) {
    if (showError) {
      return _EmptyTutorSchedule(
        icon: Icons.error_outline_rounded,
        title: strings.text(
          en: 'Could not load teaching schedule',
          vi: 'Không thể tải lịch dạy',
        ),
        message:
            error ??
            strings.text(
              en: 'Please try again later.',
              vi: 'Vui lòng thử lại sau.',
            ),
      );
    }

    if (sourceClasses.isEmpty) {
      return _EmptyTutorSchedule(
        icon: _showPast
            ? Icons.history_toggle_off_rounded
            : Icons.calendar_month_outlined,
        title: _showPast
            ? strings.text(
                en: 'No completed classes yet',
                vi: 'Chưa có lớp đã dạy',
              )
            : strings.text(
                en: 'No upcoming teaching classes',
                vi: 'Chưa có lớp sắp dạy',
              ),
        message: _showPast
            ? strings.text(
                en: 'Completed classes will appear here.',
                vi: 'Các lớp đã hoàn thành sẽ xuất hiện tại đây.',
              )
            : strings.text(
                en: 'When you create a new class, it will appear here.',
                vi: 'Khi bạn tạo lớp mới, lớp sắp dạy sẽ xuất hiện tại đây.',
              ),
      );
    }

    if (selectedClasses.isEmpty) {
      return _EmptyTutorSchedule(
        icon: Icons.event_available_outlined,
        title: strings.text(
          en: 'No teaching schedule on this date',
          vi: 'Ngày này chưa có lịch dạy',
        ),
        message: strings.text(
          en: 'Choose a marked date to view classes.',
          vi: 'Chọn ngày có đánh dấu đỏ để xem danh sách lớp.',
        ),
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: selectedClasses.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final session = selectedClasses[index];
        return TutorClassCardWidget(
          session: session,
          onTap: () =>
              context.push(AppRoutes.teacherClassDetail, extra: session),
        );
      },
    );
  }
}

class _EmptyTutorSchedule extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _EmptyTutorSchedule({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Icon(icon, size: 36, color: cs.onSurfaceVariant),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.onSurfaceVariant, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
