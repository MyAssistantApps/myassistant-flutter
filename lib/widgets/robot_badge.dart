import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../screens/splash_screen.dart' show LogoGeo, LogoLayers;

/// THE TINY ROBOT (owner, 2026-11-01: "make it stylish and add the same tiny
/// robot there, the same robot we have in the splash screen").
///
/// The splash's own layers (screens/splash_screen.dart), cropped to the
/// ring: the robot in its glowing ring, the ring turning slowly and the
/// eyes blinking now and then — the same picture, only small. With
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
  bool _still = false;
  final _rand = math.Random();

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
    if (_still) {
      _spin.stop();
      _blink.value = 0;
      _next?.cancel();
      _next = null;
    } else {
      if (!_spin.isAnimating) _spin.repeat();
      _next ??= _schedule(first: true);
    }
  }

  Timer _schedule({bool first = false}) => _next = Timer(
        Duration(milliseconds: first ? 1500 : 3000 + _rand.nextInt(2500)),
        () async {
          if (!mounted || _still) return;
          await _blink.forward(from: 0);
          if (mounted && !_still) _schedule();
        },
      );

  @override
  void dispose() {
    _next?.cancel();
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
