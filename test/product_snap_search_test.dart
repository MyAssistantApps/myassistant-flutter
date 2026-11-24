// Price compare's camera and microphone search (features/pricecompare):
// the product named in a photo or spoken becomes the search, and a photo
// with no product, or silence, says so instead of searching.
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:myassistant/features/pricecompare/price_service.dart';

void main() {
  final svc = PriceService.instance;
  final bytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0]);

  tearDown(() {
    svc.see = null;
    svc.hear = null;
  });

  group('productNameOf', () {
    test('keeps the first line, without a label or quotes', () {
      expect(PriceService.productNameOf('boAt Airdopes 141'), 'boAt Airdopes 141');
      expect(PriceService.productNameOf('Product: "Apple iPhone 16 128GB".\nIt is blue.'), 'Apple iPhone 16 128GB');
      expect(PriceService.productNameOf('  **Sony WH-1000XM5**  '), 'Sony WH-1000XM5');
    });

    test('NONE or nothing is no product', () {
      expect(PriceService.productNameOf('NONE'), '');
      expect(PriceService.productNameOf('none.'), '');
      expect(PriceService.productNameOf('   '), '');
    });
  });

  test('a photo of a product becomes its name', () async {
    svc.see = (b, mime) async {
      expect(mime, 'image/jpeg');
      return 'Name: boAt Airdopes 141';
    };
    expect(await svc.productInPhoto(bytes, 'image/jpeg'), 'boAt Airdopes 141');
  });

  test('a photo with no product says so', () async {
    svc.see = (_, __) async => 'NONE';
    expect(() => svc.productInPhoto(bytes, 'image/jpeg'), throwsA(isA<PriceCompareException>()));
  });

  test('a failed photo look-up says what to do', () async {
    svc.see = (_, __) async => throw Exception('offline');
    expect(() => svc.productInPhoto(bytes, 'image/jpeg'), throwsA(isA<PriceCompareException>()));
  });

  test('spoken words become the search; silence says so', () async {
    svc.hear = (_, mime) async => '  iPhone 16 128GB ';
    expect(await svc.productFromSpeech(bytes, 'audio/wav'), 'iPhone 16 128GB');
    svc.hear = (_, __) async => '';
    expect(() => svc.productFromSpeech(bytes, 'audio/wav'), throwsA(isA<PriceCompareException>()));
  });
}
