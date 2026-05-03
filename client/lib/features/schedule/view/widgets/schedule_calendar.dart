import 'package:client/features/student/model/class_session.dart';
import 'package:flutter/material.dart';

enum ScheduleCalendarViewMode { week, month }

class ScheduleCalendar extends StatelessWidget {
  final List<ClassSession> classes;
  final DateTime selectedDate;
  final ScheduleCalendarViewMode mode;
  final ValueChanged<DateTime> onDateSelected;
  final ValueChanged<ScheduleCalendarViewMode> onModeChanged;
  final EdgeInsetsGeometry margin;

  const ScheduleCalendar({
    super.key,
    required this.classes,
    required this.selectedDate,
    required this.mode,
    required this.onDateSelected,
    required this.onModeChanged,
    this.margin = EdgeInsets.zero,
  });

  static const _weekdayLabels = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
  static const _fullWeekdayLabels = [
    'Thứ hai',
    'Thứ ba',
    'Thứ tư',
    'Thứ năm',
    'Thứ sáu',
    'Thứ bảy',
    'Chủ nhật',
  ];
  static const _monthLabels = [
    'tháng 1',
    'tháng 2',
    'tháng 3',
    'tháng 4',
    'tháng 5',
    'tháng 6',
    'tháng 7',
    'tháng 8',
    'tháng 9',
    'tháng 10',
    'tháng 11',
    'tháng 12',
  ];

  static DateTime dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  static String dateKey(DateTime value) {
    final date = dateOnly(value);
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  static List<ClassSession> classesForDate(
    List<ClassSession> classes,
    DateTime date,
  ) {
    final target = dateOnly(date);
    final items = classes.where((session) {
      final start = session.startDateTime;
      return start != null && dateOnly(start) == target;
    }).toList();
    items.sort((a, b) => a.startDateTime!.compareTo(b.startDateTime!));
    return items;
  }

  static Set<DateTime> datesWithClasses(List<ClassSession> classes) {
    return {
      for (final session in classes)
        if (session.startDateTime != null) dateOnly(session.startDateTime!),
    };
  }

  static String selectedDateLabel(DateTime value) {
    final date = dateOnly(value);
    final weekday = _fullWeekdayLabels[date.weekday - 1];
    return '$weekday, ${date.day} ${_monthLabels[date.month - 1]}';
  }

  DateTime get _normalizedSelectedDate => dateOnly(selectedDate);

  Set<DateTime> get _activeDates => datesWithClasses(classes);

  DateTime _weekStart(DateTime value) {
    final date = dateOnly(value);
    return date.subtract(Duration(days: date.weekday - 1));
  }

  DateTime _shiftedDate(int direction) {
    final selected = _normalizedSelectedDate;
    return switch (mode) {
      ScheduleCalendarViewMode.week => selected.add(
        Duration(days: direction * 7),
      ),
      ScheduleCalendarViewMode.month => _shiftMonth(selected, direction),
    };
  }

  DateTime _shiftMonth(DateTime value, int direction) {
    final targetMonth = value.month + direction;
    final firstOfTarget = DateTime(value.year, targetMonth);
    final maxDay = DateUtils.getDaysInMonth(
      firstOfTarget.year,
      firstOfTarget.month,
    );
    return DateTime(
      firstOfTarget.year,
      firstOfTarget.month,
      value.day.clamp(1, maxDay),
    );
  }

  String _periodLabel() {
    final selected = _normalizedSelectedDate;
    return switch (mode) {
      ScheduleCalendarViewMode.week => _weekLabel(selected),
      ScheduleCalendarViewMode.month =>
        'Tháng ${selected.month}, ${selected.year}',
    };
  }

  String _weekLabel(DateTime value) {
    final start = _weekStart(value);
    final end = start.add(const Duration(days: 6));
    if (start.month == end.month && start.year == end.year) {
      return '${start.day} - ${end.day} ${_monthLabels[start.month - 1]}, ${start.year}';
    }
    return '${_shortDate(start)} - ${_shortDate(end)}';
  }

  String _shortDate(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day/$month/${value.year}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      margin: margin,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        children: [
          SegmentedButton<ScheduleCalendarViewMode>(
            segments: const [
              ButtonSegment(
                value: ScheduleCalendarViewMode.week,
                icon: Icon(Icons.view_week_rounded),
                label: Text('Tuần'),
              ),
              ButtonSegment(
                value: ScheduleCalendarViewMode.month,
                icon: Icon(Icons.calendar_month_rounded),
                label: Text('Tháng'),
              ),
            ],
            selected: {mode},
            onSelectionChanged: (selection) => onModeChanged(selection.first),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              IconButton.filledTonal(
                onPressed: () => onDateSelected(_shiftedDate(-1)),
                icon: const Icon(Icons.chevron_left_rounded),
                tooltip: 'Kỳ trước',
              ),
              Expanded(
                child: Text(
                  _periodLabel(),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              IconButton.filledTonal(
                onPressed: () => onDateSelected(_shiftedDate(1)),
                icon: const Icon(Icons.chevron_right_rounded),
                tooltip: 'Kỳ sau',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => onDateSelected(dateOnly(DateTime.now())),
              icon: const Icon(Icons.my_location_rounded),
              label: const Text('Hôm nay'),
            ),
          ),
          const SizedBox(height: 4),
          switch (mode) {
            ScheduleCalendarViewMode.week => _buildWeekView(context),
            ScheduleCalendarViewMode.month => _buildMonthView(context),
          },
        ],
      ),
    );
  }

  Widget _buildWeekView(BuildContext context) {
    final start = _weekStart(_normalizedSelectedDate);
    final today = dateOnly(DateTime.now());
    final days = List.generate(7, (index) => start.add(Duration(days: index)));

    return Row(
      children: [
        for (final day in days)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: _CalendarDayCell(
                date: day,
                classCount: classesForDate(classes, day).length,
                isSelected: day == _normalizedSelectedDate,
                isToday: day == today,
                hasClass: _activeDates.contains(day),
                inCurrentMonth: true,
                compact: false,
                onTap: () => onDateSelected(day),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMonthView(BuildContext context) {
    final selected = _normalizedSelectedDate;
    final today = dateOnly(DateTime.now());
    final monthClassDates =
        _activeDates
            .where(
              (date) =>
                  date.year == selected.year && date.month == selected.month,
            )
            .toList()
          ..sort();

    if (monthClassDates.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'ThÃ¡ng nÃ y chÆ°a cÃ³ lá»‹ch.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final day in monthClassDates)
            _MonthClassDayChip(
              date: day,
              classCount: classesForDate(classes, day).length,
              isSelected: day == selected,
              isToday: day == today,
              onTap: () => onDateSelected(day),
            ),
        ],
      ),
    );
  }
}

class _MonthClassDayChip extends StatelessWidget {
  final DateTime date;
  final int classCount;
  final bool isSelected;
  final bool isToday;
  final VoidCallback onTap;

  const _MonthClassDayChip({
    required this.date,
    required this.classCount,
    required this.isSelected,
    required this.isToday,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final background = isSelected ? cs.error : cs.errorContainer;
    final foreground = isSelected ? cs.onError : cs.onErrorContainer;
    final borderColor = isToday ? cs.primary : Colors.transparent;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey(
          'schedule-calendar-day-${ScheduleCalendar.dateKey(date)}',
        ),
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          constraints: const BoxConstraints(minWidth: 74),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: isToday ? 1.3 : 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                ScheduleCalendar._weekdayLabels[date.weekday - 1],
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${date.day}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$classCount lá»›p',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CalendarDayCell extends StatelessWidget {
  final DateTime date;
  final int classCount;
  final bool isSelected;
  final bool isToday;
  final bool hasClass;
  final bool inCurrentMonth;
  final bool compact;
  final VoidCallback onTap;

  const _CalendarDayCell({
    required this.date,
    required this.classCount,
    required this.isSelected,
    required this.isToday,
    required this.hasClass,
    required this.inCurrentMonth,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final background = hasClass
        ? (isSelected ? cs.error : cs.errorContainer)
        : isToday
        ? cs.primaryContainer
        : Colors.transparent;
    final foreground = hasClass
        ? (isSelected ? cs.onError : cs.onErrorContainer)
        : isToday
        ? cs.onPrimaryContainer
        : inCurrentMonth
        ? cs.onSurface
        : cs.onSurfaceVariant.withValues(alpha: 0.52);
    final borderColor = hasClass && isSelected ? cs.error : Colors.transparent;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey(
          'schedule-calendar-day-${ScheduleCalendar.dateKey(date)}',
        ),
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: compact ? 46 : 72,
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 4 : 6,
            vertical: compact ? 4 : 6,
          ),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: borderColor,
              width: hasClass && isSelected ? 1.4 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!compact)
                Text(
                  ScheduleCalendar._weekdayLabels[date.weekday - 1],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              if (!compact) const SizedBox(height: 2),
              Text(
                '${date.day}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              SizedBox(
                height: compact ? 6 : 14,
                child: hasClass
                    ? compact
                          ? _ClassDot(color: isSelected ? foreground : cs.error)
                          : Text(
                              '$classCount lớp',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: foreground,
                                    fontWeight: FontWeight.w800,
                                  ),
                            )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClassDot extends StatelessWidget {
  final Color color;

  const _ClassDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 5,
        height: 5,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}
