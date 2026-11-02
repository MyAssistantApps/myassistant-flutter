// The professional assistants (client, 2026-11-01): Doctor's, Advocate's and
// Business, each a page of what the app already does for that work.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myassistant/screens/pro_assistant_screen.dart';

void main() {
  test('each profession has its own actions, each one opens or asks', () {
    for (final k in ProKind.values) {
      final p = ProProfile.of(k);
      expect(p.actions.length, greaterThanOrEqualTo(3), reason: p.name);
      for (final a in p.actions) {
        expect(a.page != null || (a.ask?.isNotEmpty ?? false), isTrue, reason: '${p.name}: ${a.title}');
      }
    }
    expect(ProProfile.of(ProKind.doctor).name, "Doctor's");
    expect(ProProfile.of(ProKind.advocate).name, "Advocate's");
    expect(ProProfile.of(ProKind.business).name, 'Business');
  });

  for (final k in ProKind.values) {
    testWidgets('${ProProfile.of(k).name} Assistant page draws its actions', (t) async {
      await t.pumpWidget(MaterialApp(home: ProAssistantScreen(kind: k)));
      await t.pump();
      expect(find.text('${ProProfile.of(k).name} Assistant'), findsOneWidget);
      for (final a in ProProfile.of(k).actions) {
        expect(find.text(a.title), findsOneWidget);
      }
      expect(t.takeException(), isNull);
    });
  }
}
