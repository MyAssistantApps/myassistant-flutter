import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myassistant/screens/splash_screen.dart';

/// The splash (the owner's logo, its ring turning and its eyes blinking)
/// loads its layers and paints every frame without an error; with
/// animations off it stands still.
void main() {
  Future<void> pumpSplash(WidgetTester tester, {bool still = false}) async {
    await tester.pumpWidget(MediaQuery(
      data: MediaQueryData(size: const Size(400, 860), disableAnimations: still),
      child: const MaterialApp(home: SplashScreen()),
    ));
    // The layers decode off the test clock.
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump();
  }

  testWidgets('the logo loads, spins and blinks without errors', (tester) async {
    await pumpSplash(tester);
    expect(find.bySemanticsLabel('My Assistant'), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
    for (var i = 0; i < 80; i++) {
      await tester.pump(const Duration(milliseconds: 80));
      expect(tester.takeException(), isNull, reason: 'frame $i');
    }
  });

  testWidgets('with animations off, the logo stands still', (tester) async {
    await pumpSplash(tester, still: true);
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}
