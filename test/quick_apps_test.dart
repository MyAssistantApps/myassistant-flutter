import 'package:flutter_test/flutter_test.dart';
import 'package:myassistant/features/home/quick_apps.dart';

void main() {
  test('PayPal is a quick app: its Android package, iPhone scheme and App Store id', () {
    final p = quickApps.firstWhere((a) => a.name == 'PayPal');
    expect(p.pkgs, ['com.paypal.android.p2pmobile']);
    expect(p.iosScheme, 'paypal');
    expect(p.iosStoreId, '283646709');
  });

  test('quick app names are unique', () {
    final names = quickApps.map((a) => a.name).toList();
    expect(names.toSet().length, names.length);
  });
}
