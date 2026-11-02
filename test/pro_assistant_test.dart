// The professional assistants (client, 2026-11-01): Doctor's, Advocate's and
// Business, each a page of what the app already does for that work.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myassistant/features/home/pro_banners.dart';
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
      // A phone's screen (360 x 800).
      t.view.physicalSize = const Size(1080, 2400);
      t.view.devicePixelRatio = 3;
      addTearDown(t.view.reset);
      await t.pumpWidget(MaterialApp(home: ProAssistantScreen(kind: k)));
      await t.pump();
      // The hero: the profession's name over its photo.
      expect(find.text(ProProfile.of(k).name), findsOneWidget);
      expect(find.text('Chat with the ${ProProfile.of(k).name} Assistant'), findsOneWidget);
      for (final a in ProProfile.of(k).actions) {
        expect(find.text(a.title), findsOneWidget);
      }
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('Home banners slide through the three, a tap opens one', (t) async {
    ProKind? opened;
    await t.pumpWidget(MaterialApp(
        home: Scaffold(body: ListView(children: [ProBanners(onOpen: (k) => opened = k)]))));
    await t.pump();
    expect(find.text("Doctor's"), findsOneWidget);
    await t.tap(find.text("Doctor's"));
    expect(opened, ProKind.doctor);
    await t.drag(find.byType(PageView), const Offset(-400, 0));
    await t.pumpAndSettle();
    expect(find.text("Advocate's"), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });
}
