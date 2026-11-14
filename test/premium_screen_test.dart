import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myassistant/features/premium/premium_plans.dart';
import 'package:myassistant/features/premium/premium_screen.dart';

Future<void> _loadFonts() async {
  final dir = Directory('assets/google_fonts');
  if (!dir.existsSync()) return;
  final loader = FontLoader('Inter Tight');
  for (final f in dir.listSync().whereType<File>()) {
    if (f.path.contains('InterTight') && f.path.endsWith('.ttf')) {
      loader.addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
    }
  }
  await loader.load();
}

Widget _app(Widget child) => MaterialApp(
      theme: ThemeData(fontFamily: 'Inter Tight', brightness: Brightness.dark),
      home: child,
    );

void main() {
  test('rupees groups the Indian way', () {
    expect(rupees(99), '₹99');
    expect(rupees(1999), '₹1,999');
    expect(rupees(14999), '₹14,999');
    expect(rupees(179988), '₹1,79,988');
  });

  test('yearly saves on every plan', () {
    for (final p in premiumPlans) {
      expect(p.yearly, lessThan(p.yearOfMonthly), reason: p.name);
    }
  });

  testWidgets('fits a 360 px phone, switches period and plan', (tester) async {
    await _loadFonts();
    tester.view.physicalSize = const Size(1080, 4200);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    String? bought;
    await tester.pumpWidget(_app(PremiumScreen(
      onPurchase: (id, period) async => bought = '$id/${period.name}',
    )));
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.takeException(), isNull);

    // Yearly is the default.
    expect(find.text('₹4,999'), findsOneWidget);
    expect(find.text("What's in Pro"), findsOneWidget);

    if (Platform.environment['PREMIUM_SHOT'] == '1') {
      await expectLater(find.byType(PremiumScreen),
          matchesGoldenFile('goldens/premium_yearly.png'));
    }

    await tester.tap(find.text('Monthly'));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('₹499'), findsOneWidget);

    await tester.tap(find.text('Business'));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text("What's in Business"), findsOneWidget);

    await tester.tap(find.text('Subscribe').at(1));
    await tester.pump(const Duration(milliseconds: 600));
    expect(bought, 'pro/monthly');
    expect(tester.takeException(), isNull);
  });
}
