import 'package:flutter_test/flutter_test.dart';
import 'package:myassistant/features/pricecompare/price_service.dart';

void main() {
  test('a product named only by its variant gets the search in front', () {
    expect(PriceService.fullProductName('Teal', 'iPhone 16'), 'iPhone 16 Teal');
    expect(PriceService.fullProductName('Apple iPhone 16 (128 GB) - Teal', 'iPhone 16'), 'Apple iPhone 16 (128 GB) - Teal');
    expect(PriceService.fullProductName('', 'boat airdopes'), 'boat airdopes');
    expect(PriceService.fullProductName('Teal', 'https://amzn.in/x'), 'Teal');
  });
}
