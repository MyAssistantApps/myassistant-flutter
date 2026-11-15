import 'package:flutter_test/flutter_test.dart';
import 'package:myassistant/services/horoscope.dart';

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
}
