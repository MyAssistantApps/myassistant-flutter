import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The night sky behind the horoscope: deep violet gradient, nebula glow,
/// a seeded starfield that twinkles with [t] (0..1, looping), and — when a
/// sign is given — its constellation drawn in glowing gold on the right.
class CosmicPainter extends CustomPainter {
  CosmicPainter({required this.seed, this.signId, this.t = 0, this.constellationBox});

  final int seed;
  final String? signId;
  final double t;

  /// Where the constellation sits, as fractions of the canvas
  /// (left, top, right, bottom). Defaults to the right ~45% of the card.
  final Rect? constellationBox;

  static const gold = Color(0xFFE6C36A);

  // Simplified star patterns (x, y in 0..1) and the lines joining them.
  static const Map<String, (List<Offset>, List<(int, int)>)> constellations = {
    'aries': ([Offset(.1, .6), Offset(.42, .42), Offset(.68, .38), Offset(.9, .5)],
        [(0, 1), (1, 2), (2, 3)]),
    'taurus': ([Offset(.1, .15), Offset(.4, .45), Offset(.55, .55), Offset(.9, .25), Offset(.62, .72), Offset(.35, .86)],
        [(0, 1), (1, 2), (2, 3), (2, 4), (4, 5)]),
    'gemini': ([Offset(.2, .1), Offset(.25, .4), Offset(.3, .7), Offset(.2, .92), Offset(.62, .12), Offset(.64, .42), Offset(.7, .72), Offset(.8, .9)],
        [(0, 1), (1, 2), (2, 3), (4, 5), (5, 6), (6, 7), (0, 4)]),
    'cancer': ([Offset(.5, .14), Offset(.5, .48), Offset(.2, .82), Offset(.8, .84)],
        [(0, 1), (1, 2), (1, 3)]),
    'leo': ([Offset(.32, .14), Offset(.18, .26), Offset(.16, .44), Offset(.3, .56), Offset(.42, .38), Offset(.68, .5), Offset(.9, .64), Offset(.62, .76)],
        [(0, 1), (1, 2), (2, 3), (3, 4), (4, 0), (3, 7), (7, 6), (6, 5), (5, 4)]),
    'virgo': ([Offset(.08, .3), Offset(.3, .38), Offset(.46, .5), Offset(.62, .44), Offset(.88, .3), Offset(.5, .72), Offset(.72, .88), Offset(.28, .82)],
        [(0, 1), (1, 2), (2, 3), (3, 4), (2, 5), (5, 6), (5, 7)]),
    'libra': ([Offset(.5, .12), Offset(.2, .45), Offset(.8, .42), Offset(.28, .84), Offset(.76, .82)],
        [(0, 1), (0, 2), (1, 2), (1, 3), (2, 4)]),
    'scorpio': ([Offset(.1, .18), Offset(.2, .3), Offset(.32, .4), Offset(.44, .48), Offset(.5, .62), Offset(.54, .78), Offset(.68, .9), Offset(.82, .84), Offset(.9, .7)],
        [(0, 1), (1, 2), (2, 3), (3, 4), (4, 5), (5, 6), (6, 7), (7, 8)]),
    'sagittarius': ([Offset(.18, .56), Offset(.34, .4), Offset(.5, .34), Offset(.64, .48), Offset(.56, .7), Offset(.34, .72), Offset(.78, .26), Offset(.86, .62)],
        [(0, 1), (1, 2), (2, 3), (3, 4), (4, 5), (5, 0), (1, 5), (2, 6), (3, 7)]),
    'capricorn': ([Offset(.08, .3), Offset(.3, .24), Offset(.56, .32), Offset(.92, .26), Offset(.76, .6), Offset(.5, .82), Offset(.24, .62)],
        [(0, 1), (1, 2), (2, 3), (3, 4), (4, 5), (5, 6), (6, 0)]),
    'aquarius': ([Offset(.08, .26), Offset(.28, .2), Offset(.44, .32), Offset(.6, .26), Offset(.4, .56), Offset(.56, .7), Offset(.72, .6), Offset(.9, .82)],
        [(0, 1), (1, 2), (2, 3), (2, 4), (4, 5), (5, 6), (6, 7)]),
    'pisces': ([Offset(.08, .2), Offset(.24, .36), Offset(.4, .56), Offset(.52, .82), Offset(.66, .6), Offset(.8, .44), Offset(.92, .34), Offset(.84, .22)],
        [(0, 1), (1, 2), (2, 3), (3, 4), (4, 5), (5, 6), (6, 7)]),
  };

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;

    // Deep night, lighter toward the top-right.
    canvas.drawRect(
      r,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
          colors: [Color(0xFF07041A), Color(0xFF140A38), Color(0xFF2B0F55)],
        ).createShader(r),
    );

    // Nebula glow: three soft clouds of colour.
    void cloud(Offset c, double radius, Color color) {
      canvas.drawCircle(
        c,
        radius,
        Paint()
          ..shader = RadialGradient(colors: [color, color.withValues(alpha: 0)])
              .createShader(Rect.fromCircle(center: c, radius: radius)),
      );
    }

    cloud(Offset(size.width * .82, size.height * .18), size.height * .9,
        const Color(0x667B2FF7));
    cloud(Offset(size.width * .62, size.height * .85), size.height * .7,
        const Color(0x40FF4FA3));
    cloud(Offset(size.width * .08, size.height * .95), size.height * .8,
        const Color(0x332F6BFF));

    // A seeded starfield; each star breathes on its own phase.
    final rnd = math.Random(seed);
    final star = Paint();
    final count = (size.width * size.height / 2200).clamp(40, 140).round();
    for (var i = 0; i < count; i++) {
      final p = Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height);
      final base = rnd.nextDouble();
      final radius = base < .85 ? .5 + rnd.nextDouble() * .7 : 1.1 + rnd.nextDouble() * .8;
      final phase = rnd.nextDouble();
      final tw = .55 + .45 * math.sin((t + phase) * 2 * math.pi);
      star.color = Colors.white.withValues(alpha: (.25 + .6 * base) * tw);
      canvas.drawCircle(p, radius, star);
      if (radius > 1.4) {
        canvas.drawCircle(
            p,
            radius * 3,
            Paint()
              ..color = Colors.white.withValues(alpha: .08 * tw)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
      }
    }

    // The sign's constellation, in glowing gold.
    final c = signId == null ? null : constellations[signId];
    if (c != null) {
      final box = constellationBox ?? const Rect.fromLTRB(.56, .12, .95, .88);
      final area = Rect.fromLTRB(box.left * size.width, box.top * size.height,
          box.right * size.width, box.bottom * size.height);
      // Keep the pattern's proportions: fit a square inside the area.
      final side = math.min(area.width, area.height);
      final o = Offset(area.center.dx - side / 2, area.center.dy - side / 2);
      Offset at(Offset f) => o + Offset(f.dx * side, f.dy * side);

      final glow = Paint()
        ..color = gold.withValues(alpha: .35)
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      final line = Paint()
        ..color = gold.withValues(alpha: .85)
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round;
      for (final (a, b) in c.$2) {
        canvas.drawLine(at(c.$1[a]), at(c.$1[b]), glow);
        canvas.drawLine(at(c.$1[a]), at(c.$1[b]), line);
      }
      final pulse = .8 + .2 * math.sin(t * 2 * math.pi);
      for (final s in c.$1) {
        final p = at(s);
        canvas.drawCircle(
            p,
            9 * pulse,
            Paint()
              ..color = gold.withValues(alpha: .25)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
        canvas.drawCircle(p, 3, Paint()..color = const Color(0xFFFFF1C9));
      }
    }
  }

  @override
  bool shouldRepaint(CosmicPainter old) =>
      old.t != t || old.signId != signId || old.seed != seed;
}
