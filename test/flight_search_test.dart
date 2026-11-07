import 'dart:io';

// Flight compare's own page (features/pricecompare/flight_*): trip types,
// the checks before searching, and the words the fare search is asked.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myassistant/features/pricecompare/airline_widgets.dart';
import 'package:myassistant/features/pricecompare/airlines.dart';
import 'package:myassistant/features/pricecompare/flight_search_screen.dart';
import 'package:myassistant/features/pricecompare/flight_trip.dart';

void main() {
  Airport ap(String code) => airports.firstWhere((a) => a.code == code);
  final d1 = DateTime(2026, 11, 20), d2 = DateTime(2026, 11, 25);

  test('one-way: asks for what is missing, then describes the trip', () {
    var t = const FlightTrip();
    expect(t.problem(), 'Choose where you fly from');
    t = t.copyWith(legs: [FlightLeg(from: ap('BLR'), to: ap('BLR'), date: d1)]);
    expect(t.problem(), 'From and To must be different');
    t = t.copyWith(legs: [FlightLeg(from: ap('BLR'), to: ap('DEL'), date: d1)], adults: 2, infants: 1, nonStop: true);
    expect(t.problem(), isNull);
    expect(t.route, 'BLR → DEL');
    expect(t.describe(), contains('One-way flight from Bengaluru (BLR) to New Delhi (DEL), departing 20 Nov 2026'));
    expect(t.describe(), contains('2 adults, 1 infant'));
    expect(t.describe(), contains('Non-stop flights only'));
  });

  test('round-trip needs a return on or after the departure', () {
    var t = FlightTrip(legs: [FlightLeg(from: ap('BOM'), to: ap('GOI'), date: d2)]).asType(TripType.roundTrip);
    expect(t.problem(), 'Choose the return date');
    expect(t.copyWith(returnDate: d1).problem(), "The return can't be before the departure");
    t = t.copyWith(returnDate: DateTime(2026, 11, 28), cabin: CabinClass.business, fare: SpecialFare.student);
    expect(t.problem(), isNull);
    expect(t.route, 'BOM ⇄ GOI');
    expect(t.describe(), allOf(contains('returning 28 Nov 2026'), contains('Business'), contains('Student fare')));
  });

  test('multi-city: the next flight starts where the last lands, in order', () {
    var t = FlightTrip(legs: [FlightLeg(from: ap('DEL'), to: ap('DXB'), date: d1)]).asType(TripType.multiCity);
    expect(t.legs, hasLength(2));
    expect(t.legs[1].from!.code, 'DXB');
    t = t.copyWith(legs: [t.legs[0], t.legs[1].copyWith(to: ap('LHR'), date: DateTime(2026, 11, 18))]);
    expect(t.problem(), "Flight 2 can't leave before flight 1");
    t = t.copyWith(legs: [t.legs[0], t.legs[1].copyWith(date: d2)]);
    expect(t.problem(), isNull);
    expect(t.route, 'DEL → DXB → LHR');
    expect(t.describe(), contains('Multi-city flight with 2 flights'));
    expect(t.asType(TripType.oneWay).legs, hasLength(1));
  });

  test('travellers: an adult per infant, nine at most', () {
    final t = FlightTrip(legs: [FlightLeg(from: ap('BLR'), to: ap('DEL'), date: d1)]);
    expect(t.copyWith(infants: 2).problem(), 'Each infant needs an adult');
    expect(t.copyWith(adults: 6, children: 4).problem(), 'Up to 9 travellers per booking');
  });

  test('airports are found by city, code or name', () {
    expect(airports.where((a) => a.matches('bom')).first.city, 'Mumbai');
    expect(airports.where((a) => a.matches('kempegowda')).single.code, 'BLR');
    expect(airports.where((a) => a.matches('mang')).first.code, 'IXE');
  });

  testWidgets('the page shows the trip types and switches to multi-city', (t) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(const MaterialApp(home: FlightSearchScreen()));
    for (final label in [
      'One-way',
      'Round-trip',
      'Multi-city',
      'POPULAR ROUTES',
      'FROM',
      'TO',
      'DEPARTURE',
      'RETURN'
    ]) {
      expect(find.text(label), findsWidgets, reason: label);
    }
    final page = find.byType(ListView).first;
    await t.dragUntilVisible(find.text('PREFERRED AIRLINE'), page, const Offset(0, -300));
    expect(find.text('Student'), findsOneWidget);
    expect(find.text('Any airline'), findsOneWidget);
    await t.dragUntilVisible(find.text('Multi-city'), page, const Offset(0, 300));
    await t.tap(find.text('Multi-city'));
    await t.pumpAndSettle();
    expect(find.text('FLIGHT 1'), findsOneWidget);
    expect(find.text('FLIGHT 2'), findsOneWidget);
    expect(find.text('RETURN'), findsNothing);
    await t.dragUntilVisible(find.text('Search flights'), find.byType(ListView).first, const Offset(0, -300));
    await t.tap(find.text('Search flights'));
    await t.pump();
    expect(find.text('Choose where you fly from for flight 1'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  test('every airline has its photo, facts and a credit; routes use known airports', () {
    expect(airlines.map((a) => a.name), containsAll(['IndiGo', 'Air India', 'Akasa Air', 'Emirates']));
    for (final a in airlines) {
      expect(a.website, startsWith('https://'), reason: a.name);
      expect(a.hubs, isNotEmpty, reason: a.name);
      expect(a.highlights, isNotEmpty, reason: a.name);
      expect(a.credit, contains(' · '), reason: a.name);
      for (final v in [a.plane.seats, a.plane.engines, a.plane.length, a.plane.wingspan, a.plane.range, a.plane.fact]) {
        expect(v, isNotEmpty, reason: a.name);
      }
    }
    for (final r in popularRoutes) {
      expect(r.fromAirport.code, r.from);
      expect(r.toAirport.code, r.to);
    }
  });

  test('a preferred airline is asked for first', () {
    final t = FlightTrip(legs: [FlightLeg(from: ap('BLR'), to: ap('DEL'), date: d1)], airline: 'IndiGo');
    expect(t.describe(), contains('Preferred airline: IndiGo'));
    expect(t.copyWith(airline: '').describe(), isNot(contains('Preferred airline')));
  });

  testWidgets('the airline banner slides on its own and opens the airlines page', (t) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    int? opened;
    await t.pumpWidget(MaterialApp(home: Scaffold(body: AirlineCarousel(onOpen: (i) => opened = i))));
    expect(find.text('IndiGo'), findsOneWidget);
    await t.pump(const Duration(seconds: 4));
    await t.pumpAndSettle();
    expect(find.text('Air India'), findsOneWidget);
    await t.tap(find.text('Air India'));
    expect(opened, 1);
  });

  testWidgets('the airlines page shows facts and returns the chosen airline', (t) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    String? chosen;
    await t.pumpWidget(MaterialApp(
      home: Builder(
        builder: (c) => TextButton(
          onPressed: () async => chosen =
              await Navigator.of(c).push<String>(MaterialPageRoute(builder: (_) => const AirlinesScreen(initial: 3))),
          child: const Text('open'),
        ),
      ),
    ));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    expect(find.text('Akasa Air'), findsOneWidget);
    expect(find.text('GOOD TO KNOW'), findsOneWidget);
    await t.dragUntilVisible(find.text('ABOUT THIS AIRCRAFT'), find.byType(ListView).first, const Offset(0, -300));
    expect(find.text('189, all economy'), findsOneWidget);
    expect(find.text('2 × CFM LEAP-1B'), findsOneWidget);
    await t.tap(find.text('Compare Akasa Air fares'));
    await t.pumpAndSettle();
    expect(chosen, 'Akasa Air');
    expect(t.takeException(), isNull);
  });

  test('every airline has more photos, each on disk and credited', () {
    for (final a in airlines) {
      expect(a.gallery.length, greaterThanOrEqualTo(3), reason: a.name);
      for (final p in a.photos) {
        expect(File(p.path).existsSync(), isTrue, reason: p.path);
        expect(p.credit, contains(' · '), reason: p.path);
      }
    }
    expect(airlineCredits.length, airlines.fold<int>(0, (n, a) => n + a.photos.length));
  });

  testWidgets('tapping a photo in the strip shows it with its caption', (t) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(const MaterialApp(home: AirlinesScreen()));
    await t.pumpAndSettle();
    final second = airlines.first.gallery.first;
    expect(find.text(second.caption), findsNothing);
    await t.tap(find.bySemanticsLabel(RegExp('IndiGo photo 2')));
    await t.pumpAndSettle();
    expect(find.text(second.caption), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('a popular route fills From and To', (t) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(const MaterialApp(home: FlightSearchScreen()));
    await t.tap(find.text('Bengaluru – New Delhi'));
    await t.pumpAndSettle();
    // The date picker opens for a trip with no date yet.
    expect(find.byType(DatePickerDialog), findsOneWidget);
    await t.tap(find.text('Cancel'));
    await t.pumpAndSettle();
    expect(find.text('BLR · Kempegowda International'), findsOneWidget);
    expect(find.text('DEL · Indira Gandhi International'), findsOneWidget);
  });
}
