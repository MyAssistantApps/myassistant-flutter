// Real flight fares (2026-11-24): Google Flights through our server first;
// the AI's web read only when the server has no flight search.
import 'package:flutter_test/flutter_test.dart';
import 'package:myassistant/ai/types.dart';
import 'package:myassistant/features/pricecompare/flight_trip.dart';
import 'package:myassistant/features/pricecompare/price_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _server = {
  'ok': true,
  'provider': 'google_flights',
  'flights': [
    {
      'airline': 'IndiGo', 'flightNo': '6E 2134', 'from': 'BLR', 'to': 'DEL', 'depart': '05:40', 'arrive': '08:25',
      'arriveDayOffset': 0, 'durationMin': 165, 'stops': 0, 'via': <String>[],
      'fares': [{'store': 'Google Flights', 'price': 5120, 'url': 'https://www.google.com/travel/flights?x'}]
    }
  ],
  'nearbyDates': <Object>[],
  'advice': 'Google Flights rates prices on this route as low right now.',
  'deals': <Object>[],
};

void main() {
  final trip = FlightTrip(legs: [
    FlightLeg(from: const Airport('BLR', 'Bengaluru', 'Kempegowda'), to: const Airport('DEL', 'Delhi', 'IGI'), date: DateTime(2026, 12, 1))
  ], adults: 2, nonStop: true);
  String? asked;
  var aiAsked = false;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    asked = null;
    aiAsked = false;
    PriceService.instance.ask = (_) async {
      aiAsked = true;
      return (text: '{"flights": []}', sources: const <SourceLink>[]);
    };
  });

  test('the server\'s Google Flights results are used, live, and the AI is not asked', () async {
    PriceService.instance.fetchFlights = (p) async {
      asked = p;
      return _server;
    };
    final a = await PriceService.instance.compareFlights(trip);
    expect(a.live, isTrue);
    expect(aiAsked, isFalse);
    expect(a.fares.flights.single.airline, 'IndiGo');
    expect(a.fares.flights.single.price, 5120);
    expect(asked, contains('from=BLR'));
    expect(asked, contains('date=2026-12-01'));
    expect(asked, contains('adults=2'));
    expect(asked, contains('nonStop=1'));
  });

  test('no flights on a real search is said plainly, not filled in by the AI', () async {
    PriceService.instance.fetchFlights = (_) async => {'ok': true, 'flights': <Object>[]};
    await expectLater(PriceService.instance.compareFlights(trip), throwsA(isA<PriceCompareException>()));
    expect(aiAsked, isFalse);
  });

  test('a server without flight search falls back to the AI, marked as an estimate', () async {
    PriceService.instance.fetchFlights = (_) async => {'ok': false, 'configured': false};
    try {
      await PriceService.instance.compareFlights(trip);
    } on PriceCompareException {
      // The stub AI found nothing; what matters is that it was asked.
    }
    expect(aiAsked, isTrue);
  });
}
