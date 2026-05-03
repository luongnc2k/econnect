import 'package:client/features/schedule/view/widgets/schedule_calendar.dart';
import 'package:client/features/student/model/class_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('month calendar only renders dates that have classes', (
    tester,
  ) async {
    DateTime? tappedDate;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScheduleCalendar(
            classes: [
              ClassSession(
                title: 'May class',
                location: 'Room A',
                teacherName: 'Tutor A',
                timeText: '18:00',
                priceText: '50000 VND',
                startDateTime: DateTime(2026, 5, 3, 18),
              ),
              ClassSession(
                title: 'Another May class',
                location: 'Room B',
                teacherName: 'Tutor B',
                timeText: '19:00',
                priceText: '50000 VND',
                startDateTime: DateTime(2026, 5, 20, 19),
              ),
              ClassSession(
                title: 'April class',
                location: 'Room C',
                teacherName: 'Tutor C',
                timeText: '20:00',
                priceText: '50000 VND',
                startDateTime: DateTime(2026, 4, 30, 20),
              ),
            ],
            selectedDate: DateTime(2026, 5, 10),
            mode: ScheduleCalendarViewMode.month,
            onDateSelected: (date) => tappedDate = date,
            onModeChanged: (_) {},
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('schedule-calendar-day-2026-05-03')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('schedule-calendar-day-2026-05-20')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('schedule-calendar-day-2026-05-04')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('schedule-calendar-day-2026-04-30')),
      findsNothing,
    );

    await tester.tap(
      find.byKey(const ValueKey('schedule-calendar-day-2026-05-20')),
    );

    expect(tappedDate, DateTime(2026, 5, 20));
  });
}
