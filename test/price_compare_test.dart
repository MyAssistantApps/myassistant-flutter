// Price compare (features/pricecompare): the web answer is read safely,
// sorted cheapest first, links only go to the store's own site, and the
// Home section draws.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myassistant/ai/types.dart';
import 'package:myassistant/features/pricecompare/price_compare_section.dart';
import 'package:myassistant/features/pricecompare/price_models.dart';
import 'package:myassistant/features/pricecompare/price_result_screen.dart';
import 'package:myassistant/features/pricecompare/price_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const answer = '''Here you go:
```json
{"product": "Apple iPhone 16 (128 GB)",
 "offers": [
   {"store": "Flipkart", "price": "₹74,999", "mrp": 79900, "rating": 4.6},
   {"store": "Amazon.in", "price": 72990, "url": "https://evil.example.com/x"},
   {"store": "Croma", "price": 0},
   {"store": "", "price": 100}
 ],
 "bestPick": "Amazon", "verdict": "buy", "advice": "Lowest in weeks.",
 "history": {"lowest": 69999, "highest": 79900, "average": 74500},
 "deals": [{"store": "Flipkart", "text": "10% off with HDFC cards", "code": ""}, {"text": ""}]}
```''';

  test('reads the answer: valid offers only, cheapest first', () {
    final r = PriceResult.parse(answer, category: PriceCategory.shopping, query: 'iphone 16')!;
    expect(r.product, 'Apple iPhone 16 (128 GB)');
    expect(r.offers.map((o) => o.store), ['Amazon.in', 'Flipkart']);
    expect(r.lowest!.price, 72990);
    expect(r.saving, 2009);
    expect(r.offers[1].offPercent, 6);
    expect(r.verdict, PriceVerdict.buy);
    expect(r.history.lowest, 69999);
    expect(r.deals, hasLength(1));
  });

  test('no prices, no result', () {
    expect(PriceResult.parse('Sorry, nothing found.', category: PriceCategory.shopping, query: 'x'), isNull);
    expect(PriceResult.parse('{"offers": []}', category: PriceCategory.shopping, query: 'x'), isNull);
  });

  test('a link opens only on the store\'s own site', () {
    final amazon = PriceStores.named('Amazon.in', PriceStores.shopping)!;
    expect(amazon.name, 'Amazon');
    expect(amazon.owns('https://www.amazon.in/dp/B0X'), isTrue);
    expect(amazon.owns('https://evil.example.com/x'), isFalse);
    expect(amazon.owns('http://www.amazon.in/dp/B0X'), isFalse);
    expect(amazon.urlFor('iphone 16'), 'https://www.amazon.in/s?k=iphone%2016');
  });

  test('rupees in Indian grouping', () {
    expect(rupees(72990), '₹72,990');
    expect(rupees(129999), '₹1,29,999');
    expect(rupees(94.72), '₹94.72');
    expect(rupees(450), '₹450');
  });

  test('a watch keeps one point a day', () {
    var w = const PriceWatch(id: 'a', category: PriceCategory.shopping, query: 'q', product: 'Q', target: 100);
    w = w.withPoint(PricePoint(DateTime(2026, 11, 1, 9), 120));
    w = w.withPoint(PricePoint(DateTime(2026, 11, 1, 18), 110));
    w = w.withPoint(PricePoint(DateTime(2026, 11, 2, 9), 99));
    expect(w.points.map((p) => p.price), [110, 99]);
    expect(w.reached, isTrue);
    expect(PriceWatch.fromJson(w.toJson())!.points, hasLength(2));
  });

  test('compare remembers it and an alert records its price', () async {
    SharedPreferences.setMockInitialValues({});
    final svc = PriceService.instance;
    svc.ask = (_) async => (text: answer, sources: const <SourceLink>[], suggestionsHtml: null);
    final a = await svc.compare(PriceCategory.shopping, 'iphone 16');
    expect(svc.recent.first.product, a.result.product);
    svc.watch(a.result, 70000);
    expect(svc.watchFor(PriceCategory.shopping, 'iPhone 16')!.last, 72990);
  });

  test('every category asks for JSON', () {
    for (final c in PriceCategory.values) {
      final p = PriceService.promptFor(c, 'x', now: DateTime(2026, 11, 4));
      expect(p, contains('"offers"'), reason: c.name);
    }
  });

  testWidgets('the Home section draws its hero, search and Product compare only', (t) async {
    SharedPreferences.setMockInitialValues({});
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(
      builder: (c, child) =>
          MediaQuery(data: MediaQuery.of(c).copyWith(textScaler: const TextScaler.linear(1.3)), child: child!),
      home: Scaffold(body: ListView(children: [PriceCompareSection(onOpen: (_) {})])),
    ));
    await t.pump();
    expect(find.text('Price compare'), findsOneWidget);
    expect(find.text('Same product.\nLower price.'), findsOneWidget);
    expect(find.text('Search or paste a link'), findsOneWidget);
    expect(find.text('Product compare'), findsOneWidget);
    // Owner, 2026-11-14: flights, hotels, rides and grocery are gone.
    for (final title in ['Flights', 'Hotels', 'Rides', 'Grocery']) {
      expect(find.text(title), findsNothing, reason: title);
    }
    // No overflow at a large text size either (the tiles overflowed once).
    expect(t.takeException(), isNull);
  });

  testWidgets('the results page shows the best price, the verdict, every store and the scale', (t) async {
    SharedPreferences.setMockInitialValues({});
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    PriceService.instance.ask = (_) async => (
          text: '{"product": "Apple iPhone 16 (128 GB)", "verdict": "buy", "bestPick": "Flipkart", '
              '"advice": "Flipkart is cheapest today.", '
              '"offers": [{"store": "Flipkart", "price": 72990, "mrp": 79900, "rating": 4.6}, '
              '{"store": "Amazon.in", "price": 74990}, {"store": "Croma", "price": 79900, "inStock": false}], '
              '"history": {"lowest": 69999, "highest": 79900, "average": 75000}, '
              '"deals": [{"store": "Flipkart", "text": "10% off with HDFC cards", "code": "HDFC10"}]}',
          sources: const <SourceLink>[],
          suggestionsHtml: null,
        );
    await t.pumpWidget(MaterialApp(
      builder: (c, child) =>
          MediaQuery(data: MediaQuery.of(c).copyWith(textScaler: const TextScaler.linear(1.2)), child: child!),
      home: const PriceResultScreen(category: PriceCategory.shopping, query: 'iphone 16'),
    ));
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));
    expect(find.text('BEST PRICE'), findsOneWidget);
    expect(find.text('BUY NOW'), findsOneWidget);
    expect(find.textContaining('You save'), findsOneWidget);
    await t.scrollUntilVisible(find.text('Price at each store'), 300);
    expect(find.text('CHEAPEST'), findsOneWidget);
    expect(find.text('+₹2,000 more'), findsOneWidget);
    await t.scrollUntilVisible(find.text('NOW'), 300);
    expect(find.textContaining('below its usual price'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  test('a history of zeros is no history', () {
    expect(PriceRange.fromJson({'lowest': 0, 'highest': 0, 'average': 0}).isEmpty, isTrue);
    expect(PriceRange.fromJson({'lowest': '₹699', 'average': 0}).lowest, 699);
  });

  group('each kind has its own page', () {
    Future<void> show(WidgetTester t, PriceCategory c, String answer) async {
      SharedPreferences.setMockInitialValues({});
      t.view.physicalSize = const Size(1080, 2400);
      t.view.devicePixelRatio = 3;
      addTearDown(t.view.reset);
      PriceService.instance.ask = (_) async => (text: answer, sources: const <SourceLink>[], suggestionsHtml: null);
      await t.pumpWidget(MaterialApp(
        builder: (ctx, child) =>
            MediaQuery(data: MediaQuery.of(ctx).copyWith(textScaler: const TextScaler.linear(1.2)), child: child!),
        home: PriceResultScreen(category: c, query: 'x'),
      ));
      await t.pump();
      await t.pump(const Duration(milliseconds: 600));
    }

    Future<void> see(WidgetTester t, Finder f) async {
      await t.scrollUntilVisible(f, 250, scrollable: find.byType(Scrollable).first);
      expect(f, findsWidgets);
      expect(t.takeException(), isNull);
    }

    testWidgets('product: specs, highlights and each store\'s delivery', (t) async {
      await show(t, PriceCategory.shopping, '''{"product": "Samsung Galaxy S24 (8/256)", "verdict": "buy",
        "offers": [{"store": "Amazon", "price": 64999, "info": {"delivery": "Tomorrow", "emi": "No-cost EMI from ₹5,417/mo", "exchange": "Up to ₹10,000 off", "warranty": "1 year", "seller": "Appario Retail"}},
                   {"store": "Flipkart", "price": 65999, "info": {"delivery": "by 12 Nov"}}],
        "facts": {"brand": "Samsung", "rating": 4.4, "reviews": 25400, "highlights": ["Galaxy AI", "50 MP camera"],
                  "specs": [{"name": "Display", "value": "6.2-inch Dynamic AMOLED 2X, 120 Hz"}, {"name": "Processor", "value": "Exynos 2400"}, {"name": "Battery", "value": "4000 mAh"}]}}''');
      await see(t, find.text('KEY SPECIFICATIONS'));
      await see(t, find.text('Exynos 2400'));
      await see(t, find.text('Sold by Appario Retail'));
    });

    testWidgets('hotel: stay, stars, rating word and amenities', (t) async {
      await show(t, PriceCategory.hotels, '''{"product": "Hotels in Goa", "verdict": "okay",
        "offers": [{"store": "Booking.com", "price": 4200, "rating": 4.6, "title": "Taj Fort Aguada",
                    "info": {"hotel": "Taj Fort Aguada Resort & Spa", "stars": 5, "reviews": 3200, "area": "Candolim", "distance": "200 m from the beach", "room": "Deluxe Sea View", "freeCancellation": true, "breakfast": true, "amenities": ["Pool", "Spa", "Free Wi-Fi"], "total": 8400}},
                   {"store": "Agoda", "price": 2900, "rating": 4.1, "info": {"hotel": "Lemon Tree Candolim", "stars": 3}}],
        "facts": {"city": "Goa", "checkIn": "Sat 15 Nov", "checkOut": "Mon 17 Nov", "nights": 2, "guests": 2, "averagePerNight": 3550}}''');
      expect(find.text('BEST DEAL · PER NIGHT'), findsOneWidget);
      await see(t, find.text('avg / night'));
      await see(t, find.text('Excellent'));
      await see(t, find.text('Free cancellation'));
      await see(t, find.text('₹8,400 for the stay'));
    });

    testWidgets('ride: route, quick picks and fares by type', (t) async {
      await show(t, PriceCategory.cabs, '''{"product": "Indiranagar to Airport", "verdict": "okay",
        "offers": [{"store": "Uber", "price": 980, "title": "Uber Go", "info": {"ride": "Mini", "pickupMin": 4, "seats": 4}},
                   {"store": "Ola", "price": 1250, "title": "Ola Prime SUV", "info": {"ride": "SUV", "pickupMin": 9, "seats": 6, "surge": true}},
                   {"store": "Rapido", "price": 420, "title": "Bike", "info": {"ride": "Bike", "pickupMin": 2, "seats": 1}}],
        "facts": {"from": "Indiranagar", "to": "Kempegowda Airport", "distanceKm": 38.5, "durationMin": 75, "traffic": "heavy"}}''');
      expect(find.text('PICKUP'), findsOneWidget);
      expect(find.text('Heavy traffic'), findsOneWidget);
      await see(t, find.text('FASTEST PICKUP'));
      await see(t, find.text('MOST ROOM'));
      await see(t, find.text('SURGE'));
    });

    testWidgets('grocery: delivery race, per kg and total to pay', (t) async {
      await show(t, PriceCategory.grocery, '''{"product": "Amul Butter 500 g", "verdict": "buy",
        "offers": [{"store": "Blinkit", "price": 285, "info": {"pack": "500 g", "unitPrice": 570, "unit": "kg", "deliveryMin": 9, "deliveryFee": 0}},
                   {"store": "Zepto", "price": 279, "info": {"pack": "500 g", "unitPrice": 558, "unit": "kg", "deliveryMin": 12, "deliveryFee": 25}}],
        "facts": {"tip": "The 2 x 500 g combo is ₹20 cheaper on Blinkit."}}''');
      await see(t, find.text('Delivery race'));
      await see(t, find.text('⚡ 9 min'));
      await see(t, find.text('CHEAPEST TOTAL'));
      await see(t, find.text('BEST PER KG'));
    });
  });
}
