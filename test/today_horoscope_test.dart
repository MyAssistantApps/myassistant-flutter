// TODAY'S HOROSCOPE (features/jyotish/today_horoscope.dart): the card's
// sign is the saved profile's rashi; the day's reading is the same all day
// and changes with the day.
import 'package:flutter_test/flutter_test.dart';
import 'package:myassistant/features/jyotish/jyotish_models.dart';
import 'package:myassistant/features/jyotish/jyotish_service.dart';
import 'package:myassistant/features/jyotish/today_horoscope.dart';

class _Svc extends JyotishService {
  _Svc(this.list, this.rashi);
  final List<SavedProfile>? list;
  final String rashi;

  @override
  Future<List<SavedProfile>?> profiles() async => list;

  @override
  Future<ChartResult?> chart(Birth birth, {DateTime? transitDate}) async => ChartResult.fromJson({
        'birth': birth.toJson(),
        'chart': {
          'timeKnown': true,
          'rashi': {'sign': 2, 'signName': rashi},
          'nakshatra': {'name': 'Ardra', 'pada': 1},
        },
      });
}

void main() {
  const birth = Birth(date: '2004-03-14', time: '06:30', place: 'Udupi', lat: 13.34, lng: 74.74, tz: 'Asia/Kolkata');

  test('signs: English or Vedic names, in the server order', () {
    expect(TodayHoroscope.signs, hasLength(12));
    expect(TodayHoroscope.byName('Gemini')?.id, 'gemini');
    expect(TodayHoroscope.byName('mithuna')?.name, 'Gemini');
    expect(TodayHoroscope.byName('Pisces'), same(TodayHoroscope.signs[11]));
    expect(TodayHoroscope.byName(''), isNull);
    expect(TodayHoroscope.byName('Ophiuchus'), isNull);
  });

  test('the reading: the same all day, different across days', () {
    final s = TodayHoroscope.byName('Leo')!;
    final morning = TodayHoroscope.today(s, DateTime(2026, 11, 23, 6));
    final night = TodayHoroscope.today(s, DateTime(2026, 11, 23, 23));
    expect(night.outlook, morning.outlook);
    expect(night.luckyColour, morning.luckyColour);
    expect(night.luckyNumber, morning.luckyNumber);
    expect(morning.luckyNumber, inInclusiveRange(1, 9));
    expect(TodayHoroscope.colours, contains(morning.luckyColour));
    final week = {for (var i = 0; i < 7; i++) TodayHoroscope.today(s, DateTime(2026, 11, 23 + i)).outlook};
    expect(week.length, greaterThan(1));
  });

  test("the card's sign: the most recent saved profile's rashi; none saved, none shown", () async {
    addTearDown(() => TodayHoroscope.sign.value = null);
    await TodayHoroscope.load(_Svc([const SavedProfile(id: 1, name: 'Asha', birth: birth)], 'Gemini'));
    expect(TodayHoroscope.sign.value?.id, 'gemini');
    expect(TodayHoroscope.owner, 'Asha');
    // Offline: the last sign stays.
    await TodayHoroscope.load(_Svc(null, 'Leo'));
    expect(TodayHoroscope.sign.value?.id, 'gemini');
    // Every profile deleted: back to asking for the birth details.
    await TodayHoroscope.load(_Svc(const [], 'Leo'));
    expect(TodayHoroscope.sign.value, isNull);
  });
}
