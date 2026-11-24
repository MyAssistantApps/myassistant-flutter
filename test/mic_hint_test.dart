// The dock mic's hint (widgets/mic_hint.dart): the bubble comes up soon
// after Home opens, then every 5 minutes, and goes away again, never during a conversation, and never
// takes a tap meant for the mic.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myassistant/widgets/mic_hint.dart';

void main() {
  double opacity(WidgetTester t) =>
      t.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity;

  Future<void> pumpHint(WidgetTester t, ValueNotifier<bool> busy, VoidCallback onTap) => t.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: MicHint(
              listenable: busy,
              quiet: () => busy.value,
              child: SizedBox(width: 76, height: 76, child: ElevatedButton(onPressed: onTap, child: const Text('Mic'))),
            ),
          ),
        ),
      ));

  testWidgets('shows, hides, and comes back every 5 minutes', (t) async {
    final busy = ValueNotifier(false);
    await pumpHint(t, busy, () {});
    expect(find.text('Tap to talk, hold for 3 seconds to customise'), findsOneWidget);
    expect(opacity(t), 0);

    await t.pump(const Duration(milliseconds: 1300));
    expect(opacity(t), 1, reason: 'first one soon after Home opens');
    await t.pump(const Duration(seconds: 3));
    expect(opacity(t), 0);

    await t.pump(const Duration(seconds: 30));
    expect(opacity(t), 0, reason: 'not back after seconds');
    await t.pump(const Duration(minutes: 5) - const Duration(milliseconds: 4300) - const Duration(seconds: 30) + const Duration(milliseconds: 100)); // 5 min mark
    expect(opacity(t), 1);
    await t.pump(const Duration(seconds: 3));
    expect(opacity(t), 0);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('stays hidden during a conversation', (t) async {
    final busy = ValueNotifier(true);
    await pumpHint(t, busy, () {});
    await t.pump(const Duration(milliseconds: 1300));
    expect(opacity(t), 0);
    await t.pump(const Duration(seconds: 5));
    expect(opacity(t), 0);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('the mic under it still takes taps', (t) async {
    var taps = 0;
    await pumpHint(t, ValueNotifier(false), () => taps++);
    await t.pump(const Duration(milliseconds: 1300));
    await t.tap(find.text('Mic'));
    expect(taps, 1);
    await t.pumpWidget(const SizedBox());
  });
}
