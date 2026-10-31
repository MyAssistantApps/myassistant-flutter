// The person's look as the app reads and applies it (lib/design/ui_spec.dart).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myassistant/design/neon_fonts.dart';
import 'package:myassistant/design/neon_tokens.dart';
import 'package:myassistant/design/ui_spec.dart';

Map<String, Object?> _spec({Map<String, Object?>? palette}) => {
      'version': 1,
      'mode': null,
      'palette': palette,
      'shape': {'radius': 12, 'cardStyle': 'solid'},
      'type': {'font': 'Roboto', 'scale': 1.2},
      'background': 'plain',
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
            {'type': 'stat', 'source': 'habits', 'label': 'Today'},
            {'type': 'button', 'label': 'Log', 'ask': 'I drank water'},
          ],
        },
      ],
    };

const _sunset = {
  'name': 'Sunset', 'dark': true, 'bg': '#1A0E14', 'surface': '#2A1620', 'surfaceHigh': '#3A1E2C',
  'primary': '#FF7A45', 'partner': '#FF3D7F', 'secondary': '#FFC15E', 'tertiary': '#9BE15D',
  'textHi': '#FFF4EC', 'textLo': '#E8C7B8', 'textDim': '#B8958A',
};

void main() {
  tearDown(() {
    Neon.usePalette(null);
    Neon.useLook();
    NeonFonts.use(null);
  });

  test('the default spec is the app as it is', () {
    const s = UiSpec.plain;
    expect(s.palette, isNull);
    expect(s.title, 'MyAssistant');
    expect(s.shows('born'), isTrue);
    expect(s.scale, 1);
  });

  test('reads the whole look', () {
    final s = UiSpec.fromJson(_spec(palette: _sunset));
    expect(s.palette!.name, 'Sunset');
    expect(s.palette!.bg, const Color(0xFF1A0E14));
    expect([s.radius, s.cardStyle, s.font, s.scale, s.background], [12, 'solid', 'Roboto', 1.2, 'plain']);
    expect([s.title, s.showDate, s.showQuote], ['Dhanush HQ', false, true]);
    expect(s.shows('born'), isFalse);
    expect(s.shows('today'), isTrue);
    expect(s.sections.first.id, 'card:c1');
  });

  test('a palette missing a colour is ignored, never half-applied', () {
    final broken = Map<String, Object?>.from(_sunset)..remove('textHi');
    expect(UiSpec.fromJson(_spec(palette: broken)).palette, isNull);
  });

  test('custom cards: accent and blocks; server-filled data wins', () {
    final s = UiSpec.fromJson(_spec(), [
      {
        'id': 'c1',
        'title': 'Water',
        'blocks': [
          {'type': 'stat', 'label': 'Today', 'value': '3 glasses'},
          {'type': 'list', 'items': ['a', 'b']},
        ],
      },
    ]);
    final c = s.cards['c1']!;
    expect(c.blocks.first.value, '3 glasses');
    expect(c.blocks.last.items, ['a', 'b']);
    expect(UiSpec.fromJson(_spec()).cards['c1']!.accent, const Color(0xFF14B8A6));
  });

  test('applying a look reaches the tokens everything reads', () {
    final s = UiSpec.fromJson(_spec(palette: _sunset));
    Neon.usePalette(s.palette);
    Neon.useLook(radius: s.radius, cardStyle: s.cardStyle, background: s.background);
    NeonFonts.use(s.font);
    expect(Neon.bg, const Color(0xFF1A0E14));
    expect(Neon.cardRadius, 12);
    expect(Neon.cardStyle, 'solid');
    expect(Neon.backgroundStyle, 'plain');
    expect(NeonFonts.display, 'Roboto');
  });

  test('the phone font needs no bundled file; the app pairing comes back with null', () {
    NeonFonts.use('Roboto');
    final t = displayFont(fontSize: 20, fontWeight: FontWeight.w700);
    expect([t.fontSize, t.fontWeight, t.fontFamily], [20, FontWeight.w700, null]);
    NeonFonts.use(null);
    expect([NeonFonts.display, NeonFonts.body], ['Space Grotesk', 'Manrope']);
    expect([Neon.cardRadius, Neon.cardStyle, Neon.backgroundStyle], [Neon.rCard, 'glass', 'ambient']);
  });
}
