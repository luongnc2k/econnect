import 'package:client/core/router/app_router.dart';
import 'package:client/features/student/model/class_session.dart';
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
  late final ScrollController _stripController;
  bool _showPast = false;

  static const _dayCount = 60;
  late final List<DateTime> _futureDays;
  late final List<DateTime> _pastDays;

  @override
  void initState() {
    super.initState();
    final today = _dateOnly(DateTime.now());
    _selectedDate = today;
    _futureDays = List.generate(_dayCount, (i) => today.add(Duration(days: i)));
    _pastDays = List.generate(_dayCount, (i) => today.subtract(Duration(days: i)));
    _stripController = ScrollController();
  }

  @override
  void dispose() {
    _stripController.dispose();
    super.dispose();
  }

  DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  List<ClassSession> _classesForDate(
    List<ClassSession> all,
    DateTime date,
  ) =>
      all.where((c) {
        if (c.startDateTime == null) return false;
        final d = _dateOnly(c.startDateTime!);
        return d == date;
      }).toList()
        ..sort((a, b) =>
            a.startDateTime!.compareTo(b.startDateTime!));

  Set<DateTime> _datesWithClasses(List<ClassSession> all) => {
        for (final c in all)
          if (c.startDateTime != null) _dateOnly(c.startDateTime!),
      };

  String _formatMonthYear(DateTime dt) {
    const months = [
      'Tháng 1', 'Tháng 2', 'Tháng 3', 'Tháng 4',
      'Tháng 5', 'Tháng 6', 'Tháng 7', 'Tháng 8',
      'Tháng 9', 'Tháng 10', 'Tháng 11', 'Tháng 12',
    ];
    return '${months[dt.month - 1]}, ${dt.year}';
  }

  String _formatSelectedDate(DateTime dt) {
    const weekdays = [
      'Chủ nhật', 'Thứ hai', 'Thứ ba', 'Thứ tư',
      'Thứ năm', 'Thứ sáu', 'Thứ bảy',
    ];
    const months = [
      'tháng 1', 'tháng 2', 'tháng 3', 'tháng 4',
      'tháng 5', 'tháng 6', 'tháng 7', 'tháng 8',
      'tháng 9', 'tháng 10', 'tháng 11', 'tháng 12',
    ];
    return '${weekdays[dt.weekday % 7]}, ${dt.day} ${months[dt.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tutorHomeViewModelProvider);
    final cs = Theme.of(context).colorScheme;
    final sourceClasses = _showPast ? state.pastClasses : state.upcomingClasses;
    final isLoading = _showPast ? state.isLoadingPast : state.isLoading;
    final activeDates = _datesWithClasses(sourceClasses);
    final todayClasses = _classesForDate(sourceClasses, _selectedDate);
    final stripDays = _showPast ? _pastDays : _futureDays;

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── AppBar ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Text(
              'Lịch dạy',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),

          // ── Toggle sắp dạy / đã dạy ───────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: false,
                  label: Text('Sắp dạy'),
                  icon: Icon(Icons.upcoming_outlined),
                ),
                ButtonSegment(
                  value: true,
                  label: Text('Đã dạy'),
                  icon: Icon(Icons.history_rounded),
                ),
              ],
              selected: {_showPast},
              onSelectionChanged: (val) {
                final today = _dateOnly(DateTime.now());
                setState(() {
                  _showPast = val.first;
                  _selectedDate = today;
                });
                // reset scroll to start
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_stripController.hasClients) {
                    _stripController.jumpTo(0);
                  }
                });
              },
            ),
          ),

          // ── Month label ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              _formatMonthYear(_selectedDate),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: cs.onSurfaceVariant,
              ),
            ),
          ),

          // ── Date strip ─────────────────────────────────────────
          SizedBox(
            height: 72,
            child: ListView.builder(
              controller: _stripController,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: stripDays.length,
              itemBuilder: (context, i) {
                final day = stripDays[i];
                final isSelected = day == _selectedDate;
                final hasClass = activeDates.contains(day);
                final isToday = day == _dateOnly(DateTime.now());
                return _DayCell(
                  day: day,
                  isSelected: isSelected,
                  hasClass: hasClass,
                  isToday: isToday,
                  onTap: () => setState(() => _selectedDate = day),
                );
              },
            ),
          ),

          const SizedBox(height: 4),
          Divider(height: 1, color: cs.outlineVariant),

          // ── Selected date label ────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Row(
              children: [
                Text(
                  _formatSelectedDate(_selectedDate),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(width: 8),
                if (todayClasses.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${todayClasses.length} lớp',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: cs.onPrimaryContainer,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── Timeline ───────────────────────────────────────────
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: () =>
                        ref.read(tutorHomeViewModelProvider.notifier).refresh(),
                    child: _DayTimeline(
                      date: _selectedDate,
                      classes: todayClasses,
                      onTapClass: (s) => context.push(
                        AppRoutes.teacherClassDetail,
                        extra: s,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── Day cell ───────────────────────────────────────────────────────────────

class _DayCell extends StatelessWidget {
  final DateTime day;
  final bool isSelected;
  final bool hasClass;
  final bool isToday;
  final VoidCallback onTap;

  const _DayCell({
    required this.day,
    required this.isSelected,
    required this.hasClass,
    required this.isToday,
    required this.onTap,
  });

  static const _weekdayShort = ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 52,
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? cs.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: isToday && !isSelected
              ? Border.all(color: cs.primary, width: 1.5)
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _weekdayShort[day.weekday % 7],
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isSelected
                    ? cs.onPrimary
                    : cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${day.day}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isSelected ? cs.onPrimary : cs.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            // dot if has class
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: hasClass
                    ? (isSelected
                        ? cs.onPrimary.withValues(alpha: 0.7)
                        : cs.primary)
                    : Colors.transparent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Day Timeline ─────────────────────────────────────────────────────────────

class _DayTimeline extends StatefulWidget {
  final DateTime date;
  final List<ClassSession> classes;
  final void Function(ClassSession) onTapClass;

  static const startHour = 6;
  static const _endHour = 22;
  static const hourHeight = 64.0;
  static const _labelWidth = 44.0;

  const _DayTimeline({
    required this.date,
    required this.classes,
    required this.onTapClass,
  });

  @override
  State<_DayTimeline> createState() => _DayTimelineState();
}

class _DayTimelineState extends State<_DayTimeline> {
  final ScrollController _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToFocus());
  }

  @override
  void didUpdateWidget(_DayTimeline old) {
    super.didUpdateWidget(old);
    // Scroll when date changes or when classes are loaded for the first time
    if (old.date != widget.date ||
        (old.classes.isEmpty && widget.classes.isNotEmpty)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToFocus());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _scrollToFocus() {
    if (!_controller.hasClients) return;

    final now = DateTime.now();
    final isToday = widget.date.year == now.year &&
        widget.date.month == now.month &&
        widget.date.day == now.day;

    double focusHour;
    if (isToday) {
      focusHour = now.hour.toDouble() - 1;
    } else if (widget.classes.isNotEmpty &&
        widget.classes.first.startDateTime != null) {
      focusHour = widget.classes.first.startDateTime!.hour.toDouble() - 0.5;
    } else {
      return;
    }

    final offset =
        ((focusHour - _DayTimeline.startHour) * _DayTimeline.hourHeight)
            .clamp(0.0, _controller.position.maxScrollExtent);

    _controller.animateTo(
      offset,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
    );
  }

  static double _topFor(DateTime dt) =>
      ((dt.hour - _DayTimeline.startHour) + dt.minute / 60) *
      _DayTimeline.hourHeight;

  static double _heightFor(DateTime start, DateTime end) {
    final mins = end.difference(start).inMinutes;
    return (mins / 60) * _DayTimeline.hourHeight;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final totalHours = _DayTimeline._endHour - _DayTimeline.startHour;
    final totalHeight = totalHours * _DayTimeline.hourHeight;

    final now = DateTime.now();
    final isToday = widget.date.year == now.year &&
        widget.date.month == now.month &&
        widget.date.day == now.day;
    final nowTop =
        isToday && now.hour >= _DayTimeline.startHour && now.hour < _DayTimeline._endHour
            ? _topFor(now)
            : null;

    return SingleChildScrollView(
      controller: _controller,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(0, 8, 16, 32),
      child: SizedBox(
        height: totalHeight + 24,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Hour labels ──────────────────────────────────────
            SizedBox(
              width: _DayTimeline._labelWidth,
              height: totalHeight,
              child: Stack(
                children: [
                  for (int h = _DayTimeline.startHour; h <= _DayTimeline._endHour; h++)
                    Positioned(
                      top: (h - _DayTimeline.startHour) * _DayTimeline.hourHeight - 8,
                      left: 0,
                      right: 0,
                      child: Text(
                        '${h.toString().padLeft(2, '0')}:00',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // ── Grid + class blocks ──────────────────────────────
            Expanded(
              child: Stack(
                children: [
                  // Hour grid lines
                  for (int h = 0; h <= totalHours; h++)
                    Positioned(
                      top: h * _DayTimeline.hourHeight,
                      left: 0,
                      right: 0,
                      child: Divider(
                        height: 1,
                        color: h == 0
                            ? cs.outlineVariant
                            : cs.outlineVariant.withValues(alpha: 0.4),
                      ),
                    ),

                  // Half-hour dashed lines
                  for (int h = 0; h < totalHours; h++)
                    Positioned(
                      top: h * _DayTimeline.hourHeight + _DayTimeline.hourHeight / 2,
                      left: 0,
                      right: 0,
                      child: Divider(
                        height: 1,
                        color: cs.outlineVariant.withValues(alpha: 0.2),
                      ),
                    ),

                  // Current time indicator
                  if (nowTop != null) ...[
                    Positioned(
                      top: nowTop - 1,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 2,
                        color: cs.error,
                      ),
                    ),
                    Positioned(
                      top: nowTop - 5,
                      left: -4,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: cs.error,
                        ),
                      ),
                    ),
                  ],

                  // Class blocks
                  for (final s in widget.classes)
                    if (s.startDateTime != null && s.endDateTime != null)
                      Positioned(
                        top: _topFor(s.startDateTime!),
                        left: 0,
                        right: 0,
                        height: _heightFor(
                          s.startDateTime!,
                          s.endDateTime!,
                        ).clamp(28.0, double.infinity),
                        child: _ClassBlock(
                          session: s,
                          cs: cs,
                          onTap: () => widget.onTapClass(s),
                        ),
                      ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClassBlock extends StatelessWidget {
  final ClassSession session;
  final ColorScheme cs;
  final VoidCallback onTap;

  const _ClassBlock({
    required this.session,
    required this.cs,
    required this.onTap,
  });

  Color _blockColor() {
    switch (session.statusText) {
      case 'DONE':
        return cs.secondaryContainer;
      case 'HUỶ':
        return cs.errorContainer;
      default:
        return cs.primaryContainer;
    }
  }

  Color _textColor() {
    switch (session.statusText) {
      case 'DONE':
        return cs.onSecondaryContainer;
      case 'HUỶ':
        return cs.onErrorContainer;
      default:
        return cs.onPrimaryContainer;
    }
  }

  String _timeRange() {
    final s = session.startDateTime!;
    final e = session.endDateTime!;
    final sh = s.hour.toString().padLeft(2, '0');
    final sm = s.minute.toString().padLeft(2, '0');
    final eh = e.hour.toString().padLeft(2, '0');
    final em = e.minute.toString().padLeft(2, '0');
    return '$sh:$sm – $eh:$em';
  }

  @override
  Widget build(BuildContext context) {
    final blockColor = _blockColor();
    final textColor = _textColor();
    final durationMins =
        session.endDateTime!.difference(session.startDateTime!).inMinutes;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 1),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: blockColor,
          borderRadius: BorderRadius.circular(8),
          border: Border(
            left: BorderSide(
              color: session.statusText == 'DONE'
                  ? cs.secondary
                  : session.statusText == 'HUỶ'
                      ? cs.error
                      : cs.primary,
              width: 3,
            ),
          ),
        ),
        child: durationMins < 45
            // compact: single line
            ? Text(
                session.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _timeRange(),
                    style: TextStyle(
                      fontSize: 11,
                      color: textColor.withValues(alpha: 0.75),
                    ),
                  ),
                  if (durationMins >= 75 && session.tags.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      session.tags.first,
                      style: TextStyle(
                        fontSize: 11,
                        color: textColor.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}
