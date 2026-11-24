// Price compare photos (features/pricecompare): a product with no photo
// link, or one that will not load, falls back to photos found by name on
// the server; each name is looked up once, and a failed look-up is
// retried next time instead of being kept.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myassistant/features/pricecompare/price_service.dart';
import 'package:myassistant/features/pricecompare/price_widgets.dart';

void main() {
  final svc = PriceService.instance;
  tearDown(() => svc.findPhotos = null);

  test('photosFor looks a name up once, and asks again after an empty answer', () async {
    var calls = 0;
    svc.findPhotos = (name) async {
      calls++;
      return name == 'Nothing Phone 3' ? const <String>[] : ['https://tse1.mm.bing.net/th?id=$calls'];
    };
    final a = await svc.photosFor('boAt Airdopes 141 (photo test)');
    final b = await svc.photosFor('BOAT AIRDOPES 141 (PHOTO TEST) ');
    expect(a, b);
    expect(calls, 1);

    await svc.photosFor('Nothing Phone 3');
    await svc.photosFor('Nothing Phone 3');
    expect(calls, 3, reason: 'an empty answer is not kept');

    svc.findPhotos = (_) async => throw Exception('offline');
    expect(await svc.photosFor('Offline product (photo test)'), isEmpty);
    expect(await svc.photosFor(' '), isEmpty);
  });

  testWidgets('a product with no photo link asks for photos by its name', (t) async {
    final asked = <String>[];
    svc.findPhotos = (name) async {
      asked.add(name);
      return const <String>[];
    };
    await t.pumpWidget(const MaterialApp(
      home: SizedBox(width: 120, height: 120, child: ProductPhoto('', name: 'Sony WH-1000XM5 (widget test)')),
    ));
    await t.pump();
    expect(asked, ['Sony WH-1000XM5 (widget test)']);
    // Nothing found: the placeholder icon, never an empty box or an error.
    expect(find.byIcon(Icons.shopping_bag_outlined), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
