import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// THE SPLASH (owner, 2026-11-01: "this image as a splash screen ... the
/// robot's eyes should blink, need exact same image and animation, that
/// circle should spin").
///
/// The owner's logo (assets/splash/logo_source.jpg), cut into layers by
/// tool/make_splash_layers.py: the logo without its ring and eyes (bg),
/// and the ring's and each eye's light on their own. The light is ADDED
/// back (BlendMode.plus), so standing still it is exactly the logo; the
/// ring turns round its centre, passing behind the wordmark, and the eyes
/// blink now and then. With "Remove animations" on, the logo stands still.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  /// The logo's own edge colour (and the native launch screen's).
  static const night = Color(0xFF000000);

  /// Starts decoding the logo's layers (main(), before runApp), so the
  /// splash has them by its first frame instead of showing black for ~1 s
  /// (measured on the owner's phone, 2026-11-01).
  static void precache() => unawaited(_Layers.load().then<void>((_) {}, onError: (Object _) {}));

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

/// Where things are in the 738x1600 source (printed by the layer tool).
class _Geo {
  static const size = Size(738, 1600);
  static const ringCentre = Offset(380.0, 781.7);
  static const ringAt = Offset(128, 529);
  static const textTop = 975.0;
  static const eyeLeftAt = Offset(344, 727);
  static const eyeRightAt = Offset(424, 738);
}

class _Layers {
  _Layers(this.bg, this.ring, this.eyeLeft, this.eyeRight);
  final ui.Image bg, ring, eyeLeft, eyeRight;

  static Future<ui.Image> _load(String name) async {
    final data = await rootBundle.load('assets/splash/$name.png');
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    return (await codec.getNextFrame()).image;
  }

  /// Decoded once per app run; a failed decode may be tried again.
  static Future<_Layers>? _pending;
  static Future<_Layers> load() => _pending ??= () async {
        try {
          final all = await Future.wait(
              [_load('bg'), _load('ring'), _load('eye_left'), _load('eye_right')]);
          return _Layers(all[0], all[1], all[2], all[3]);
        } catch (_) {
          _pending = null;
          rethrow;
        }
      }();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  /// One turn of the ring.
  late final AnimationController _spin =
      AnimationController(vsync: this, duration: const Duration(seconds: 6));

  /// One blink: shut and open again.
  late final AnimationController _blink =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 260));

  /// The logo fading in over the black launch screen.
  late final AnimationController _in =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 450));

  _Layers? _layers;
  Timer? _nextBlink;
  bool _still = false;
  final _rand = math.Random();

  @override
  void initState() {
    super.initState();
    _Layers.load().then((l) {
      if (!mounted) return;
      setState(() => _layers = l);
      _still ? _in.value = 1 : _in.forward();
    }).catchError((Object _) {/* the black screen stays; the app goes on */});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (_still) {
      _spin.stop();
      _blink.value = 0;
      _nextBlink?.cancel();
      _nextBlink = null;
      if (_layers != null) _in.value = 1;
    } else {
      if (!_spin.isAnimating) _spin.repeat();
      _nextBlink ??= _scheduleBlink(first: true);
    }
  }

  /// Blinks every 2.5-4.5 s, now and then twice in a row, like a person.
  Timer _scheduleBlink({bool first = false}) {
    final wait = first ? 900 : 2500 + _rand.nextInt(2000);
    return _nextBlink = Timer(Duration(milliseconds: wait), () async {
      if (!mounted || _still) return;
      await _blink.forward(from: 0);
      if (mounted && !_still && _rand.nextDouble() < 0.25) {
        await Future<void>.delayed(const Duration(milliseconds: 90));
        if (mounted && !_still) await _blink.forward(from: 0);
      }
      if (mounted && !_still) _scheduleBlink();
    });
  }

  @override
  void dispose() {
    _nextBlink?.cancel();
    _spin.dispose();
    _blink.dispose();
    _in.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final layers = _layers;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: SplashScreen.night,
        body: Semantics(
          label: 'My Assistant',
          image: true,
          child: layers == null
              ? const SizedBox.expand()
              : FadeTransition(
                  opacity: _in,
                  child: RepaintBoundary(
                    child: CustomPaint(
                      size: Size.infinite,
                      painter: _LogoPainter(layers, _spin, _blink),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  _LogoPainter(this.layers, this.spin, this.blink)
      : super(repaint: Listenable.merge([spin, blink]));

  final _Layers layers;
  final Animation<double> spin;
  final Animation<double> blink;

  static final _plain = Paint()..filterQuality = FilterQuality.medium;
  static final _light = Paint()
    ..filterQuality = FilterQuality.medium
    ..blendMode = BlendMode.plus;

  /// How shut the eyes are, 0 (open) .. 1 (a thin line): fast down, a
  /// touch slower back up.
  double get _shut {
    final t = blink.value;
    return t < 0.4 ? Curves.easeIn.transform(t / 0.4) : 1 - Curves.easeOut.transform((t - 0.4) / 0.6);
  }

  @override
  void paint(Canvas canvas, Size size) {
    // The logo covers the screen, centred (it is a phone-shaped picture,
    // so on a phone almost nothing is cut).
    final scale = math.max(size.width / _Geo.size.width, size.height / _Geo.size.height);
    canvas.save();
    canvas.translate((size.width - _Geo.size.width * scale) / 2,
        (size.height - _Geo.size.height * scale) / 2);
    canvas.scale(scale);

    canvas.drawImage(layers.bg, Offset.zero, _plain);

    // THE RING, turning. Its light fades out just above the wordmark, so it
    // passes behind "My Assistant" instead of across it.
    final ringBox = Rect.fromLTWH(
        _Geo.ringAt.dx, _Geo.ringAt.dy, layers.ring.width.toDouble(), layers.ring.height.toDouble());
    canvas.saveLayer(ringBox, _light);
    canvas.save();
    canvas.translate(_Geo.ringCentre.dx, _Geo.ringCentre.dy);
    canvas.rotate(spin.value * 2 * math.pi);
    canvas.translate(-_Geo.ringCentre.dx, -_Geo.ringCentre.dy);
    canvas.drawImage(layers.ring, _Geo.ringAt, _plain);
    canvas.restore();
    canvas.drawRect(
      ringBox,
      Paint()
        ..blendMode = BlendMode.dstIn
        ..shader = ui.Gradient.linear(
          const Offset(0, _Geo.textTop - 45),
          const Offset(0, _Geo.textTop),
          const [Color(0xFFFFFFFF), Color(0x00FFFFFF)],
        ),
    );
    canvas.restore();

    // THE EYES, squashed towards their middle as they blink.
    final shut = _shut;
    for (final (img, at) in [
      (layers.eyeLeft, _Geo.eyeLeftAt),
      (layers.eyeRight, _Geo.eyeRightAt),
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
  bool shouldRepaint(_LogoPainter old) =>
      old.layers != layers || old.spin != spin || old.blink != blink;
}
