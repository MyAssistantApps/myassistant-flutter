import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myassistant/features/home/horoscope_card.dart';
import 'package:myassistant/services/horoscope.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('twelve signs, each found by id', () {
    expect(Horoscope.signs.length, 12);
    for (final s in Horoscope.signs) {
      expect(Horoscope.byId(s.id), same(s));
    }
    expect(Horoscope.byId('nope'), isNull);
  });

  test('the same sign reads the same all day and differently another day', () {
    final leo = Horoscope.byId('leo')!;
    final a = Horoscope.today(leo, DateTime(2026, 11, 15, 8));
    final b = Horoscope.today(leo, DateTime(2026, 11, 15, 22));
    expect(a.outlook, b.outlook);
    expect(a.luckyNumber, b.luckyNumber);
    final week = {
      for (var d = 15; d < 22; d++) Horoscope.today(leo, DateTime(2026, 11, d)).outlook
    };
    expect(week.length, greaterThan(1));
    expect(a.luckyNumber, inInclusiveRange(1, 9));
  });

  for (final id in [null, 'sagittarius']) {
    testWidgets('the Home card lays out on a 360 px phone (sign: $id)', (t) async {
      SharedPreferences.setMockInitialValues({});
      t.view.physicalSize = const Size(1080, 2400);
      t.view.devicePixelRatio = 3;
      addTearDown(t.view.reset);
      await t.pumpWidget(const MaterialApp(
          home: Scaffold(body: Padding(padding: EdgeInsets.all(16), child: HoroscopeCard()))));
      await t.pump();
      await Horoscope.save(Horoscope.byId(id));
      await t.pump();
      expect(find.text("TODAY'S HOROSCOPE"), findsOneWidget);
      if (id != null) expect(find.text('Sagittarius'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }
}
