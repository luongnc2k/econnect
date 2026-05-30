import 'package:client/core/localization/app_language.dart';
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

  static String selectedDateLabel(DateTime value, {AppStrings? strings}) {
    return (strings ?? const AppStrings('vi')).selectedDateLabel(value);
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

  String _periodLabel(AppStrings strings) {
    final selected = _normalizedSelectedDate;
    return switch (mode) {
      ScheduleCalendarViewMode.week => _weekLabel(selected, strings),
      ScheduleCalendarViewMode.month =>
        strings.isVietnamese
            ? 'Tháng ${selected.month}, ${selected.year}'
            : '${strings.monthLabels[selected.month - 1]} ${selected.year}',
    };
  }

  String _weekLabel(DateTime value, AppStrings strings) {
    final start = _weekStart(value);
    final end = start.add(const Duration(days: 6));
    if (start.month == end.month && start.year == end.year) {
      final month = strings.monthLabels[start.month - 1];
      if (strings.isVietnamese) {
        return '${start.day} - ${end.day} $month, ${start.year}';
      }
      return '$month ${start.day} - ${end.day}, ${start.year}';
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
    final strings = AppStrings(Localizations.localeOf(context).languageCode);
    final maxHeight = (MediaQuery.sizeOf(context).height * 0.25)
        .clamp(156.0, 220.0)
        .toDouble();

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Container(
        margin: margin,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: cs.surfaceContainer,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SegmentedButton<ScheduleCalendarViewMode>(
              showSelectedIcon: false,
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: WidgetStatePropertyAll(
                  EdgeInsets.symmetric(horizontal: 10),
                ),
              ),
              segments: [
                ButtonSegment(
                  value: ScheduleCalendarViewMode.week,
                  icon: const Icon(Icons.view_week_rounded, size: 18),
                  label: Text(strings.text(en: 'Week', vi: 'Tuần')),
                ),
                ButtonSegment(
                  value: ScheduleCalendarViewMode.month,
                  icon: const Icon(Icons.calendar_month_rounded, size: 18),
                  label: Text(strings.text(en: 'Month', vi: 'Tháng')),
                ),
              ],
              selected: {mode},
              onSelectionChanged: (selection) => onModeChanged(selection.first),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                IconButton.filledTonal(
                  onPressed: () => onDateSelected(_shiftedDate(-1)),
                  icon: const Icon(Icons.chevron_left_rounded),
                  iconSize: 20,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 34,
                    height: 34,
                  ),
                  tooltip: strings.text(en: 'Previous period', vi: 'Kỳ trước'),
                ),
                Expanded(
                  child: Text(
                    _periodLabel(strings),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: () => onDateSelected(_shiftedDate(1)),
                  icon: const Icon(Icons.chevron_right_rounded),
                  iconSize: 20,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 34,
                    height: 34,
                  ),
                  tooltip: strings.text(en: 'Next period', vi: 'Kỳ sau'),
                ),
                const SizedBox(width: 4),
                IconButton.filledTonal(
                  onPressed: () => onDateSelected(dateOnly(DateTime.now())),
                  icon: const Icon(Icons.my_location_rounded),
                  iconSize: 18,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 34,
                    height: 34,
                  ),
                  tooltip: strings.text(en: 'Today', vi: 'Hôm nay'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            switch (mode) {
              ScheduleCalendarViewMode.week => _buildWeekView(context, strings),
              ScheduleCalendarViewMode.month => _buildMonthView(
                context,
                strings,
              ),
            },
          ],
        ),
      ),
    );
  }

  Widget _buildWeekView(BuildContext context, AppStrings strings) {
    final start = _weekStart(_normalizedSelectedDate);
    final today = dateOnly(DateTime.now());
    final days = List.generate(7, (index) => start.add(Duration(days: index)));

    return SizedBox(
      height: 50,
      child: Row(
        children: [
          for (final day in days)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: _CalendarDayCell(
                  strings: strings,
                  date: day,
                  classCount: classesForDate(classes, day).length,
                  isSelected: day == _normalizedSelectedDate,
                  isToday: day == today,
                  hasClass: _activeDates.contains(day),
                  inCurrentMonth: true,
                  compact: true,
                  onTap: () => onDateSelected(day),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMonthView(BuildContext context, AppStrings strings) {
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          strings.text(
            en: 'No schedule this month.',
            vi: 'Tháng này chưa có lịch.',
          ),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return SizedBox(
      height: 54,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: monthClassDates.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final day = monthClassDates[index];
          return _MonthClassDayChip(
            strings: strings,
            date: day,
            classCount: classesForDate(classes, day).length,
            isSelected: day == selected,
            isToday: day == today,
            onTap: () => onDateSelected(day),
          );
        },
      ),
    );
  }
}

class _MonthClassDayChip extends StatelessWidget {
  final AppStrings strings;
  final DateTime date;
  final int classCount;
  final bool isSelected;
  final bool isToday;
  final VoidCallback onTap;

  const _MonthClassDayChip({
    required this.strings,
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
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          constraints: const BoxConstraints(minWidth: 58),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor, width: isToday ? 1.3 : 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                strings.weekdayShortLabels[date.weekday - 1],
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: foreground,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${date.day}',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                strings.classCount(classCount),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: foreground,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  height: 1,
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
  final AppStrings strings;
  final DateTime date;
  final int classCount;
  final bool isSelected;
  final bool isToday;
  final bool hasClass;
  final bool inCurrentMonth;
  final bool compact;
  final VoidCallback onTap;

  const _CalendarDayCell({
    required this.strings,
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
          height: compact ? 50 : 72,
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 2 : 6,
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
              Text(
                strings.weekdayShortLabels[date.weekday - 1],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: foreground,
                  fontSize: compact ? 9 : null,
                  fontWeight: FontWeight.w700,
                  height: compact ? 1 : null,
                ),
              ),
              SizedBox(height: compact ? 3 : 2),
              Text(
                '${date.day}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: foreground,
                  fontSize: compact ? 14 : null,
                  fontWeight: FontWeight.w900,
                  height: compact ? 1 : null,
                ),
              ),
              SizedBox(height: compact ? 1 : 2),
              SizedBox(
                height: compact ? 6 : 14,
                child: hasClass
                    ? compact
                          ? _ClassDot(color: isSelected ? foreground : cs.error)
                          : Text(
                              strings.classCount(classCount),
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
