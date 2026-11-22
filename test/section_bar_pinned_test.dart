// The section's speaker and camera stay on screen while the page scrolls
// (client, 2026-11-22: "it should not hide when we scroll down").
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myassistant/features/home/buses_screen.dart';
import 'package:myassistant/features/home/flights_screen.dart';
import 'package:myassistant/features/home/hotels_screen.dart';
import 'package:myassistant/features/pricecompare/price_compare_screen.dart';
import 'package:myassistant/screens/clinic/appointments_screen.dart';
import 'package:myassistant/screens/clinic/clinic_screen.dart';
import 'package:myassistant/screens/pro/cases_screen.dart';
import 'package:myassistant/screens/pro/legal_draft_screen.dart';
import 'package:myassistant/widgets/section_assistant_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final screens = <String, Widget>{
    'Flights': const FlightsScreen(),
    'Buses': const BusesScreen(),
    'Hotels': const HotelsScreen(),
    'Price Compare': const PriceCompareScreen(),
    'Workspace': const ClinicScreen(),
    'Appointments': const AppointmentsScreen(),
    'Cases': const CasesScreen(),
    'Legal draft': const LegalDraftScreen(),
  };

  for (final e in screens.entries) {
    testWidgets('${e.key}: the mic and camera stay put on scroll', (t) async {
      t.view.physicalSize = const Size(1080, 2000);
      t.view.devicePixelRatio = 3;
      addTearDown(t.view.reset);
      await t.pumpWidget(MaterialApp(home: e.value));
      await t.pump();

      final bar = find.byType(SectionAssistantBar);
      expect(bar, findsOneWidget);
      final before = t.getTopLeft(bar);

      // Whatever scrolls on the page (a short or empty page may not).
      final scrollables = find.byType(Scrollable);
      if (scrollables.evaluate().isNotEmpty) {
        await t.drag(scrollables.last, const Offset(0, -2000),
            warnIfMissed: false);
      }
      await t.pump(const Duration(milliseconds: 500));

      expect(bar, findsOneWidget);
      expect(t.getTopLeft(bar), before);
      expect(find.text('Camera'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }
}
