import 'package:client/features/student/model/class_session.dart';
import 'package:client/features/tutor/view/widgets/tutor_class_card_widget.dart';
import 'package:client/features/tutor/viewmodel/tutor_home_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    // past: 60 days back, most recent first
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

          // ── Class list ─────────────────────────────────────────
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: () =>
                        ref.read(tutorHomeViewModelProvider.notifier).refresh(),
                    child: todayClasses.isEmpty
                        ? _EmptyDay(date: _selectedDate)
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                            itemCount: todayClasses.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (_, i) => TutorClassCardWidget(
                              session: todayClasses[i],
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

// ─── Empty state ─────────────────────────────────────────────────────────────

class _EmptyDay extends StatelessWidget {
  final DateTime date;

  const _EmptyDay({required this.date});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isToday = date ==
        DateTime(
            DateTime.now().year, DateTime.now().month, DateTime.now().day);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: 260,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.event_available_outlined,
                  size: 52, color: cs.onSurfaceVariant),
              const SizedBox(height: 12),
              Text(
                isToday
                    ? 'Hôm nay không có lớp nào'
                    : 'Không có lớp học ngày này',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
