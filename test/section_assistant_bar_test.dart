// A speaker and a camera in every section (widgets/section_assistant_bar.dart):
// each section's assistant has its own name and work, the role reaches the
// assistant's instruction, and every section page shows the pair.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myassistant/ai/assistant_role.dart';
import 'package:myassistant/features/home/buses_screen.dart';
import 'package:myassistant/features/home/flights_screen.dart';
import 'package:myassistant/features/home/hotels_screen.dart';
import 'package:myassistant/widgets/section_assistant_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => AssistantRole.current.value = null);

  const roles = [
    SectionRoles.flights,
    SectionRoles.buses,
    SectionRoles.hotels,
    SectionRoles.services,
  ];

  test('each section has its own assistant', () {
    expect(roles.map((r) => r.name).toSet().length, roles.length);
    for (final r in roles) {
      expect(r.name, startsWith('the '));
      expect(r.name, endsWith(' Assistant'));
      expect(r.brief, isNotEmpty);
    }
  });

  test('the section role is told to the assistant', () {
    AssistantRole.current.value = SectionRoles.hotels;
    final s = AssistantRole.apply('BASE');
    expect(s, startsWith('BASE'));
    expect(s, contains('you are the Hotels Assistant'));
  });

  for (final (name, page) in [
    ('Flights', const FlightsScreen()),
    ('Buses', const BusesScreen()),
    ('Hotels', const HotelsScreen()),
  ]) {
    testWidgets('$name shows a speaker and a camera', (t) async {
      t.view.physicalSize = const Size(1080, 2400);
      t.view.devicePixelRatio = 3;
      addTearDown(t.view.reset);
      await t.pumpWidget(MaterialApp(home: page));
      await t.pump();

      expect(find.byType(SectionAssistantBar), findsOneWidget);
      expect(find.text('Ask the $name Assistant'), findsOneWidget);
      expect(find.text('Camera'), findsOneWidget);
      // Scoped to the bar: Hotels also has production's floating booking
      // mic (BookingVoiceOrb), which says "Tap to talk" too.
      expect(
          find.descendant(
              of: find.byType(SectionAssistantBar),
              matching: find.text('Tap to talk')),
          findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }
}
