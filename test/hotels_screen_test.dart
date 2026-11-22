// Hotels & Airbnb (features/home/hotels_screen.dart): Airbnb sits above
// the hotel sites with its own logo, and the page draws without overflow.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myassistant/features/home/hotels_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('the Airbnb logo is bundled', () {
    expect(File('assets/brands/airbnb.png').existsSync(), isTrue);
  });

  testWidgets('Airbnb is offered for homes, above the hotel sites', (t) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(const MaterialApp(home: HotelsScreen()));
    await t.pump();
    // The section's speaker and camera card is pinned above the list.
    await t.scrollUntilVisible(find.text('Booking.com'), 200,
        scrollable: find.byType(Scrollable).first);

    expect(find.text('Hotels & Airbnb'), findsOneWidget);
    expect(find.text('HOMES & VILLAS'), findsOneWidget);
    expect(find.text('Airbnb'), findsOneWidget);
    expect(find.text('Booking.com'), findsOneWidget);
    expect(
      t.getTopLeft(find.text('Airbnb')).dy,
      lessThan(t.getTopLeft(find.text('Booking.com')).dy),
    );
    expect(t.takeException(), isNull);
  });
}
