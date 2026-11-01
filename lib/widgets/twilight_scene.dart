import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../design/motion.dart';
import '../design/neon_tokens.dart';

/// ─────────────────────────────────────────────────────────────────────────
///  THE NIGHT THE APP SITS IN (2026-11-01, the juniors UI pass).
///
///  The client's reference is their "AI Assistant" logo: near-black navy,
///  a ring of neon light running electric blue → violet → magenta, a blue
///  glow on the floor with a swoosh of light, and a four-point sparkle.
///  Two pieces:
///
///   * [TwilightScene] — the still part: the floor glow, the swoosh and a
///     field of faint stars. Drawn once, on the ambient light's own layer,
///     and never again while the page above it scrolls.
///   * [PetalDrift] — the moving part, on its own layer: the neon ring
///     turning slowly, motes of light rising, and sparkles twinkling. The
///     only thing that ticks; it stops with Remove animations, when
///     covered, and on hidden routes (TickerMode).
///
///  (The names are from the first, dusk pass; the widgets are referenced
///  as-is by AmbientBackground.)
///
///  Purely decorative: no pointer, no semantics, no state anyone reads.
/// ─────────────────────────────────────────────────────────────────────────

class TwilightScene extends StatelessWidget {
  const TwilightScene({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Neon.isDark) return const SizedBox.expand();
    return IgnorePointer(
      child: ExcludeSemantics(
        child: CustomPaint(
          painter: _ScenePainter(Neon.cyan, Neon.violet, Neon.pink),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _ScenePainter extends CustomPainter {
  const _ScenePainter(this.cyan, this.blue, this.magenta);
  final Color cyan, blue, magenta;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;

    // 1 — THE FLOOR GLOW: a wide blue light low on the screen, as under
    // the logo's name.
    final floor = Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.80), width: w * 1.6, height: h * 0.40);
    canvas.drawOval(
      floor,
      Paint()
        ..shader = RadialGradient(colors: [
          blue.withValues(alpha: 0.34),
          blue.withValues(alpha: 0.12),
          blue.withValues(alpha: 0),
        ], stops: const [0, 0.45, 1]).createShader(floor),
    );

    // 2 — A MAGENTA HAZE up on the right, a cyan one low on the left: the
    // ring's two ends lighting the room.
    for (final g in [
      (c: Offset(w * 1.0, h * 0.14), r: w * 0.75, col: magenta, a: 0.20),
      (c: Offset(w * 0.0, h * 0.46), r: w * 0.70, col: cyan, a: 0.14),
    ]) {
      final rect = Rect.fromCircle(center: g.c, radius: g.r);
      canvas.drawOval(
        rect,
        Paint()
          ..shader = RadialGradient(colors: [
            g.col.withValues(alpha: g.a),
            g.col.withValues(alpha: 0),
          ]).createShader(rect),
      );
    }

    // 3 — THE SWOOSH: a thin arc of light across the floor glow, bright
    // in the middle and fading at both ends.
    final swoosh = Path()
      ..moveTo(w * 0.12, h * 0.835)
      ..quadraticBezierTo(w * 0.50, h * 0.795, w * 0.88, h * 0.815);
    final sRect = Rect.fromLTWH(w * 0.12, h * 0.79, w * 0.76, h * 0.05);
    final fadeEnds = LinearGradient(colors: [
      cyan.withValues(alpha: 0),
      cyan,
      magenta,
      magenta.withValues(alpha: 0),
    ], stops: const [0, 0.35, 0.75, 1]);
    for (final s in [(wd: 10.0, a: 0.10), (wd: 4.0, a: 0.30), (wd: 1.6, a: 0.85)]) {
      canvas.drawPath(
        swoosh,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = s.wd
          ..shader = LinearGradient(colors: [
            for (final c in fadeEnds.colors) c.withValues(alpha: c.a * s.a),
          ], stops: fadeEnds.stops).createShader(sRect),
      );
    }

    // 4 — STARS: faint and fixed, so the scene is drawn once.
    final rnd = math.Random(7);
    final star = Paint();
    for (var i = 0; i < 60; i++) {
      final x = rnd.nextDouble() * w;
      final y = rnd.nextDouble() * h * 0.7;
      final r = 0.4 + rnd.nextDouble() * 0.9;
      final a = 0.15 + rnd.nextDouble() * 0.45;
      star.color = Color.lerp(Colors.white, cyan, rnd.nextDouble() * 0.4)!
          .withValues(alpha: a);
      canvas.drawCircle(Offset(x, y), r, star);
    }
  }

  @override
  bool shouldRepaint(_ScenePainter old) =>
      old.cyan != cyan || old.blue != blue || old.magenta != magenta;
}

/// THE RING, THE MOTES AND THE SPARKLES — the moving light.
class PetalDrift extends StatefulWidget {
  const PetalDrift({super.key, this.count = 18});

  /// How many motes of light.
  final int count;

  @override
  State<PetalDrift> createState() => _PetalDriftState();
}

class _PetalDriftState extends State<PetalDrift>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final ValueNotifier<double> _t = ValueNotifier(0);
  late final List<_Mote> _motes;

  @override
  void initState() {
    super.initState();
    final rnd = math.Random(42);
    _motes = List.generate(widget.count, (_) => _Mote.random(rnd));
    _ticker = createTicker((e) => _t.value = e.inMicroseconds / 1e6);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = Motion.reduced(context) || !Neon.isDark;
    if (still && _ticker.isActive) _ticker.stop();
    if (!still && !_ticker.isActive) _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!Neon.isDark) return const SizedBox.expand();
    // With Remove animations the ring still shows, just still (t = 0).
    return IgnorePointer(
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: CustomPaint(
            painter: _LightPainter(
              motes: _motes,
              t: _t,
              cyan: Neon.cyan,
              blue: Neon.violet,
              magenta: Neon.pink,
              still: Motion.reduced(context),
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

class _Mote {
  _Mote.random(math.Random r)
      : x = r.nextDouble(),
        phase = r.nextDouble(),
        speed = 0.018 + r.nextDouble() * 0.03,
        sway = 6 + r.nextDouble() * 16,
        swayRate = 0.4 + r.nextDouble() * 0.7,
        size = 1.2 + r.nextDouble() * 2.2,
        hue = r.nextDouble(),
        alpha = 0.35 + r.nextDouble() * 0.5;

  final double x, phase, speed, sway, swayRate, size, hue, alpha;
}

class _LightPainter extends CustomPainter {
  _LightPainter({
    required this.motes,
    required this.t,
    required this.cyan,
    required this.blue,
    required this.magenta,
    required this.still,
  }) : super(repaint: t);

  final List<_Mote> motes;
  final ValueNotifier<double> t;
  final Color cyan, blue, magenta;
  final bool still;

  /// cyan → blue → magenta, as the ring runs.
  Color _along(double v) => v < 0.5
      ? Color.lerp(cyan, blue, v * 2)!
      : Color.lerp(blue, magenta, (v - 0.5) * 2)!;

  @override
  void paint(Canvas canvas, Size size) {
    final now = still ? 0.0 : t.value;
    final w = size.width, h = size.height;

    // 1 — THE NEON RING, up on the right and partly off the screen,
    // its light turning slowly round it (one turn in ~24 s) and
    // breathing a little. Glow from layered strokes, not a blur, so it
    // stays cheap at 60 fps.
    final centre = Offset(w * 0.86, h * 0.20);
    final radius = w * 0.46;
    final rect = Rect.fromCircle(center: centre, radius: radius);
    final breathe = 0.85 + 0.15 * math.sin(now * 0.9);
    final sweep = SweepGradient(
      transform: GradientRotation(now * (2 * math.pi / 24)),
      colors: [cyan, blue, magenta, blue.withValues(alpha: 0.2), cyan],
      stops: const [0, 0.3, 0.55, 0.8, 1],
    );
    for (final s in [
      (wd: 18.0, a: 0.06),
      (wd: 8.0, a: 0.16),
      (wd: 3.0, a: 0.45),
      (wd: 1.2, a: 0.9),
    ]) {
      canvas.drawCircle(
        centre,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s.wd
          ..shader = sweep.createShader(rect)
          ..color = Colors.white.withValues(alpha: s.a * breathe),
      );
    }
    // A bright head of light travelling round the ring.
    final head = centre +
        Offset.fromDirection(now * (2 * math.pi / 9) + math.pi * 0.7, radius);
    canvas.drawCircle(
      head,
      9,
      Paint()
        ..shader = RadialGradient(colors: [
          Colors.white.withValues(alpha: 0.9 * breathe),
          cyan.withValues(alpha: 0.45),
          cyan.withValues(alpha: 0),
        ], stops: const [0, 0.35, 1])
            .createShader(Rect.fromCircle(center: head, radius: 9)),
    );

    // 2 — MOTES OF LIGHT rising slowly, swaying, fading in and out.
    final dot = Paint();
    for (final m in motes) {
      final f = (m.phase + now * m.speed) % 1.0;
      final y = h + 20 - f * (h + 40);
      final x = m.x * w + math.sin(now * m.swayRate + m.phase * 6.28) * m.sway;
      final fade = f < 0.1 ? f / 0.1 : (f > 0.85 ? (1 - f) / 0.15 : 1.0);
      final c = _along(m.hue);
      final r = m.size * 3;
      dot.shader = RadialGradient(colors: [
        Colors.white.withValues(alpha: m.alpha * fade),
        c.withValues(alpha: m.alpha * fade * 0.55),
        c.withValues(alpha: 0),
      ], stops: const [0, 0.3, 1])
          .createShader(Rect.fromCircle(center: Offset(x, y), radius: r));
      canvas.drawCircle(Offset(x, y), r, dot);
    }
    dot.shader = null;

    // 3 — SPARKLES: four-point stars, as by the logo's name, each
    // swelling and fading on its own beat.
    final rnd = math.Random(5);
    for (var i = 0; i < 7; i++) {
      final sx = rnd.nextDouble() * w;
      final sy = rnd.nextDouble() * h * 0.6;
      final rate = 0.5 + rnd.nextDouble() * 0.9;
      final v = 0.5 + 0.5 * math.sin(now * rate + i * 1.9);
      final a = still ? 0.6 : v;
      final r = 2.5 + 5.5 * a;
      final c = _along(rnd.nextDouble());
      final star = Path()
        ..moveTo(sx, sy - r)
        ..quadraticBezierTo(sx, sy, sx + r * 0.75, sy)
        ..quadraticBezierTo(sx, sy, sx, sy + r)
        ..quadraticBezierTo(sx, sy, sx - r * 0.75, sy)
        ..quadraticBezierTo(sx, sy, sx, sy - r)
        ..close();
      canvas.drawCircle(
        Offset(sx, sy),
        r * 1.6,
        Paint()
          ..shader = RadialGradient(colors: [
            c.withValues(alpha: 0.35 * a),
            c.withValues(alpha: 0),
          ]).createShader(Rect.fromCircle(center: Offset(sx, sy), radius: r * 1.6)),
      );
      canvas.drawPath(
          star,
          Paint()
            ..color = Color.lerp(Colors.white, c, 0.25)!
                .withValues(alpha: 0.25 + 0.7 * a));
    }
  }

  @override
  bool shouldRepaint(_LightPainter old) =>
      old.cyan != cyan ||
      old.blue != blue ||
      old.magenta != magenta ||
      old.still != still;
}
