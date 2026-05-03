import 'package:client/core/theme/theme.dart';
import 'package:client/features/student/model/class_session.dart';
import 'package:client/features/student/view/widgets/upcoming_classlist_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('upcoming class list scrolls vertically', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightThemeMode,
        home: Scaffold(
          body: UpcomingClassListWidget(
            classes: const [
              ClassSession(
                id: 'class-1',
                classCode: 'CLS-260324-ABCD',
                title: 'English Speaking',
                location: 'Cafe A',
                teacherName: 'Teacher Demo',
                timeText: '18:00 Hôm nay',
                priceText: '50.000đ',
                statusText: 'OPEN',
              ),
              ClassSession(
                id: 'class-2',
                classCode: 'CLS-260324-EFGH',
                title: 'Business English',
                location: 'Cafe B',
                teacherName: 'Teacher Demo 2',
                timeText: '20:00 Hôm nay',
                priceText: '60.000đ',
                statusText: 'OPEN',
              ),
            ],
          ),
        ),
      ),
    );

    final listView = tester.widget<ListView>(find.byType(ListView));
    expect(listView.scrollDirection, Axis.vertical);
    expect(find.text('English Speaking'), findsOneWidget);
    expect(find.text('Business English'), findsOneWidget);
  });
}
