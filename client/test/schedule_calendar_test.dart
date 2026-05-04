import 'package:client/features/schedule/view/widgets/schedule_calendar.dart';
import 'package:client/features/student/model/class_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('selected date label uses Vietnamese accents', () {
    expect(
      ScheduleCalendar.selectedDateLabel(DateTime(2026, 5, 3)),
      'Chủ nhật, 3 tháng 5',
    );
  });

  testWidgets('week calendar stays near one quarter of phone height', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              ScheduleCalendar(
                classes: [
                  ClassSession(
                    title: 'May class',
                    location: 'Room A',
                    teacherName: 'Tutor A',
                    timeText: '18:00',
                    priceText: '50000 VND',
                    startDateTime: DateTime(2026, 5, 3, 18),
                  ),
                ],
                selectedDate: DateTime(2026, 5, 3),
                mode: ScheduleCalendarViewMode.week,
                onDateSelected: (_) {},
                onModeChanged: (_) {},
              ),
            ],
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byType(ScheduleCalendar)).height,
      lessThanOrEqualTo(200),
    );
  });

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
    expect(find.text('Tháng 5, 2026'), findsOneWidget);
    expect(find.text('1 lớp'), findsNWidgets(2));

    await tester.tap(
      find.byKey(const ValueKey('schedule-calendar-day-2026-05-20')),
    );

    expect(tappedDate, DateTime(2026, 5, 20));
  });

  testWidgets('month calendar empty state uses Vietnamese accents', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScheduleCalendar(
            classes: const [],
            selectedDate: DateTime(2026, 5, 10),
            mode: ScheduleCalendarViewMode.month,
            onDateSelected: (_) {},
            onModeChanged: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Tháng này chưa có lịch.'), findsOneWidget);
  });
}
