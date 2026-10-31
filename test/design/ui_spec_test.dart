// The person's design document (v2) as the app reads and applies it
// (lib/design/ui_spec.dart).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myassistant/design/neon_fonts.dart';
import 'package:myassistant/design/neon_tokens.dart';
import 'package:myassistant/design/ui_spec.dart';

Map<String, Object?> _doc({Map<String, Object?> colors = const {}}) => {
      'version': 2,
      'mode': null,
      'colors': colors,
      'background': {'style': 'gradient', 'from': '#0B3D91', 'to': '#00B3D6'},
      'cards': {'radius': 12, 'style': 'solid'},
      'typography': {'font': 'Roboto', 'scale': 1.2},
      'header': {'title': 'Dhanush HQ', 'showDate': false, 'showQuote': true},
      'home': {
        'sections': [
          {'id': 'card:c1', 'visible': true},
          {'id': 'today', 'visible': true},
          {'id': 'born', 'visible': false},
        ],
      },
      'customCards': [
        {
          'id': 'c1',
          'title': 'Water',
          'accent': '#14B8A6',
          'blocks': [
            {'type': 'button', 'label': 'Log', 'ask': 'I drank water'},
          ],
        },
      ],
    };

void main() {
  tearDown(() {
    Neon.usePalette(null);
    Neon.useLook();
    NeonFonts.use(null);
  });

  test('the default is the app as it is', () {
    const s = UiSpec.plain;
    expect(s.palette, isNull);
    expect(s.title, 'MyAssistant');
    expect(s.shows('born'), isTrue);
  });

  test('one colour alone: card text red, everything else the app\'s own', () {
    final s = UiSpec.fromJson(_doc(colors: {'cardText': '#FF5A5F'}));
    expect(s.cardText, const Color(0xFFFF5A5F));
    expect(s.palette!.bg, const Color(0xFF070B2B), reason: 'the app\'s dark page');
    expect(s.palette!.textHi, const Color(0xFFF3F6FF), reason: 'page text untouched');
  });

  test('a whole look, the gradient ends, cards, font, layout', () {
    final s = UiSpec.fromJson(_doc(colors: {'page': '#FFF6F0', 'pageText': '#2A1620', 'card': '#FFFFFF'}));
    expect(s.palette!.dark, isFalse, reason: 'a light page is a light theme');
    expect(s.palette!.surfaceHigh, const Color(0xFFEEEFF6), reason: 'missing colours from the light set');
    expect([s.gradientFrom, s.gradientTo], [const Color(0xFF0B3D91), const Color(0xFF00B3D6)]);
    expect([s.radius, s.cardStyle, s.font, s.scale, s.background], [12, 'solid', 'Roboto', 1.2, 'gradient']);
    expect([s.title, s.showDate, s.shows('born'), s.sections.first.id], ['Dhanush HQ', false, false, 'card:c1']);
    expect(s.cards['c1']!.accent, const Color(0xFF14B8A6));
  });

  test('a look cached in the old format still loads', () {
    final s = UiSpec.fromJson({
      'palette': {'bg': '#061B2D', 'surface': '#0B2A40', 'textHi': '#EAF6FF', 'primary': '#1E88E5'},
      'shape': {'radius': 20, 'cardStyle': 'outlined'},
      'background': 'plain',
    });
    expect(s.palette!.bg, const Color(0xFF061B2D));
    expect([s.radius, s.cardStyle, s.background], [20, 'outlined', 'plain']);
  });

  test('applied, it reaches the tokens everything reads', () {
    final s = UiSpec.fromJson(_doc(colors: {'cardText': '#FF5A5F', 'cardBorder': '#FFFFFF'}));
    Neon.usePalette(s.palette);
    Neon.useLook(
      radius: s.radius, cardStyle: s.cardStyle, background: s.background, cardText: s.cardText,
      cardBorder: s.cardBorder, gradientFrom: s.gradientFrom, gradientTo: s.gradientTo,
    );
    expect(Neon.cardText, const Color(0xFFFF5A5F));
    expect(Neon.cardBorder, const Color(0xFFFFFFFF));
    expect(Neon.gradientFrom, const Color(0xFF0B3D91));
    expect([Neon.cardRadius, Neon.cardStyle, Neon.backgroundStyle], [12, 'solid', 'gradient']);
  });

  test('with no design the card text is the page text', () {
    Neon.useLook();
    expect(Neon.cardText, Neon.textHi);
    expect(Neon.cardBorder, isNull);
  });

  test('the phone font needs no bundled file', () {
    NeonFonts.use('Roboto');
    final t = displayFont(fontSize: 20, fontWeight: FontWeight.w700);
    expect([t.fontSize, t.fontWeight, t.fontFamily], [20, FontWeight.w700, null]);
  });
}
