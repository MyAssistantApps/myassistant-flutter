import 'package:flutter_test/flutter_test.dart';
import 'package:myassistant/features/home/quick_apps.dart';

void main() {
  test('PayPal is a quick app: its Android package, iPhone scheme and App Store id', () {
    final p = quickApps.firstWhere((a) => a.name == 'PayPal');
    expect(p.pkgs, ['com.paypal.android.p2pmobile']);
    expect(p.iosScheme, 'paypal');
    expect(p.iosStoreId, '283646709');
  });

  test('the payment apps have their own section; the rest stay on Quick Apps', () {
    expect(paymentApps.map((a) => a.name), ['GPay', 'PhonePe', 'Paytm', 'PayPal']);
    expect(otherApps.any((a) => paymentApps.contains(a)), isFalse);
  });

  test('rows are evened out, at most five a row', () {
    expect(tilesPerRow(4), 4);
    expect(tilesPerRow(5), 5);
    expect(tilesPerRow(6), 3);
    expect(tilesPerRow(7), 4);
    expect(tilesPerRow(10), 5);
    expect(tilesPerRow(11), 4);
  });

  test('quick app names are unique', () {
    final names = quickApps.map((a) => a.name).toList();
    expect(names.toSet().length, names.length);
  });
}
