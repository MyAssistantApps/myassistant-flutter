// Hotel compare's own page (features/pricecompare/hotel_*): the checks
// before searching, the words the hotel price search is asked, and the page.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myassistant/features/pricecompare/hotel_search_screen.dart';
import 'package:myassistant/features/pricecompare/hotel_stay.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final d1 = DateTime(2026, 12, 12), d2 = DateTime(2026, 12, 14);

  test('asks for what is missing, then describes the stay', () {
    var s = const HotelStay();
    expect(s.problem(), 'Choose a city, area or hotel first.');
    s = s.copyWith(place: 'Goa');
    expect(s.problem(), 'Choose your check-in and check-out dates.');
    s = s.copyWith(checkIn: d2, checkOut: d1);
    expect(s.problem(), 'Check-out must be after check-in.');
    s = s.copyWith(checkIn: d1, checkOut: d2, rooms: 2, adults: 3, children: 1);
    expect(s.problem(), isNull);
    expect(s.nights, 2);
    final q = s.query();
    expect(q, contains('Goa.'));
    expect(q, contains('Check-in 12 Dec 2026'));
    expect(q, contains('check-out 14 Dec 2026'));
    expect(q, contains('2 nights'));
    expect(q, contains('2 rooms · 3 adults · 1 child'));
    expect(q, isNot(contains('star')));
  });

  test('stars, extras and the budget go into the search', () {
    final s = HotelStay(
      place: 'Udaipur',
      checkIn: d1,
      checkOut: d1.add(const Duration(days: 1)),
      stars: HotelStars.four,
      extras: const {HotelExtra.freeCancellation, HotelExtra.breakfast},
      budget: 6000,
    );
    final q = s.query();
    expect(q, contains('1 night.'));
    expect(q, contains('4-star or above'));
    expect(q, contains('free cancellation, breakfast included'));
    expect(q, contains('a night'));
    expect(s.copyWith(clearBudget: true).budget, isNull);
  });

  test('each room needs an adult; 30 nights at most', () {
    final s = HotelStay(place: 'Goa', checkIn: d1, checkOut: d2);
    expect(s.copyWith(rooms: 3, adults: 2).problem(), 'Each room needs at least one adult.');
    expect(s.copyWith(checkOut: d1.add(const Duration(days: 31))).problem(), contains('30 nights'));
  });

  testWidgets('the page shows where, when, who and the filters', (t) async {
    SharedPreferences.setMockInitialValues({});
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(const MaterialApp(home: HotelSearchScreen()));
    await t.pump();
    for (final label in [
      'Hotel compare',
      'WHERE',
      'CHECK-IN',
      'CHECK-OUT',
      '1 night',
      'ROOMS & GUESTS',
      'POPULAR PLACES'
    ]) {
      expect(find.text(label), findsWidgets, reason: label);
    }
    // A popular place fills Where.
    await t.tap(find.text('Goa'));
    await t.pump();
    expect(find.widgetWithText(TextField, 'Goa'), findsOneWidget);
    final page = find.byType(ListView).first;
    await t.dragUntilVisible(find.text('Search hotels'), page, const Offset(0, -300));
    expect(find.text('Free cancellation'), findsOneWidget);
    expect(find.text('4★ & up'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
