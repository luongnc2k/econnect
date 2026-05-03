import 'package:client/core/widgets/app_scroll_behavior.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app scroll behavior allows vertical mouse drag scrolling', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        scrollBehavior: const AppScrollBehavior(),
        home: Scaffold(
          body: SizedBox(
            height: 220,
            child: ListView.builder(
              controller: controller,
              itemExtent: 48,
              itemCount: 30,
              itemBuilder: (context, index) => ListTile(
                key: ValueKey('item-$index'),
                title: Text('Item $index'),
              ),
            ),
          ),
        ),
      ),
    );

    expect(controller.offset, 0);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('item-3'))),
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveBy(const Offset(0, -160));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(controller.offset, greaterThan(0));
  });
}
