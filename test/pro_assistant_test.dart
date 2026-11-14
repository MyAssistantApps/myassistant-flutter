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
        // Opens a page, runs in place (a sheet), or asks the assistant.
        expect(a.page != null || a.run != null || (a.ask?.isNotEmpty ?? false), isTrue,
            reason: '${p.name}: ${a.title}');
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
      // The page is a lazy list: scroll to each thing, as a user would —
      // the Doctor's page has six actions, so the chat sits below the fold.
      final scroller = find.byType(Scrollable).first;
      for (final a in ProProfile.of(k).actions) {
        await t.scrollUntilVisible(find.text(a.title), 120, scrollable: scroller);
        expect(find.text(a.title), findsOneWidget);
      }
      // The ask card's message box (2026-11-14) carries this label.
      final chat = find.bySemanticsLabel('Chat with the ${ProProfile.of(k).name} Assistant');
      await t.scrollUntilVisible(chat, 120, scrollable: scroller);
      expect(chat, findsOneWidget);
      expect(t.takeException(), isNull);
      // Scrolling built the page's animated mic orb: dispose it inside the
      // test, as the banner test below does, so no frame is left pending.
      await t.pumpWidget(const SizedBox());
      // The first widget test loads the app's fonts, and the engine's
      // "system fonts changed" message lands asynchronously — let it arrive
      // and be handled here rather than after the tree is gone.
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await t.pump(const Duration(milliseconds: 100));
    });
  }

  testWidgets('Home banners slide through the three, a tap opens one', (t) async {
    ProKind? opened;
    await t.pumpWidget(MaterialApp(
        home: Scaffold(body: ListView(children: [ProBanners(onOpen: (k) => opened = k)]))));
    await t.pump();
    expect(find.text("Doctor's\nAssistant"), findsOneWidget);
    await t.tap(find.text("Doctor's\nAssistant"));
    expect(opened, ProKind.doctor);
    await t.drag(find.byType(PageView), const Offset(-400, 0));
    await t.pumpAndSettle();
    expect(find.text("Advocate's\nAssistant"), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });
}
