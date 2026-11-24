// The dock mic's colour (services/mic_color.dart, screens/mic_color_screen.dart):
// the default is the original violet, a choice is kept across launches,
// an unknown saved value falls back to the default, and picking a swatch
// on the page recolours the mic straight away.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myassistant/screens/mic_color_screen.dart';
import 'package:myassistant/services/mic_color.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('the default is the original violet mic', () {
    final d = MicColorStore.options.first;
    expect(d.id, 'violet');
    expect(d.ring, const Color(0xFF8B5CF6));
    expect(d.glyph, const Color(0xFFC4B5FD));
    expect(MicColorStore.byId('no-such-colour').id, 'violet');
    expect(MicColorStore.byId(null).id, 'violet');
  });

  test('every colour has its own id', () {
    final ids = MicColorStore.options.map((o) => o.id).toSet();
    expect(ids.length, MicColorStore.options.length);
  });

  testWidgets('picking a colour applies and is saved', (t) async {
    SharedPreferences.setMockInitialValues({});
    final store = MicColorStore.instance;
    await store.choose(MicColorStore.options.first);
    await t.pumpWidget(const MaterialApp(home: MicColorScreen()));
    await t.pump();
    expect(find.text('Customise Mic'), findsOneWidget);

    await t.tap(find.bySemanticsLabel('Green mic colour'));
    await t.pump();
    expect(store.value.id, 'green');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('dock_mic.color.v1'), 'green');
    expect(find.text('Reset to Default'), findsOneWidget);

    await t.tap(find.text('Reset to Default'));
    await t.pump();
    expect(store.value.id, 'violet');
    expect(t.takeException(), isNull);
  });

  testWidgets('Done goes back to the page it was opened from', (t) async {
    SharedPreferences.setMockInitialValues({});
    await t.pumpWidget(MaterialApp(
      home: Builder(
        builder: (c) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(c).push(MaterialPageRoute<void>(builder: (_) => const MicColorScreen())),
            child: const Text('Home'),
          ),
        ),
      ),
    ));
    await t.tap(find.text('Home'));
    await t.pumpAndSettle();
    expect(find.text('Customise Mic'), findsOneWidget);
    await t.scrollUntilVisible(find.text('Done'), 200);
    await t.tap(find.text('Done'));
    await t.pumpAndSettle();
    expect(find.text('Customise Mic'), findsNothing);
    expect(find.text('Home'), findsOneWidget);
  });
}
