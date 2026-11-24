// Try Now's pictures (owner, 2026-11-24): real-looking people instead of
// the robot — women or men, the user's choice above the cards.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myassistant/features/home/try_now_cards.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TryNowLook.models.value = TryNowModels.women;
  });

  test('every card has a picture of a woman and of a man', () {
    for (final c in tryNowCards) {
      for (final m in TryNowModels.values) {
        final f = File(TryNowLook.art(c, m));
        expect(f.existsSync(), isTrue, reason: f.path);
        expect(f.lengthSync(), lessThan(400 * 1024), reason: '${f.path} stays small');
      }
    }
    // The robot pictures are gone.
    for (final c in tryNowCards) {
      expect(File('assets/tryon/${c.art}.png').existsSync(), isFalse, reason: c.art);
    }
  });

  test('until chosen, a profile that says male sees men, everyone else women', () {
    expect(TryNowLook.fromSaved(null, 'male'), TryNowModels.men);
    expect(TryNowLook.fromSaved(null, ' Male '), TryNowModels.men);
    expect(TryNowLook.fromSaved(null, 'female'), TryNowModels.women);
    expect(TryNowLook.fromSaved(null, 'other'), TryNowModels.women);
    expect(TryNowLook.fromSaved(null, null), TryNowModels.women);
    // A choice made wins over the profile.
    expect(TryNowLook.fromSaved('women', 'male'), TryNowModels.women);
    expect(TryNowLook.fromSaved('men', 'female'), TryNowModels.men);
    expect(TryNowLook.fromSaved('nonsense', 'male'), TryNowModels.men);
  });

  testWidgets('Women / Men swaps the pictures, and the choice is kept', (t) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(
        home: Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: TryNowSection(onOpen: (_) {})))));
    await t.pump();
    Iterable<String> shown() => t
        .widgetList<Image>(find.byType(Image))
        .map((i) => i.image)
        .whereType<AssetImage>()
        .map((a) => a.assetName);
    expect(shown(), isNotEmpty);
    expect(shown().every((a) => a.endsWith('_women.png')), isTrue, reason: '${shown()}');

    await t.tap(find.text('Men'));
    await t.pump();
    expect(shown().every((a) => a.endsWith('_men.png')), isTrue, reason: '${shown()}');
    expect((await SharedPreferences.getInstance()).getString('try_now_models'), 'men');

    await t.tap(find.text('Women'));
    await t.pump();
    expect(shown().every((a) => a.endsWith('_women.png')), isTrue);
    expect(find.bySemanticsLabel('Show men'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });
}
