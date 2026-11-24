import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../screens/splash_screen.dart' show LogoGeo, LogoLayers;

/// THE TINY ROBOT (owner, 2026-11-01: "make it stylish and add the same tiny
/// robot there, the same robot we have in the splash screen").
///
/// The splash's own layers (screens/splash_screen.dart), cropped to the
/// ring: the robot in its glowing ring, the ring turning slowly (for a few
/// seconds at a time) and the eyes blinking now and then — the same picture, only small. With
/// "Remove animations" on it stands still.
class RobotBadge extends StatefulWidget {
  const RobotBadge({super.key, this.size = 52});
  final double size;

  @override
  State<RobotBadge> createState() => _RobotBadgeState();
}

class _RobotBadgeState extends State<RobotBadge> with TickerProviderStateMixin {
  late final AnimationController _spin =
      AnimationController(vsync: this, duration: const Duration(seconds: 9));
  late final AnimationController _blink =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 260));
  LogoLayers? _layers;
  Timer? _next;
  Timer? _rest;
  bool _still = false;
  bool _seen = true;
  ScrollPosition? _scroll;
  final _rand = math.Random();

  /// HOW LONG THE RING TURNS (2026-11-24, measured on an RMX5003): a ring
  /// turning for ever made Flutter draw the whole screen 60–120 times a
  /// second with nobody touching it — on that phone 9–12 ms a frame, over
  /// the 8.3 ms a 120 Hz frame has, so Home stuttered and the battery ran
  /// down. It now turns while it is first seen (and each time it comes back
  /// into view), then rests; it never turns off screen. The blink stays.
  static const _turnFor = Duration(seconds: 8);

  @override
  void initState() {
    super.initState();
    LogoLayers.load().then((l) {
      if (mounted) setState(() => _layers = l);
    }).catchError((Object _) {/* the badge stays empty; the title stands */});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final scroll = Scrollable.maybeOf(context)?.position;
    if (scroll != _scroll) {
      _scroll?.removeListener(_whereAmI);
      _scroll = scroll?..addListener(_whereAmI);
    }
    if (_still) {
      _spin.stop();
      _rest?.cancel();
      _blink.value = 0;
      _next?.cancel();
      _next = null;
    } else {
      _turn();
      _next ??= _schedule(first: true);
    }
  }

  /// Turn the ring for [_turnFor], then rest.
  void _turn() {
    if (_still || !_seen) return;
    if (!_spin.isAnimating) _spin.repeat();
    _rest?.cancel();
    _rest = Timer(_turnFor, () {
      if (mounted) _spin.stop(canceled: false);
    });
  }

  /// On a scroll: is the badge on screen? Off it, nothing turns or blinks.
  void _whereAmI() {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return;
    final top = box.localToGlobal(Offset.zero).dy;
    final seen = top + box.size.height > 0 && top < MediaQuery.sizeOf(context).height;
    if (seen == _seen) return;
    _seen = seen;
    if (seen) {
      _turn();
    } else {
      _spin.stop(canceled: false);
      _rest?.cancel();
    }
  }

  Timer _schedule({bool first = false}) => _next = Timer(
        Duration(milliseconds: first ? 1500 : 3000 + _rand.nextInt(2500)),
        () async {
          if (!mounted || _still) return;
          if (_seen && TickerMode.valuesOf(context).enabled) await _blink.forward(from: 0);
          if (mounted && !_still) _schedule();
        },
      );

  @override
  void dispose() {
    _next?.cancel();
    _rest?.cancel();
    _scroll?.removeListener(_whereAmI);
    _spin.dispose();
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final layers = _layers;
    return Semantics(
      image: true,
      label: 'MyAssistant robot',
      child: SizedBox.square(
        dimension: widget.size,
        child: layers == null
            ? null
            : RepaintBoundary(
                child: CustomPaint(painter: _BadgePainter(layers, _spin, _blink)),
              ),
      ),
    );
  }
}

class _BadgePainter extends CustomPainter {
  _BadgePainter(this.layers, this.spin, this.blink)
      : super(repaint: Listenable.merge([spin, blink]));

  final LogoLayers layers;
  final Animation<double> spin;
  final Animation<double> blink;

  static final _plain = Paint()..filterQuality = FilterQuality.medium;
  static final _light = Paint()
    ..filterQuality = FilterQuality.medium
    ..blendMode = BlendMode.plus;

  double get _shut {
    final t = blink.value;
    return t < 0.4 ? Curves.easeIn.transform(t / 0.4) : 1 - Curves.easeOut.transform((t - 0.4) / 0.6);
  }

  @override
  void paint(Canvas canvas, Size size) {
    // The ring's square in the source, scaled to the badge.
    final box = Rect.fromLTWH(LogoGeo.ringAt.dx, LogoGeo.ringAt.dy,
        layers.ring.width.toDouble(), layers.ring.height.toDouble());
    final scale = size.width / box.width;
    canvas.save();
    canvas.clipPath(Path()..addOval(Offset.zero & size));
    canvas.scale(scale);
    canvas.translate(-box.left, -box.top);

    // The logo's night behind it, then the picture fading out just above
    // the wordmark (the letters start at y=986 in the source; only the
    // robot and its ring belong in the badge).
    canvas.drawRect(box, Paint()..color = const Color(0xFF05061A));
    canvas.saveLayer(box, Paint());
    canvas.drawImageRect(layers.bg, box, box, _plain);
    canvas.drawRect(
      box,
      Paint()
        ..blendMode = BlendMode.dstIn
        ..shader = ui.Gradient.linear(
          const Offset(0, LogoGeo.textTop - 60),
          const Offset(0, LogoGeo.textTop - 5),
          const [Color(0xFFFFFFFF), Color(0x00FFFFFF)],
        ),
    );
    canvas.restore();

    canvas.saveLayer(box, _light);
    canvas.translate(LogoGeo.ringCentre.dx, LogoGeo.ringCentre.dy);
    canvas.rotate(spin.value * 2 * math.pi);
    canvas.translate(-LogoGeo.ringCentre.dx, -LogoGeo.ringCentre.dy);
    canvas.drawImage(layers.ring, LogoGeo.ringAt, _plain);
    canvas.restore();

    final shut = _shut;
    for (final (img, at) in [
      (layers.eyeLeft, LogoGeo.eyeLeftAt),
      (layers.eyeRight, LogoGeo.eyeRightAt),
    ]) {
      final c = at + Offset(img.width / 2, img.height / 2);
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.scale(1, 1 - 0.9 * shut);
      canvas.translate(-c.dx, -c.dy);
      canvas.drawImage(img, at, _light);
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BadgePainter old) => old.layers != layers;
}
