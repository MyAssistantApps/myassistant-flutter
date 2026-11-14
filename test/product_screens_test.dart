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
        (text: p.contains('"products"') ? _grid : _page, sources: const <SourceLink>[], suggestionsHtml: null);
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

  testWidgets('the results grid shows each product with its rating and price', (t) async {
    await big(t, const ProductSearchScreen(query: 'iPhone 16'));
    expect(find.text('Showing results for “iPhone 16”'), findsOneWidget);
    expect(find.text('4.5 (2.85K)'), findsOneWidget);
    expect(find.text('₹76,999'), findsOneWidget);
    expect(find.text('Popularity'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('the product page shows price vs average, score, stores, deals and the bottom bar', (t) async {
    await big(t, const ProductDetailScreen(query: 'pixel 10'));
    expect(find.textContaining('lower than average price'), findsOneWidget);
    expect(find.text('SCORE'), findsOneWidget);
    expect(find.text('Set Alert'), findsOneWidget);
    expect(find.textContaining('Buy Now'), findsOneWidget);
    final list = find.byType(Scrollable).first;
    await t.scrollUntilVisible(find.text('Never miss a price drop'), 300, scrollable: list);
    await t.scrollUntilVisible(find.text('More Store Prices'), 300, scrollable: list);
    await t.scrollUntilVisible(find.text('LOWEST'), 300, scrollable: list);
    await t.scrollUntilVisible(find.text('Deals in this category'), 300, scrollable: list);
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

  testWidgets('the Price compare page: categories, search pill, examples and stores fit', (t) async {
    await big(t, const PriceCompareScreen());
    // Only Product compare is offered now (owner, 2026-11-14).
    expect(find.text('Grocery'), findsNothing);
    expect(find.text('Flights'), findsNothing);
    expect(find.text('Try'), findsOneWidget);
    expect(find.text('iPhone 16 128GB'), findsOneWidget);
    expect(find.text('Add budget'), findsOneWidget);
    expect(find.text('Checks'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
