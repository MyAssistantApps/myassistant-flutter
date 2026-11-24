import 'package:flutter_test/flutter_test.dart';
import 'package:myassistant/features/pricecompare/price_service.dart';

void main() {
  test('a named product is read from the answer', () {
    expect(PriceService.productNameFrom('{"product": "Apple iPhone 16 128GB Black"}'),
        'Apple iPhone 16 128GB Black');
    expect(PriceService.productNameFrom('Here it is:\n```json\n{"product": " boAt Airdopes 141 "}\n```'),
        'boAt Airdopes 141');
  });

  test('no product, or an unreadable answer, gives null', () {
    expect(PriceService.productNameFrom('{"product": ""}'), isNull);
    expect(PriceService.productNameFrom('I cannot see a product.'), isNull);
    expect(PriceService.productNameFrom('{"product": '), isNull);
    expect(PriceService.productNameFrom('[1, 2]'), isNull);
  });

  test('a product named only by its variant gets the search in front', () {
    expect(PriceService.fullProductName('Teal', 'iPhone 16'), 'iPhone 16 Teal');
    expect(PriceService.fullProductName('Apple iPhone 16 (128 GB) - Teal', 'iPhone 16'), 'Apple iPhone 16 (128 GB) - Teal');
    expect(PriceService.fullProductName('', 'boat airdopes'), 'boat airdopes');
    expect(PriceService.fullProductName('Teal', 'https://amzn.in/x'), 'Teal');
  });
}
