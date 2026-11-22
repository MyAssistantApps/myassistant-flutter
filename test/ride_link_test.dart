import 'package:flutter_test/flutter_test.dart';
import 'package:myassistant/features/home/ride_sheet.dart';

void main() {
  test('Uber: pickup here, the typed destination as the drop-off', () {
    final u = rideLink('uber', 'Mangalore Airport');
    expect(u, startsWith('https://m.uber.com/ul/?action=setPickup&pickup=my_location'));
    expect(u, contains('dropoff[formatted_address]=Mangalore%20Airport'));
    expect(u, contains('dropoff[nickname]=Mangalore%20Airport'));
  });

  test('Ola: its booking page with the drop-off named', () {
    expect(rideLink('ola', 'MG Road'),
        'https://book.olacabs.com/?utm_source=myassistant&drop_name=MG%20Road');
  });
}
