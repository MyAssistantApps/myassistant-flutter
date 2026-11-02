// The Home header's tiny robot (widgets/robot_badge.dart): the splash's
// layers, small — it loads, turns and blinks without an error, and stands
// still with animations off.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myassistant/widgets/robot_badge.dart';

void main() {
  Future<void> pump(WidgetTester t, {bool still = false}) async {
    await t.pumpWidget(MediaQuery(
      data: MediaQueryData(disableAnimations: still),
      child: const MaterialApp(home: Scaffold(body: Center(child: RobotBadge(size: 50)))),
    ));
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await t.pump();
  }

  testWidgets('loads, turns and blinks without errors', (t) async {
    await pump(t);
    expect(find.bySemanticsLabel('MyAssistant robot'), findsOneWidget);
    expect(t.getSize(find.byType(RobotBadge)), const Size(50, 50));
    for (var i = 0; i < 60; i++) {
      await t.pump(const Duration(milliseconds: 100));
      expect(t.takeException(), isNull, reason: 'frame $i');
    }
  });

  testWidgets('with animations off it stands still', (t) async {
    await pump(t, still: true);
    await t.pump(const Duration(seconds: 1));
    expect(t.takeException(), isNull);
    expect(t.binding.hasScheduledFrame, isFalse);
  });
}
