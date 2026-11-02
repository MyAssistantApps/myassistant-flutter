// The neuron orb on the talking page (lib/widgets/neuron_orb.dart): every
// mood paints without errors, the colours follow the time of day, and a
// paused or hidden orb asks for no frames.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myassistant/widgets/neuron_orb.dart';
import 'package:myassistant/widgets/voice_orb.dart' show OrbMood;

Widget _host(OrbMood mood, {bool active = true, double level = 0.6}) =>
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 400,
          height: 400,
          child: NeuronOrb(
            radius: 100,
            mood: mood,
            levelListenable: ValueNotifier(level),
            speakerLevel: () => level,
            active: active,
            clock: () => DateTime(2026, 11, 2, 20, 30),
          ),
        ),
      ),
    );

void main() {
  testWidgets('every mood paints and moves without errors', (tester) async {
    for (final m in OrbMood.values) {
      await tester.pumpWidget(_host(m));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }
      expect(tester.takeException(), isNull, reason: m.name);
    }
  });

  testWidgets('paused or hidden: no frames scheduled', (tester) async {
    await tester.pumpWidget(_host(OrbMood.paused));
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pumpWidget(_host(OrbMood.speaking, active: false));
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('the sky behind it paints in every mood', (tester) async {
    for (final m in OrbMood.values) {
      await tester.pumpWidget(MaterialApp(
        home: NeuronSky(
          mood: m,
          levelListenable: ValueNotifier(0.7),
          speakerLevel: () => 0.7,
          clock: () => DateTime(2026, 11, 2, 9),
        ),
      ));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 400));
      }
      expect(tester.takeException(), isNull, reason: m.name);
    }
  });

  test('colours change with the time of day', () {
    final night = NeuronPalette.at(DateTime(2026, 1, 1, 2));
    final morning = NeuronPalette.at(DateTime(2026, 1, 1, 11));
    final sunset = NeuronPalette.at(DateTime(2026, 1, 1, 18, 30));
    final evening = NeuronPalette.at(DateTime(2026, 1, 1, 21));
    expect({night, morning, sunset, evening}.length, 4);
    // A smooth blend in between, never a jump.
    final a = NeuronPalette.at(DateTime(2026, 1, 1, 9, 0));
    final b = NeuronPalette.at(DateTime(2026, 1, 1, 9, 1));
    expect((a.a.r - b.a.r).abs(), lessThan(0.02));
  });
}
