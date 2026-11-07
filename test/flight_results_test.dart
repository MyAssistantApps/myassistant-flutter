// Flight results (features/pricecompare/flight_results_screen.dart): the
// web answer is read into one row per flight with every site's fare, bad
// rows are dropped, and the results page draws without overflow.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myassistant/ai/types.dart';
import 'package:myassistant/features/pricecompare/flight_fares.dart';
import 'package:myassistant/features/pricecompare/flight_results_screen.dart';
import 'package:myassistant/features/pricecompare/flight_trip.dart';
import 'package:myassistant/features/pricecompare/price_models.dart';
import 'package:myassistant/features/pricecompare/price_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _answer = '''```json
{"flights": [
  {"airline": "IndiGo", "flightNo": "6E 2134", "from": "DEL", "to": "BOM", "depart": "19:30", "arrive": "21:35",
   "durationMin": 125, "stops": 0, "fares": [{"store": "IndiGo", "price": 5400}, {"store": "MakeMyTrip", "price": "₹5,410"}]},
  {"airline": "SpiceJet", "flightNo": "SG 8169", "depart": "5:40 AM", "arrive": "07:55", "stops": 0,
   "fares": [{"store": "Goibibo", "price": 5021, "url": "https://www.goibibo.com/x"}, {"store": "ixigo", "price": 5100},
             {"store": "Goibibo", "price": 5300}]},
  {"airline": "Air India", "flightNo": "AI 887", "depart": "23:10", "arrive": "01:30", "arriveDayOffset": 1, "stops": 1,
   "via": ["ixe"], "fares": [{"store": "Cleartrip", "price": 6100, "url": "http://insecure.example"}]},
  {"airline": "Nobody", "depart": "10:00", "arrive": "12:00", "fares": []},
  {"airline": "", "depart": "10:00", "arrive": "12:00", "fares": [{"store": "X", "price": 1}]}
 ],
 "nearbyDates": [{"date": "2026-11-09", "lowest": 3465}, {"date": "2026-11-10", "lowest": 0}],
 "advice": "Book the 05:40 SpiceJet."}
```''';

void main() {
  test('reads flights cheapest first, drops rows with no fare or airline', () {
    final f = FlightFares.parse(_answer)!;
    expect(f.flights.map((o) => o.airline), ['SpiceJet', 'IndiGo', 'Air India']);
    final sg = f.flights.first;
    expect(sg.depart, '05:40');
    expect(sg.minutes, 135); // worked out from the times
    expect(sg.fares.map((x) => x.store), ['Goibibo', 'ixigo']); // one fare per site
    expect(sg.best.url, 'https://www.goibibo.com/x');
    final ai = f.flights.last;
    expect(ai.minutes, 140); // across midnight
    expect(ai.stopsLabel, '1 stop · IXE');
    expect(ai.best.url, isEmpty); // not https
    expect(f.flights[1].fares.last.price, 5410);
    expect(f.nearby, {DateTime(2026, 11, 9): 3465});
    expect(f.fastest!.airline, 'IndiGo');
  });

  test('a cut-off answer keeps the flights that arrived whole', () {
    const cut = '{"flights": [{"airline": "IndiGo", "depart": "06:00", "arrive": "08:10", '
        '"fares": [{"store": "ixigo", "price": 4999}]}, {"airline": "Akasa Air", "depart": "09:00", "arr';
    final f = FlightFares.parse(cut)!;
    expect(f.flights.single.airline, 'IndiGo');
    expect(f.flights.single.price, 4999);
  });

  test('a flight with no arrival time is still shown, its fare being real', () {
    const a = '{"flights": [{"airline": "Air India", "depart": "21:00", "arrive": "", "durationMin": 0, '
        '"fares": [{"store": "ixigo.com", "price": 6643}]}]}';
    final o = FlightFares.parse(a)!.flights.single;
    expect(o.arrive, isEmpty);
    expect(o.minutes, 0);
    expect(o.durationLabel, isEmpty);
    expect(o.title, 'Air India · 21:00 · Non-stop');
  });

  test('no usable flight is no answer', () {
    expect(FlightFares.parse('{"flights": []}'), isNull);
    expect(FlightFares.parse('sorry'), isNull);
  });

  test('the flight prompt names the route and date and asks for JSON', () {
    final trip = FlightTrip(legs: [FlightLeg(from: airports[0], to: airports[1], date: DateTime(2026, 11, 8))]);
    final p = PriceService.flightPromptFor(trip, now: DateTime(2026, 11, 7));
    expect(p, contains('DEL to BOM on 2026-11-08'));
    expect(p, contains('"flights"'));
    expect(p, contains('"nearbyDates"'));
  });

  testWidgets('the results page draws the flights, labels and dates', (t) async {
    SharedPreferences.setMockInitialValues({});
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    PriceService.instance.ask = (_) async => (text: _answer, sources: const <SourceLink>[], suggestionsHtml: null);
    final date = DateTime.now().add(const Duration(days: 5));
    final trip = FlightTrip(legs: [FlightLeg(from: airports[0], to: airports[1], date: date)]);
    await t.pumpWidget(MaterialApp(
      builder: (c, child) =>
          MediaQuery(data: MediaQuery.of(c).copyWith(textScaler: const TextScaler.linear(1.2)), child: child!),
      home: FlightResultsScreen(trip: trip),
    ));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    expect(find.text('Cheapest'), findsOneWidget);
    expect(find.text('Set price alert', skipOffstage: false), findsOneWidget);
    expect(find.textContaining('BEST VALUE'), findsOneWidget);
    expect(find.text('FASTEST'), findsOneWidget);
    expect(find.text('Book'), findsWidgets);
    expect(find.text('1 more ›'), findsWidgets);
    expect(find.text(rupees(5021)), findsWidgets);
    expect(t.takeException(), isNull);
    // Opening "more" lists the other site's fare.
    await t.tap(find.text('1 more ›').first);
    await t.pumpAndSettle();
    expect(find.text('ixigo'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('a round trip gets a tab for each way and searches the return on tap', (t) async {
    SharedPreferences.setMockInitialValues({});
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    final asked = <String>[];
    PriceService.instance.ask = (p) async {
      asked.add(p);
      return (text: _answer, sources: const <SourceLink>[], suggestionsHtml: null);
    };
    final d = DateTime.now().add(const Duration(days: 5));
    final trip = FlightTrip(
      type: TripType.roundTrip,
      legs: [FlightLeg(from: airports[0], to: airports[1], date: d)],
      returnDate: d.add(const Duration(days: 4)),
    );
    await t.pumpWidget(MaterialApp(home: FlightResultsScreen(trip: trip)));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    expect(find.text('DEPART'), findsOneWidget);
    expect(find.text('RETURN'), findsOneWidget);
    expect(find.text('DEL → BOM'), findsOneWidget);
    expect(find.text('BOM → DEL'), findsOneWidget);
    expect(asked.single, contains('DEL to BOM'));
    await t.tap(find.text('BOM → DEL'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    expect(asked.last, contains('BOM to DEL'));
    expect(find.textContaining('Whole trip from'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  test('an empty flight list falls back to the plain comparison, read into cards', () async {
    SharedPreferences.setMockInitialValues({});
    var n = 0;
    PriceService.instance.ask = (p) async {
      n++;
      final text = n == 1
          ? '{"flights": [], "advice": "could not find"}'
          : '{"product": "BOM to DEL", "offers": ['
              '{"store": "Cleartrip", "price": 6643, "title": "Air India AI 887, 21:00 - 23:15, non-stop"},'
              '{"store": "ixigo", "price": 6700, "title": "Air India AI 887 21:00–23:15 nonstop"},'
              '{"store": "MakeMyTrip", "price": 5200, "title": "IndiGo 6E 2134 06:10-08:25, 1 stop"}]}';
      return (text: text, sources: const <SourceLink>[], suggestionsHtml: null);
    };
    final trip = FlightTrip(
        legs: [FlightLeg(from: airports[1], to: airports[0], date: DateTime.now().add(const Duration(days: 3)))]);
    final a = await PriceService.instance.compareFlights(trip);
    expect(n, 2);
    final f = a.fares.flights;
    expect(f.map((o) => o.airline), ['IndiGo', 'Air India']);
    expect(f.first.flightNo, '6E 2134');
    expect(f.first.stops, 1);
    expect(f.last.depart, '21:00');
    expect(f.last.arrive, '23:15');
    expect(f.last.fares.map((x) => x.store), ['Cleartrip', 'ixigo']);
  });
}
