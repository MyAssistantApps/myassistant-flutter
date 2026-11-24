// Product compare (features/pricecompare/product_screens.dart): the results
// grid and the product page draw from the web answer without overflowing.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myassistant/ai/types.dart';
import 'package:myassistant/features/pricecompare/price_models.dart';
import 'package:myassistant/features/pricecompare/price_compare_screen.dart';
import 'package:myassistant/features/pricecompare/price_service.dart';
import 'package:myassistant/features/pricecompare/product_screens.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _grid = '''{"products": [
  {"name": "Apple iPhone 16 128 GB: 5G Mobile Phone with Camera Control", "price": 76999, "mrp": 79900, "store": "Amazon", "rating": 4.5, "reviews": 2850},
  {"name": "Apple iPhone 16 Plus 128 GB", "price": 86999, "store": "Flipkart", "rating": 4.6},
  {"name": "Apple iPhone 16 Pro 256 GB", "price": 129900, "store": "Croma"}]}''';

const _page =
    '''{"product": "Google Pixel 10 (Frost, 256 GB) (12 GB RAM)", "verdict": "buy", "advice": "Flipkart is cheapest today.",
  "offers": [{"store": "Flipkart", "price": 74999, "mrp": 79999, "info": {"delivery": "Tomorrow"}},
             {"store": "JioMart", "price": 76999, "mrp": 79999}, {"store": "Croma", "price": 79999}],
  "history": {"lowest": 74749, "highest": 85000, "average": 76518},
  "deals": [{"store": "Flipkart", "text": "10% off with SBI cards", "code": "SBI10"}],
  "facts": {"brand": "Google", "rating": 4.5, "reviews": 3880, "highlights": ["Tensor G5"],
            "specs": [{"name": "Display", "value": "6.3-inch Actua"}],
            "similar": [{"name": "HMD Vibe2 5G (Cosmic Lavender, 128 GB)", "price": 11999, "mrp": 15704, "store": "Flipkart", "rating": 4.4, "reviews": 10930}]}}''';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PriceService.instance.ask = (p) async =>
        (text: p.contains('"products"') ? _grid : _page, sources: const <SourceLink>[]);
  });

  Future<void> big(WidgetTester t, Widget w) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(
      builder: (c, child) =>
          MediaQuery(data: MediaQuery.of(c).copyWith(textScaler: const TextScaler.linear(1.2)), child: child!),
      home: w,
    ));
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));
  }

  testWidgets('the results list shows each product with its rating, price and the lowest marked', (t) async {
    await big(t, const ProductSearchScreen(query: 'iPhone 16'));
    expect(find.textContaining('Results for “iPhone 16”'), findsOneWidget);
    expect(find.textContaining('3 products'), findsOneWidget);
    expect(find.text('4.5 (2.85K)'), findsOneWidget);
    expect(find.text('₹76,999'), findsOneWidget);
    expect(find.text('LOWEST PRICE'), findsOneWidget);
    expect(find.text('Popularity'), findsOneWidget);
    // A chip per store, to hide its products.
    expect(find.text('Amazon'), findsOneWidget);
    await t.tap(find.text('Amazon'));
    await t.pump();
    expect(find.textContaining('2 products'), findsOneWidget);
    expect(find.text('₹76,999'), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('the product page shows the best price, every store ranked, alerts, deals and the bottom bar', (t) async {
    await big(t, const ProductDetailScreen(query: 'pixel 10'));
    expect(find.text('BEST PRICE TODAY'), findsOneWidget);
    expect(find.textContaining('below the average price'), findsOneWidget);
    expect(find.textContaining('less than the highest store'), findsOneWidget);
    expect(find.text('SCORE'), findsOneWidget);
    expect(find.byTooltip('Set Alert'), findsOneWidget);
    expect(find.textContaining('Buy Now on Flipkart'), findsOneWidget);
    final list = find.byType(Scrollable).first;
    await t.scrollUntilVisible(find.text('Price at Every Store'), 300, scrollable: list);
    await t.scrollUntilVisible(find.text('LOWEST'), 300, scrollable: list);
    await t.scrollUntilVisible(find.text('+₹2,000 more'), 300, scrollable: list);
    await t.scrollUntilVisible(find.text('Price Drop Alert'), 300, scrollable: list);
    await t.scrollUntilVisible(find.text('SBI10'), 300, scrollable: list);
    await t.scrollUntilVisible(find.text('Deals in This Category'), 300, scrollable: list);
    expect(t.takeException(), isNull);
  });

  test('the deal score follows where the price sits in its range', () {
    PriceResult r(double now, {double? lo, double? hi, double? mrp}) => PriceResult(
          category: PriceCategory.shopping,
          query: 'x',
          product: 'x',
          offers: [PriceOffer(store: 'A', price: now, mrp: mrp)],
          history: PriceRange(lowest: lo, highest: hi),
        );
    expect(ProductDetailScreenScore.of(r(100, lo: 100, hi: 200)), 99);
    expect(ProductDetailScreenScore.of(r(150, lo: 100, hi: 200)), 50);
    expect(ProductDetailScreenScore.of(r(80, mrp: 100)), 50);
    expect(ProductDetailScreenScore.of(r(100)), isNull);
  });

  testWidgets('the Price compare page: search, camera, voice, link, popular searches and stores fit', (t) async {
    // Earlier tests compared products; start with no history.
    PriceService.instance.clearRecent();
    await big(t, const PriceCompareScreen());
    // Only Product compare is offered now (owner, 2026-11-14).
    expect(find.text('Flights'), findsNothing);
    expect(find.text('Select a Category'), findsNothing);
    expect(find.text('Search or paste a link'), findsOneWidget);
    expect(find.byTooltip('Compare a product from a photo'), findsOneWidget);
    expect(find.text('Paste Link'), findsOneWidget);
    expect(find.text('Add Budget'), findsOneWidget);
    expect(find.text('Stores We Compare'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
