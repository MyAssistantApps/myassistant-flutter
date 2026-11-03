import 'package:flutter/material.dart';

import '../design/neon_tokens.dart';

/// THE GROUND THE APP SITS ON (2026-11-02, the light premium redesign):
/// one flat [Neon.bg], paper by day and violet-black by night. The raised
/// cards on it carry the depth. (The night-sky wash, pools and ribbons,
/// shaders/ambient.frag, were taken out with the neon look.)
class AmbientBackground extends StatelessWidget {
  final Widget child;

  /// True while something opaque covers the whole page (the voice session).
  final bool covered;

  const AmbientBackground(
      {super.key, required this.child, this.covered = false});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Visibility.maintain(
            visible: !covered,
            child: const AmbientLight(),
          ),
        ),
        child,
      ],
    );
  }
}

/// The ground alone. A tab opening in a circle over another tab carries it
/// inside the circle (TabDeck.ground), so the tab being covered does not
/// show through.
///
/// THE THEME'S AURORA (2026-11-03, "premium, not just purple"): four soft
/// lights over [Neon.bg] — the accent from the top-left, a cool blue from
/// the top-right, teal on the right and a rose low on the left.
/// The three companions are the accent turned round the colour wheel, so
/// any theme colour gets its own matching set (violet → blue, rose, teal).
/// Softer in the light theme so the cards still lift off it. Static (no
/// ticker), opaque and on its own layer: pages scroll over it for free.
class AmbientLight extends StatelessWidget {
  const AmbientLight({super.key});

  /// The accent moved [degrees] round the wheel, kept rich and mid-light.
  static Color _turn(Color c, double degrees,
      {double sat = 0.85, double light = 0.58}) {
    final h = HSLColor.fromColor(c);
    return h
        .withHue((h.hue + degrees) % 360)
        .withSaturation(sat)
        .withLightness(light)
        .toColor();
  }

  static Widget _light(Alignment at, double radius, Color c, double alpha) =>
      DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: at,
            radius: radius,
            colors: [c.withValues(alpha: alpha), c.withValues(alpha: 0)],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final dark = Neon.isDark;
    final k = dark ? 1.0 : 0.42; // light theme: the same aurora, quieter
    final accent = Neon.violet;
    final blue = _turn(accent, -58, sat: 0.9, light: 0.55);
    final rose = _turn(accent, 52, sat: 0.85, light: 0.6);
    final teal = _turn(accent, -86, sat: 0.8, light: 0.55);
    return IgnorePointer(
      child: RepaintBoundary(
        child: DecoratedBox(
          decoration: BoxDecoration(color: Neon.bg),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _light(const Alignment(-1.0, -1.1), 1.05, accent, 0.30 * k),
              _light(const Alignment(1.15, -0.7), 1.0, blue, 0.28 * k),
              _light(const Alignment(1.15, 0.45), 0.8, teal, 0.17 * k),
              _light(const Alignment(-1.15, 0.85), 0.9, rose, 0.18 * k),
              // A faint sheen across the middle ties the four together.
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.transparent,
                      Colors.white.withValues(alpha: dark ? 0.015 : 0.05),
                      Colors.transparent,
                    ],
                    stops: const [0.3, 0.5, 0.7],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
