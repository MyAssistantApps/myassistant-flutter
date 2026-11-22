import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myassistant/design/neon_tokens.dart';
import 'package:myassistant/services/overlay_bridge.dart';

void main() {
  tearDown(() {
    Neon.setAccent(null);
    Neon.setDark(true);
  });

  test('floating mic gets the app accent, partner and cyan', () {
    Neon.setDark(true);
    Neon.setAccent(const Color(0xFF39FF14)); // Green
    final c = OverlayBridge.themeColors();
    expect(c['accent'], Neon.violet.toARGB32());
    expect(c['accent'], 0xFF39FF14);
    expect(c['partner'], Neon.pink.toARGB32());
    expect(c['cyan'], Neon.cyan.toARGB32());
  });

  test('floating mic follows the light theme ink', () {
    Neon.setDark(false);
    Neon.setAccent(const Color(0xFF39FF14));
    expect(OverlayBridge.themeColors()['accent'], Neon.violet.toARGB32());
    expect(OverlayBridge.themeColors()['accent'], isNot(0xFF39FF14));
  });
}
