import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// HOME CARD EFFECTS (owner, 2026-11-16: "need wow like design and animation
/// or transition effects"). Looping light effects for the Home hero cards:
/// a light that travels round the card's edge and a sheen that sweeps
/// across it now and then.
///
/// Every effect on a card reads ONE controller; each picks its own speed
/// from it with [loopPhase], so a card runs one ticker, not one per effect.
/// The painters repaint from the controller directly, with no rebuild.
///
/// IN BURSTS, NOT FOREVER (2026-11-17, resource audit): a loop that never
/// stopped kept the whole app drawing about 74 frames a second while it sat
/// idle on Home, even with the card scrolled out of view. Now a burst of
/// [loopPeriod] plays when the card appears and a few times after, with
/// [burstRest] between, and then the card holds still and the app draws
/// nothing until something changes. At rest every effect is in its still
/// pose (t = 1). With "Remove animations" on, no burst plays at all.
const Duration loopPeriod = Duration(milliseconds: 2600);

/// The pause between bursts, and how many bursts play in all.
const Duration burstRest = Duration(seconds: 7);
const int burstCount = 3;

/// Where an effect that runs [cycles] times per [loopPeriod] is now (0..1),
/// shifted by [offset] so two cards do not pulse in step.
double loopPhase(double t, int cycles, [double offset = 0]) =>
    (t * cycles + offset) % 1.0;

/// A bright arc of light that travels round a rounded card's edge, over
/// a faint full outline, with a soft glow just inside the edge.
class AuroraBorderPainter extends CustomPainter {
  AuroraBorderPainter({
    required this.t,
    required this.radius,
    required this.color,
    this.width = 1.4,
    this.cycles = 1,
    this.offset = 0,
  }) : super(repaint: t);

  final Animation<double> t;
  final double radius;
  final Color color;
  final double width;
  final int cycles;
  final double offset;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final outer = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    final edge = outer.deflate(width / 2);
    final angle = loopPhase(t.value, cycles, offset) * 2 * math.pi;
    final bright = Color.lerp(color, Colors.white, 0.55)!;

    List<Color> arc(double a) => [
          color.withValues(alpha: 0.10 * a),
          color.withValues(alpha: 0.10 * a),
          bright.withValues(alpha: a),
          color.withValues(alpha: 0.85 * a),
          color.withValues(alpha: 0.10 * a),
        ];
    Shader sweep(double a) => SweepGradient(
          colors: arc(a),
          stops: const [0, 0.55, 0.72, 0.8, 1],
          transform: GradientRotation(angle),
        ).createShader(rect);

    // The glow, inside the card only.
    canvas.save();
    canvas.clipRRect(outer);
    canvas.drawRRect(
      edge,
      Paint()
        ..shader = sweep(0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = width * 7
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );
    canvas.restore();

    // The crisp edge.
    canvas.drawRRect(
      edge,
      Paint()
        ..shader = sweep(1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = width,
    );
  }

  @override
  bool shouldRepaint(AuroraBorderPainter old) =>
      old.color != color || old.radius != radius || old.t != t;
}

/// A diagonal sheen that sweeps across the card for the first [active]
/// part of each cycle and then rests. Draw it clipped to the card.
class ShimmerPainter extends CustomPainter {
  ShimmerPainter({
    required this.t,
    this.cycles = 1,
    this.active = 0.7,
    this.strength = 0.11,
    this.offset = 0,
  }) : super(repaint: t);

  final Animation<double> t;
  final int cycles;
  final double active;
  final double strength;
  final double offset;

  @override
  void paint(Canvas canvas, Size size) {
    final p = loopPhase(t.value, cycles, offset);
    if (p > active) return;
    final k = Curves.easeInOutCubic.transform(p / active);
    final w = size.width;
    final band = w * 0.45;
    final x = -band + k * (w + band * 2);
    final rect = Offset.zero & size;
    final shader = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Colors.white.withValues(alpha: 0),
        Colors.white.withValues(alpha: strength),
        Colors.white.withValues(alpha: 0),
      ],
    ).createShader(Rect.fromLTWH(x - band / 2, 0, band, size.height));
    canvas.drawRect(rect, Paint()..shader = shader..blendMode = BlendMode.plus);
  }

  @override
  bool shouldRepaint(ShimmerPainter old) => old.t != t;
}

/// Plays a card's bursts (see [loopPeriod]) unless "Remove animations" is
/// on. The controller rests at 1, the still pose.
mixin LoopFx<T extends StatefulWidget> on State<T>, SingleTickerProviderStateMixin<T> {
  late final AnimationController loop =
      AnimationController(vsync: this, duration: loopPeriod, value: 1)
        ..addStatusListener(_onStatus);
  Timer? _rest;
  int _played = 0;
  bool _still = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (_still) {
      _rest?.cancel();
      loop.value = 1;
    } else if (!_started) {
      _started = true;
      _burst();
    }
  }

  void _burst() {
    if (!mounted || _still || _played >= burstCount) return;
    _played++;
    loop.forward(from: 0);
  }

  void _onStatus(AnimationStatus s) {
    if (s != AnimationStatus.completed) return;
    _rest?.cancel();
    _rest = Timer(burstRest, _burst);
  }

  @override
  void dispose() {
    _rest?.cancel();
    loop.dispose();
    super.dispose();
  }
}
