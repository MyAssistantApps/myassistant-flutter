// "Order and shop" (features/home/deal_banners.dart): suggestions follow the
// meal time and the shopping list, and no banner invents a discount.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myassistant/features/home/deal_banners.dart';

void main() {
  DateTime at(int h) => DateTime(2026, 11, 1, h, 15);

  test('meal times lead with food, named for the meal', () {
    final lunch = dealBannersFor(at(13));
    expect(lunch.first.brand, 'Swiggy');
    expect(lunch.first.title, 'Lunch time');
    expect(dealBannersFor(at(20)).first.title, 'Dinner time');
  });

  test('a shopping list leads with groceries, naming what is on it', () {
    final b = dealBannersFor(at(17), toBuy: ['milk', 'eggs', 'bread', 'rice']);
    expect(b.first.brand, 'Blinkit');
    expect(b.first.title, '4 things on your list');
    expect(b.first.body, 'milk, eggs, bread and more — get them in minutes.');
  });

  test('no banner claims a discount it cannot back', () {
    for (final h in [8, 13, 17, 21]) {
      for (final b in dealBannersFor(at(h), toBuy: ['milk'])) {
        final all = '${b.title} ${b.body} ${b.action}';
        expect(RegExp(r'\d+\s*%|% off|flat|cashback|free delivery', caseSensitive: false).hasMatch(all), isFalse,
            reason: all);
        expect(b.pkg.isNotEmpty || b.url.startsWith('https://'), isTrue, reason: b.brand);
      }
    }
  });

  testWidgets('the carousel draws, swipes and shows its dots', (t) async {
    await t.pumpWidget(MaterialApp(
      home: Scaffold(body: ListView(children: [DealBanners(banners: dealBannersFor(at(13)))])),
    ));
    expect(find.text('Order and shop'), findsOneWidget);
    expect(find.text('Lunch time'), findsOneWidget);
    await t.drag(find.byType(PageView), const Offset(-300, 0));
    await t.pumpAndSettle();
    expect(find.text('Something different?'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
