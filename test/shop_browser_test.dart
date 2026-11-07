// The in-app shop browser (features/pricecompare/shop_browser.dart): what
// a page's script reports is read into a product only when it is one.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:myassistant/features/pricecompare/price_models.dart';
import 'package:myassistant/features/pricecompare/price_service.dart';
import 'package:myassistant/features/pricecompare/shop_browser.dart';

void main() {
  String page(Map<String, Object?> m) => jsonEncode(jsonEncode(m)); // as Android hands it back

  test('an Amazon product page is a product, its title cleaned', () {
    final p = PageProduct.read(page({
      'name': 'Apple iPhone 16 (128 GB) - Black : Amazon.in: Electronics',
      'price': '₹69,900.00',
      'image': 'https://m.media-amazon.com/x.jpg',
      'product': false,
      'url': 'https://www.amazon.in/Apple-iPhone-16/dp/B0DGJ65N7V',
    }))!;
    expect(p.name, 'Apple iPhone 16 (128 GB) - Black');
    expect(p.price, 69900);
    expect(p.image, startsWith('https://'));
  });

  test('schema.org Product data counts even without a known URL', () {
    final p = PageProduct.read(
        jsonEncode({'name': 'boAt Airdopes 141', 'price': '1299', 'product': true, 'url': 'https://example.com/x'}))!;
    expect(p.price, 1299);
  });

  test('a home or search page is not a product', () {
    expect(
        PageProduct.read(page(
            {'name': 'Browse all categories', 'price': '₹33,990', 'product': false, 'url': 'https://www.amazon.in/'})),
        isNull);
    expect(
        PageProduct.read(page({'name': 'Amazon.in', 'price': '', 'product': false, 'url': 'https://www.amazon.in/'})),
        isNull);
    expect(PageProduct.read(page({'name': '', 'price': '999', 'product': true, 'url': 'https://x.in/dp/1'})), isNull);
    expect(PageProduct.read('not json'), isNull);
  });

  test('an insecure image is dropped', () {
    final p = PageProduct.read(jsonEncode({
      'name': 'Milk 1L',
      'price': '68',
      'image': 'http://x/y.jpg',
      'product': true,
      'url': 'https://blinkit.com/prn/milk/prid/1'
    }))!;
    expect(p.image, isEmpty);
  });

  test('the AI recommendation is read, its pick kept in range', () {
    final a = ProductAdvice.parse(
        '```json\n{"verdict": "Buy the Galaxy S24", "pick": 2, "why": "Better camera.", '
        '"items": [{"name": "iPhone 15", "good": ["iOS"], "bad": ["slow charging"], "score": 7}, '
        '{"name": "Galaxy S24", "good": ["camera", "screen"], "bad": [], "score": 9}], '
        '"alternatives": [{"name": "Pixel 8", "price": "₹52,999", "why": "clean Android"}, {"name": ""}]}\n```',
        count: 2)!;
    expect(a.pick, 1);
    expect(a.items[1].score, 9);
    expect(a.items[0].bad, ['slow charging']);
    expect(a.alternatives.single.price, 52999);
    expect(ProductAdvice.parse('{"verdict": "x", "pick": 9}', count: 2)!.pick, 1);
    expect(ProductAdvice.parse('no', count: 1), isNull);
  });

  test('an intent link falls back to its web page', () {
    expect(
        webFallbackOf('intent://www.amazon.in/dp/B0X#Intent;scheme=https;package=in.amazon.mShop.android.shopping;'
            'S.browser_fallback_url=https%3A%2F%2Fwww.amazon.in%2Fdp%2FB0X;end'),
        'https://www.amazon.in/dp/B0X');
    expect(webFallbackOf('intent://dl.flipkart.com/p/x#Intent;scheme=https;package=com.flipkart.android;end'),
        'https://dl.flipkart.com/p/x');
    expect(webFallbackOf('market://details?id=x'), isNull);
    expect(categoryForUrl('https://blinkit.com/prn/x'), PriceCategory.grocery);
    expect(categoryForUrl('https://www.amazon.in/deals'), PriceCategory.shopping);
  });

  test('every store in the browser has its logo on disk', () {
    for (final s in shopStores) {
      final logo = brandLogoFor(store: s.$1);
      expect(logo, isNotNull, reason: s.$1.name);
      expect(File(logo!).existsSync(), isTrue, reason: logo);
    }
    expect(brandLogoFor(store: PriceStores.instamart), 'assets/brands/swiggy.png');
    expect(brandLogoFor(host: 'm.zomato.com'), 'assets/brands/zomato.png');
    expect(brandLogoFor(host: 'www.1mg.com'), 'assets/brands/tata1mg.png');
    expect(brandLogoFor(host: 'example.com'), isNull);
  });
}
