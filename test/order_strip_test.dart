import 'package:flutter_test/flutter_test.dart';
import 'package:myassistant/features/home/order_strip.dart';
import 'package:myassistant/features/home/ride_strip.dart';

void main() {
  test('an order reads what the server sends and says where it is', () {
    final o = ActiveOrder.fromJson({
      'id': 4, 'kind': 'medicine', 'providerLabel': 'Test Store', 'test': true,
      'summary': 'Dolo 650', 'status': 'out_for_delivery', 'etaMin': 12,
      'partner': {'name': 'Ravi'}, 'otp': '4821',
    });
    expect(o.statusLine, 'Out for delivery · 12 min');
    expect(o.cancellable, isFalse);
    expect(o.otp, '4821');
    expect(ActiveOrder.fromJson(const {'status': 'confirmed'}).cancellable, isTrue);
  });

  test('a ride tolerates missing driver and vehicle', () {
    final r = ActiveRide.fromJson(const {'id': 1, 'status': 'searching', 'drop': 'Majestic'});
    expect(r.statusLine, 'Finding a driver');
    expect(r.otp, isEmpty);
    final a = ActiveRide.fromJson(const {
      'status': 'accepted', 'etaMin': 4, 'otp': '1234',
      'driver': {'name': 'Suresh'}, 'vehicle': {'model': 'Dzire', 'plate': 'KA 01 AB 1234'},
    });
    expect(a.statusLine, 'Driver on the way · 4 min');
    expect(a.plate, 'KA 01 AB 1234');
  });
}
