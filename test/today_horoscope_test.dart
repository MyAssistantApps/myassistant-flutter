// Today's horoscope carousel (features/jyotish/today_horoscope.dart): the
// server's set is read safely, the day turns at 4 AM India time, the set is
// kept for next time, and the carousel draws every sign's reading, colour
// and number — or says plainly when it could not load.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myassistant/features/jyotish/today_horoscope.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> serverSet(String day) => {
      'day': day,
      'signs': [
        {'id': 'aries', 'name': 'Aries', 'symbol': '♈', 'reading': 'Lead the discussion and set the agenda.', 'colour': 'Royal Blue', 'colourHex': '#4169E1', 'number': 8},
        {'id': 'taurus', 'name': 'Taurus', 'symbol': '♉', 'reading': 'A calm pace serves you best today.', 'colour': 'Coral', 'colourHex': '#FF7F50', 'number': '3'},
        {'id': '', 'reading': 'no sign'},
        {'id': 'gemini', 'reading': ''},
        'not a sign',
      ],
    };

void main() {
  final svc = TodayHoroscopeService.instance;
  tearDown(() {
    svc.fetch = null;
    svc.value = null;
    svc.failed.value = false;
  });

  test('reads the set safely', () {
    final h = DailyHoroscope.fromJson(serverSet('2026-11-24'))!;
    expect(h.signs.map((s) => s.id), ['aries', 'taurus']);
    expect(h.signs[1].number, 3);
    expect(h.signs[0].dot, const Color(0xFF4169E1));
    expect(h.dateLabel, '24 NOV');
    expect(DailyHoroscope.fromJson({'day': 'today', 'signs': []}), isNull);
    expect(DailyHoroscope.fromJson(null), isNull);
    final again = DailyHoroscope.fromJson(h.toJson())!;
    expect(again.signs.length, 2);
    expect(again.signs[0].reading, h.signs[0].reading);
  });

  test('the day turns at 4 AM India time', () {
    expect(horoscopeDayNow(DateTime.utc(2026, 11, 23, 22, 29)), '2026-11-23');
    expect(horoscopeDayNow(DateTime.utc(2026, 11, 23, 22, 31)), '2026-11-24');
  });

  testWidgets('draws each sign with its reading, colour and number', (t) async {
    SharedPreferences.setMockInitialValues({});
    svc.fetch = () async => serverSet(horoscopeDayNow());
    await t.pumpWidget(const MaterialApp(home: Scaffold(body: Center(child: SizedBox(width: 360, child: TodayHoroscopeCarousel())))));
    await t.pump();
    await t.pump();
    expect(find.text('Aries'), findsOneWidget);
    expect(find.text('Royal Blue'), findsOneWidget);
    expect(find.text('No. 8'), findsOneWidget);
    expect(find.text("TODAY'S HOROSCOPE"), findsWidgets);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('jyotish.today.v1'), contains('Royal Blue'));
    await t.drag(find.byType(PageView), const Offset(-400, 0));
    await t.pumpAndSettle();
    expect(find.text('Taurus'), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('says so when it cannot load', (t) async {
    SharedPreferences.setMockInitialValues({});
    svc.fetch = () async => null;
    await svc.refresh(force: true);
    await t.pumpWidget(const MaterialApp(home: Scaffold(body: TodayHoroscopeCarousel())));
    await t.pump();
    expect(find.textContaining('Unable to load'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });
}
