// Real hotel prices (2026-11-24): the server's Google Hotels answer, parsed
// defensively; hotels with no price are dropped, never filled in.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myassistant/features/home/hotel_prices.dart';
import 'package:myassistant/features/home/hotels_screen.dart';

void main() {
  test('hotels are read cheapest first, with each site\'s price', () {
    final l = HotelHit.listFrom({
      'ok': true,
      'hotels': [
        {
          'name': 'Sea Breeze Resort', 'stars': 4, 'rating': 4.3, 'reviews': 1820, 'pricePerNight': 5400,
          'image': 'https://x/y.jpg', 'link': 'http://not-safe',
          'sites': [{'source': 'Agoda', 'pricePerNight': 5600}, {'source': 'Booking.com', 'pricePerNight': 5400}]
        },
        {'name': 'Budget Inn', 'pricePerNight': 1900},
        {'name': 'No Price Villa'},
        'junk',
      ]
    })!;
    expect(l.map((h) => h.name), ['Budget Inn', 'Sea Breeze Resort']);
    final s = l[1];
    expect(s.stars, 4);
    expect(s.cheapestSite, 'Booking.com');
    expect(s.link, ''); // only https links are kept
    expect(s.image, 'https://x/y.jpg');
  });

  test('a server without hotel search, or an error, gives no list', () async {
    expect(HotelHit.listFrom({'ok': false, 'configured': false}), isNull);
    expect(HotelHit.listFrom(null), isNull);
    HotelPrices.fetch = (_) async => {'ok': false, 'configured': false};
    final r = await HotelPrices.search(place: 'Goa', checkIn: '2026-12-01', checkOut: '2026-12-03', adults: 2);
    expect(r.hotels, isNull);
    expect(r.error, contains('not available yet'));
    String? asked;
    HotelPrices.fetch = (p) async {
      asked = p;
      return {'ok': true, 'hotels': <Object>[]};
    };
    final ok = await HotelPrices.search(place: 'North Goa', checkIn: '2026-12-01', checkOut: '2026-12-03', adults: 3);
    expect(ok.hotels, isEmpty);
    expect(asked, contains('q=North+Goa'));
    expect(asked, contains('adults=3'));
  });

  testWidgets('Compare Prices lists live hotels on the Hotels screen', (t) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    HotelPrices.fetch = (_) async => {
          'ok': true,
          'hotels': [
            {'name': 'Sea Breeze Resort', 'stars': 4, 'rating': 4.3, 'pricePerNight': 5400, 'total': 10800,
             'sites': [{'source': 'Booking.com', 'pricePerNight': 5400}]},
            {'name': 'Budget Inn', 'pricePerNight': 1900},
          ]
        };
    await t.pumpWidget(const MaterialApp(home: HotelsScreen()));
    await t.pump();
    await t.tap(find.text('Compare Prices'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));
    expect(find.text('Live · Google Hotels'), findsOneWidget);
    expect(find.text('Budget Inn'), findsOneWidget);
    expect(find.text('LOWEST PRICE'), findsOneWidget);
    expect(find.text('₹1,900'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
