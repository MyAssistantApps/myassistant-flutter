import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myassistant/features/home/cosmic_painter.dart';
import 'package:myassistant/features/jyotish/jyotish_card.dart';
import 'package:myassistant/features/jyotish/jyotish_theme.dart';

void main() {
  test('Gemini has a constellation to draw', () {
    expect(CosmicPainter.constellations, contains('gemini'));
  });

  testWidgets('the card: headed like the slides, words clear of Gemini, camera and mic centred', (t) async {
    await t.pumpWidget(const MaterialApp(home: Scaffold(body: JyotishCard())));
    expect(find.byIcon(Icons.auto_awesome_rounded), findsNothing);
    expect(
        find.byWidgetPredicate((w) => w is CustomPaint && w.painter is HinduMotifPainter),
        findsOneWidget);
    final card = t.getRect(find.byType(JyotishCard));
    expect(find.text("TODAY'S HOROSCOPE"), findsOneWidget);
    expect(find.text('Your Vedic Horoscope'), findsOneWidget);
    // Gemini is drawn from 60% of the width; the words stop before it.
    for (final w in ["TODAY'S HOROSCOPE", 'Your Vedic Horoscope']) {
      expect(t.getRect(find.text(w)).right, lessThanOrEqualTo(card.left + card.width * 0.6));
    }
    expect(t.getRect(find.textContaining('Kundli, dasha')).right,
        lessThanOrEqualTo(card.left + card.width * 0.6));
    final camera = t.getRect(find.bySemanticsLabel('Upload your horoscope'));
    final mic = t.getRect(find.bySemanticsLabel(RegExp(r'^Speak to .* about your horoscope$')));
    final pair = (camera.left + mic.right) / 2;
    expect((pair - card.center.dx).abs(), lessThan(2));
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });
}
