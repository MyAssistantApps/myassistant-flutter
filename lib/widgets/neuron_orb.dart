import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../design/motion.dart';
import 'voice_orb.dart' show OrbMood;

/// ─────────────────────────────────────────────────────────────────────
///  THE NEURON ORB (2026-11-02, Karthik's reference "Your Jarvis needs a
///  face"): a ball of glowing particles wired together like neurons,
///  turning slowly in 3D, with signals running along the wires.
///
///  It is the assistant's face on the talking page and only ever SHOWS the
///  state it is given (the same [OrbMood] and voice levels the old rings
///  read) — it decides nothing:
///   * idle / paused — small, breathing slowly;
///   * listening     — grows and ripples with his voice;
///   * thinking      — twists into a spinning ring of neurons;
///   * responding    — half ring, half lumpy ball, turning faster;
///   * speaking      — swells with her voice and morphs between the ball
///                     and flowing sound waves;
///   * connecting    — a ring forming, pulsing;
///   * done          — one pop.
///  Its colours follow the time of day ([NeuronPalette.at]).
///  With "Remove animations" it is one still picture.
/// ─────────────────────────────────────────────────────────────────────

/// The orb's two colours at a time of day: [a] lights the top of the ball,
/// [b] the bottom. Changes smoothly through the day.
@immutable
class NeuronPalette {
  const NeuronPalette(this.a, this.b);
  final Color a, b;

  static const _night = (Color(0xFF9B7BFF), Color(0xFF3D5AFE));
  static const _dawn = (Color(0xFFFFB38A), Color(0xFFFF5FA2));
  static const _morning = (Color(0xFF5CE1FF), Color(0xFF4C7DFF));
  static const _afternoon = (Color(0xFF3DF2C8), Color(0xFF3D8BFF));
  static const _sunset = (Color(0xFFFFA24C), Color(0xFFE040FB));
  static const _evening = (Color(0xFFFF7AD9), Color(0xFF9B6BFF));

  /// Hour of day → colours. Each look holds for a while, then blends into
  /// the next.
  static const List<(double, (Color, Color))> _stops = [
    (0, _night),
    (5, _night),
    (6.5, _dawn),
    (8, _dawn),
    (9.5, _morning),
    (13, _morning),
    (14.5, _afternoon),
    (16.5, _afternoon),
    (18, _sunset),
    (19, _sunset),
    (20.5, _evening),
    (22, _evening),
    (23.5, _night),
    (24, _night),
  ];

  static NeuronPalette at(DateTime t) {
    final h = t.hour + t.minute / 60 + t.second / 3600;
    for (var i = 0; i < _stops.length - 1; i++) {
      final (h0, c0) = _stops[i];
      final (h1, c1) = _stops[i + 1];
      if (h >= h0 && h <= h1) {
        final k = h1 == h0 ? 0.0 : Curves.easeInOut.transform((h - h0) / (h1 - h0));
        return NeuronPalette(Color.lerp(c0.$1, c1.$1, k)!, Color.lerp(c0.$2, c1.$2, k)!);
      }
    }
    return NeuronPalette(_night.$1, _night.$2);
  }

  @override
  bool operator ==(Object other) =>
      other is NeuronPalette && other.a == a && other.b == b;

  @override
  int get hashCode => Object.hash(a, b);
}

class NeuronOrb extends StatefulWidget {
  const NeuronOrb({
    super.key,
    required this.radius,
    this.mood = OrbMood.idle,
    this.levelListenable,
    this.speakerLevel,
    this.active = true,
    this.clock = DateTime.now,
  });

  /// The ball's radius at rest; it swells to about 1.35× of it.
  final double radius;
  final OrbMood mood;

  /// His mic's loudness (0..1), read on every frame while listening.
  final ValueListenable<double>? levelListenable;

  /// Her voice's loudness (0..1), asked on every frame while she speaks.
  final double Function()? speakerLevel;

  /// False while its screen is hidden: it holds still and costs nothing.
  final bool active;

  /// Test seam: the time of day the colours are for.
  final DateTime Function() clock;

  @override
  State<NeuronOrb> createState() => _NeuronOrbState();
}

/// What the painter reads each frame. The ticker changes it and the
/// painter repaints its own layer — no widget rebuilds for a frame.
class _Scene extends ChangeNotifier {
  double sec = 0;
  double spin = 0;
  double scale = 0.8, amp = 0.03, wave = 0, ring = 0, bright = 0.8;
  double energy = 0;

  /// The ball's size as a spring (velocity [scaleV]): it overshoots and
  /// settles, so a loud word reads as a bounce, not a fade.
  double scaleV = 0;

  /// The level heard on the last frame — a sudden rise is a new syllable
  /// and kicks the spring.
  double lastDrive = 0;
  double pop = 1; // seconds since "done"; ≥1: none running
  double appear = 0;
  NeuronPalette palette = NeuronPalette.at(DateTime.now());

  void changed() => notifyListeners();
}

class _NeuronOrbState extends State<NeuronOrb>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onTick);
  Duration _last = Duration.zero;
  final _Scene _scene = _Scene();
  bool _still = false;
  double _paletteAge = 0;

  bool get _moving => widget.active && widget.mood != OrbMood.paused && !_still;

  @override
  void initState() {
    super.initState();
    _scene.palette = NeuronPalette.at(widget.clock());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = Motion.reduced(context);
    _sync();
  }

  @override
  void didUpdateWidget(NeuronOrb old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) _scene.appear = 0;
    if (widget.mood == OrbMood.done && old.mood != OrbMood.done) _scene.pop = 0;
    _scene.palette = NeuronPalette.at(widget.clock());
    _sync();
  }

  void _sync() {
    if (_moving && !_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    } else if (!_moving && _ticker.isActive) {
      _ticker.stop();
    }
    if (!_moving) {
      // Hold one calm picture (Remove animations, paused, hidden).
      final s = _scene
        ..appear = 1
        ..energy = 0
        ..wave = 0
        ..ring = 0
        ..amp = 0.03
        ..scale = 0.8
        ..scaleV = 0
        ..lastDrive = 0
        ..bright = 0.85;
      s.changed();
    }
  }

  double _heard() {
    final w = widget;
    final double l = switch (w.mood) {
      OrbMood.speaking => w.speakerLevel?.call() ?? w.levelListenable?.value ?? 0,
      OrbMood.listening => w.levelListenable?.value ?? 0,
      _ => 0.0,
    };
    return l.isFinite ? l.clamp(0.0, 1.0) : 0.0;
  }

  static double _ease(double v, double to, double rate, double dt) =>
      v + (to - v) * (1 - math.exp(-dt * rate));

  void _onTick(Duration elapsed) {
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.1);
    _last = elapsed;
    final s = _scene;
    s.sec += dt;
    s.appear = math.min(1, s.appear + dt / 0.45);
    if (s.pop < 1) s.pop = math.min(1, s.pop + dt);

    _paletteAge += dt;
    if (_paletteAge > 5) {
      _paletteAge = 0;
      s.palette = NeuronPalette.at(widget.clock());
    }

    // LOUDER IS BIGGER (2026-11-02, Karthik: "more reactive… the louder I
    // speak the circle should grow"; then 15%, then 30% calmer). Below 2% is silence; the curve lifts
    // quiet speech so it still shows, and her voice gets a little gain —
    // the speaker's level runs lower than the mic's.
    final heard = _heard() *
        (widget.mood == OrbMood.speaking ? 1.6 : 1.0);
    final h = heard.clamp(0.0, 1.0);
    final drive = h <= 0.02 ? 0.0 : math.pow((h - 0.02) / 0.98, 0.5).toDouble();
    // Fast up, slower down: it jumps with a word and sinks after it.
    s.energy = _ease(s.energy, drive, drive > s.energy ? 40 : 5, dt);
    final e = s.energy;
    final rise = drive - s.lastDrive;
    s.lastDrive = drive;

    // What each mood is aiming for.
    double scale, amp, wave = 0, ring = 0, spinRate, bright = 1;
    switch (widget.mood) {
      case OrbMood.idle:
      case OrbMood.paused:
        scale = 0.80 + 0.03 * math.sin(s.sec * 2 * math.pi / 4.5);
        amp = 0.025;
        spinRate = 0.18;
        bright = 0.8;
      case OrbMood.listening:
        scale = 0.84 + 0.46 * e;
        amp = 0.05 + 0.20 * e;
        spinRate = 0.3 + 0.83 * e;
        bright = 0.9 + 0.30 * e;
      case OrbMood.thinking:
        scale = 0.84 + 0.04 * math.sin(s.sec * 2 * math.pi / 2.2);
        amp = 0.06;
        ring = 1;
        spinRate = 1.3;
      case OrbMood.responding:
        scale = 0.86;
        amp = 0.10;
        ring = 0.45;
        spinRate = 0.9;
      case OrbMood.speaking:
        // Ball and waves take turns (~3.5 s each), the voice swelling both.
        final phase = 0.5 - 0.5 * math.cos(s.sec * 2 * math.pi / 7);
        wave = Curves.easeInOut.transform(((phase - 0.2) / 0.6).clamp(0.0, 1.0));
        scale = 0.86 + 0.43 * e;
        amp = 0.05 + 0.20 * e;
        spinRate = 0.35 + 0.71 * e;
        bright = 0.9 + 0.30 * e;
      case OrbMood.done:
        scale = 0.84;
        amp = 0.05;
        spinRate = 0.3;
      case OrbMood.connecting:
        scale = 0.74 + 0.05 * math.sin(s.sec * 2 * math.pi / 1.1);
        amp = 0.05;
        ring = 0.6;
        spinRate = 1.0;
    }
    if (s.pop < 1) scale += 0.14 * math.sin(math.pi * s.pop);

    // The size is a bouncy spring (~3 Hz, light damping); a sudden rise in
    // the voice — a new word — kicks it outward.
    final talking =
        widget.mood == OrbMood.listening || widget.mood == OrbMood.speaking;
    if (talking && rise > 0.08) s.scaleV += 1.9 * rise;
    const k = (2 * math.pi * 2.4) * (2 * math.pi * 2.4);
    final c = 2 * 0.30 * math.sqrt(k);
    final steps = (dt * 240).ceil().clamp(1, 24);
    final hstep = dt / steps;
    for (var i = 0; i < steps; i++) {
      s.scaleV += (k * (scale - s.scale) - c * s.scaleV) * hstep;
      s.scale += s.scaleV * hstep;
    }
    s.amp = _ease(s.amp, amp, 8, dt);
    s.wave = _ease(s.wave, wave, 3.2, dt);
    s.ring = _ease(s.ring, ring, 3.0, dt);
    s.bright = _ease(s.bright, bright, 10, dt);
    s.spin = (s.spin + dt * spinRate) % (2 * math.pi);
    s.changed();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _scene.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: CustomPaint(
          painter: _NeuronPainter(_scene, widget.radius),
          child: const SizedBox.expand(),
        ),
      );
}

/// The ball's particles and wires, made once for the app's life.
class _Cloud {
  _Cloud._(this.n) {
    ux = Float32List(n);
    uy = Float32List(n);
    uz = Float32List(n);
    lon = Float32List(n);
    lat = Float32List(n);
    seed = Float32List(n);
    final golden = math.pi * (3 - math.sqrt(5));
    final rnd = math.Random(7);
    for (var i = 0; i < n; i++) {
      final y = 1 - (i + 0.5) / n * 2;
      final r = math.sqrt(1 - y * y);
      final th = golden * i;
      ux[i] = math.cos(th) * r;
      uy[i] = y;
      uz[i] = math.sin(th) * r;
      lon[i] = math.atan2(uz[i], ux[i]);
      lat[i] = math.asin(y);
      seed[i] = rnd.nextDouble();
    }
    // Wires: each particle to its two nearest neighbours.
    final seen = <int>{};
    final pairs = <int>[];
    for (var i = 0; i < n; i++) {
      var b1 = -1, b2 = -1;
      var d1 = 9.0, d2 = 9.0;
      for (var j = 0; j < n; j++) {
        if (j == i) continue;
        final dx = ux[i] - ux[j], dy = uy[i] - uy[j], dz = uz[i] - uz[j];
        final d = dx * dx + dy * dy + dz * dz;
        if (d < d1) {
          d2 = d1;
          b2 = b1;
          d1 = d;
          b1 = j;
        } else if (d < d2) {
          d2 = d;
          b2 = j;
        }
      }
      for (final j in [b1, b2]) {
        if (j < 0) continue;
        final key = i < j ? i * n + j : j * n + i;
        if (seen.add(key)) {
          pairs
            ..add(math.min(i, j))
            ..add(math.max(i, j));
        }
      }
    }
    edges = Int32List.fromList(pairs);
  }

  static final _Cloud instance = _Cloud._(900);

  final int n;
  late final Float32List ux, uy, uz, lon, lat, seed;
  late final Int32List edges;

  /// Every [hubEvery]th particle is a bright neuron body.
  static const int hubEvery = 14;
}

const int _depthBands = 3, _colorBands = 3;

class _NeuronPainter extends CustomPainter {
  _NeuronPainter(this.scene, this.radius) : super(repaint: scene) {
    final n = _cloud.n;
    _sx = Float32List(n);
    _sy = Float32List(n);
    _sz = Float32List(n);
    for (var i = 0; i < _depthBands * _colorBands; i++) {
      _pts.add(Float32List(n * 2));
      _cnt.add(0);
    }
    for (var i = 0; i < _depthBands; i++) {
      _hubs.add(Float32List(n * 2));
      _hubCnt.add(0);
      _lines.add(Float32List(_cloud.edges.length * 2));
      _lineCnt.add(0);
    }
  }

  final _Scene scene;
  final double radius;
  final _Cloud _cloud = _Cloud.instance;

  late final Float32List _sx, _sy, _sz;
  final List<Float32List> _pts = [], _hubs = [], _lines = [];
  final List<int> _cnt = [], _hubCnt = [], _lineCnt = [];
  final Float32List _sparks = Float32List(18 * 2);

  final Paint _p = Paint()
    ..strokeCap = StrokeCap.round
    ..isAntiAlias = true;
  final Paint _fill = Paint();

  @override
  void paint(Canvas canvas, Size size) {
    final s = scene;
    final c = _cloud;
    final n = c.n;
    final cx = size.width / 2, cy = size.height / 2;
    final R = radius * s.scale;
    final t = s.sec;
    final pal = s.palette;
    final fade = s.appear;
    if (fade <= 0) return;

    // THE GLOW behind the ball, and its faint body.
    _fill.shader = ui.Gradient.radial(
      Offset(cx, cy),
      R * 1.75,
      [
        pal.a.withValues(alpha: (0.30 * s.bright * fade).clamp(0.0, 0.6)),
        pal.b.withValues(alpha: (0.12 * s.bright * fade).clamp(0.0, 0.3)),
        pal.b.withValues(alpha: 0),
      ],
      const [0.0, 0.5, 1.0],
    );
    canvas.drawCircle(Offset(cx, cy), R * 1.75, _fill);
    // The drop's body: a soft translucent fill, and a shine up and left.
    _fill.shader = ui.Gradient.radial(
      Offset(cx, cy),
      R * 1.08,
      [
        pal.a.withValues(alpha: 0.16 * fade),
        pal.b.withValues(alpha: 0.09 * fade),
        pal.b.withValues(alpha: 0),
      ],
      const [0.0, 0.78, 1.0],
    );
    canvas.drawCircle(Offset(cx, cy), R * 1.08, _fill);
    final shine = Offset(cx - 0.34 * R, cy - 0.40 * R);
    _fill.shader = ui.Gradient.radial(
      shine,
      R * 0.5,
      [
        Colors.white.withValues(alpha: 0.13 * fade),
        Colors.white.withValues(alpha: 0),
      ],
    );
    canvas.drawCircle(shine, R * 0.5, _fill);

    // Where every particle is this frame.
    final wave = s.wave, ring = s.ring.clamp(0.0, 1.0 - wave);
    final sphere = 1 - wave - ring;
    final cs = math.cos(s.spin), sn = math.sin(s.spin);
    const tilt = 0.32;
    final ct = math.cos(tilt), st = math.sin(tilt);
    final amp = s.amp, e = s.energy;
    // THE WATER (2026-11-02, Karthik: "more circle and water type liquid
    // … this is too rigid"): the particles drift in slow currents round
    // the drop, its outline wobbles only in big soft modes, and fine
    // ripples run across the surface — stronger with the voice.
    final ripAmp = 0.006 + 0.021 * e;
    for (var i = 0; i < n; i++) {
      final uy = c.uy[i];
      final fl = 0.45 * math.sin(c.lat[i] * 2.0 + t * 0.55) + 0.25 * t;
      final cf = math.cos(fl), sf = math.sin(fl);
      final ux = c.ux[i] * cf - c.uz[i] * sf;
      final uz = c.ux[i] * sf + c.uz[i] * cf;
      double x = 0, y = 0, z = 0;
      if (sphere > 0.001 || ring > 0.001) {
        double bx = 0, by = 0, bz = 0;
        if (sphere > 0.001) {
          // A drop of water: big slow wobbles, fine running ripples.
          final wob = 0.75 *
                  math.sin(1.7 * ux + 1.1 * t) *
                  math.cos(1.4 * uy - 0.8 * t) +
              0.55 *
                  math.sin(1.5 * uz - 0.9 * t + 1.3) *
                  math.cos(1.3 * ux + 0.6 * t);
          final rip = math.sin(7.0 * (0.6 * ux + 0.8 * uy) - 3.0 * t) +
              math.sin(6.0 * (0.7 * uz - 0.7 * ux) - 2.4 * t);
          final d = amp * wob +
              ripAmp * 0.5 * rip +
              0.004 * math.sin(t * 1.3 + c.seed[i] * 6.28);
          final r = 1 + d;
          bx += ux * r * sphere;
          by += uy * r * sphere;
          bz += uz * r * sphere;
        }
        if (ring > 0.001) {
          // A ring of neurons, its tube flowing.
          final minor = c.lat[i] * 2 + t * 1.6;
          final rr = 0.92 + 0.24 * math.cos(minor);
          bx += math.cos(c.lon[i]) * rr * ring;
          by += 0.24 * math.sin(minor) * ring;
          bz += math.sin(c.lon[i]) * rr * ring;
        }
        // Turned and tilted toward him.
        final rx = bx * cs + bz * sn;
        final rz = -bx * sn + bz * cs;
        final ry = by * ct - rz * st;
        final rz2 = by * st + rz * ct;
        x = rx;
        y = ry;
        z = rz2;
      }
      if (wave > 0.001) {
        // Sound waves: the ball unrolled into flowing strands.
        final wx = c.lon[i] / math.pi * 1.55;
        final strand = c.lat[i] / (math.pi / 2);
        final ph = wx * 2.6 - t * 3.6 + strand * 1.5;
        final env = 1 - 0.45 * wx.abs() / 1.55;
        final wy = strand * 0.30 + math.sin(ph) * (0.15 + 0.37 * e) * env;
        final wz = math.cos(ph) * 0.3;
        x += wx * wave;
        y += wy * wave;
        z += wz * wave;
      }
      const persp = 3.2;
      final f = persp / (persp - z);
      _sx[i] = cx + x * R * f;
      _sy[i] = cy - y * R * f;
      _sz[i] = z;
    }

    // Sort into depth and colour bands (one draw call each).
    for (var i = 0; i < _cnt.length; i++) {
      _cnt[i] = 0;
    }
    for (var i = 0; i < _depthBands; i++) {
      _hubCnt[i] = 0;
      _lineCnt[i] = 0;
    }
    int depthOf(double z) {
      final d = ((z + 1.2) / 2.4 * _depthBands).floor();
      return d < 0 ? 0 : (d >= _depthBands ? _depthBands - 1 : d);
    }

    for (var i = 0; i < n; i++) {
      final d = depthOf(_sz[i]);
      if (i % _Cloud.hubEvery == 0) {
        final k = _hubCnt[d];
        _hubs[d][k * 2] = _sx[i];
        _hubs[d][k * 2 + 1] = _sy[i];
        _hubCnt[d] = k + 1;
      }
      final cb = (((c.uy[i] + 1) / 2) * _colorBands).floor().clamp(0, _colorBands - 1);
      final b = d * _colorBands + cb;
      final k = _cnt[b];
      _pts[b][k * 2] = _sx[i];
      _pts[b][k * 2 + 1] = _sy[i];
      _cnt[b] = k + 1;
    }
    final maxLen = 0.5 * R;
    final maxLen2 = maxLen * maxLen;
    final ed = c.edges;
    for (var k = 0; k < ed.length; k += 2) {
      final a = ed[k], b = ed[k + 1];
      final dx = _sx[a] - _sx[b], dy = _sy[a] - _sy[b];
      if (dx * dx + dy * dy > maxLen2) continue;
      final d = depthOf((_sz[a] + _sz[b]) / 2);
      final m = _lineCnt[d];
      final L = _lines[d];
      L[m * 4] = _sx[a];
      L[m * 4 + 1] = _sy[a];
      L[m * 4 + 2] = _sx[b];
      L[m * 4 + 3] = _sy[b];
      _lineCnt[d] = m + 1;
    }

    // Particles swell a little with the voice too.
    final unit = (radius / 100).clamp(0.6, 2.0) * (1 + 0.21 * e);
    final mid = Color.lerp(pal.a, pal.b, 0.5)!;
    final glow = s.bright.clamp(0.0, 1.0) * fade;
    final flare = (s.bright - 1).clamp(0.0, 0.5); // extra light when loud
    for (var d = 0; d < _depthBands; d++) {
      final near = d / (_depthBands - 1); // 0 back .. 1 front
      // The wires.
      if (_lineCnt[d] > 0) {
        _p
          ..strokeWidth = 0.55 * unit
          ..color = mid.withValues(alpha: (0.035 + 0.10 * near) * glow);
        canvas.drawRawPoints(ui.PointMode.lines,
            Float32List.sublistView(_lines[d], 0, _lineCnt[d] * 4), _p);
      }
      // The particles.
      for (var cb = 0; cb < _colorBands; cb++) {
        final b = d * _colorBands + cb;
        if (_cnt[b] == 0) continue;
        final col = Color.lerp(pal.b, pal.a, cb / (_colorBands - 1))!;
        _p
          ..strokeWidth = (1.0 + 1.2 * near) * unit
          ..color = Color.lerp(col, Colors.white, 0.25 * near)!
              .withValues(alpha: (0.30 + 0.65 * near) * glow);
        canvas.drawRawPoints(ui.PointMode.points,
            Float32List.sublistView(_pts[b], 0, _cnt[b] * 2), _p);
      }
      // The neuron bodies: a soft halo and a bright core.
      if (_hubCnt[d] > 0) {
        final hv = Float32List.sublistView(_hubs[d], 0, _hubCnt[d] * 2);
        _p
          ..strokeWidth = (5 + 5 * near) * unit
          ..color = pal.a.withValues(
              alpha: ((0.06 + 0.14 * near) * glow + 0.35 * flare * near)
                  .clamp(0.0, 1.0));
        canvas.drawRawPoints(ui.PointMode.points, hv, _p);
        _p
          ..strokeWidth = (1.8 + 1.8 * near) * unit
          ..color = Color.lerp(pal.a, Colors.white, 0.55)!
              .withValues(alpha: (0.4 + 0.6 * near) * glow);
        canvas.drawRawPoints(ui.PointMode.points, hv, _p);
      }
    }

    // SIGNALS firing along the wires.
    final pairs = ed.length ~/ 2;
    if (pairs > 0) {
      var m = 0;
      final rate = 0.6 + 1.2 * e;
      for (var k = 0; k < _sparks.length ~/ 2; k++) {
        final ph = t * rate + k * 0.137;
        final which = ((k * 37 + ph.floor() * 101) % pairs) * 2;
        final f = ph - ph.floor();
        final a = ed[which], b = ed[which + 1];
        if (_sz[a] + _sz[b] < -0.4) continue; // only the near side
        _sparks[m * 2] = _sx[a] + (_sx[b] - _sx[a]) * f;
        _sparks[m * 2 + 1] = _sy[a] + (_sy[b] - _sy[a]) * f;
        m++;
      }
      if (m > 0) {
        _p
          ..strokeWidth = 3.0 * unit
          ..color = Colors.white.withValues(alpha: 0.85 * glow);
        canvas.drawRawPoints(ui.PointMode.points,
            Float32List.sublistView(_sparks, 0, m * 2), _p);
      }
    }
  }

  @override
  bool shouldRepaint(_NeuronPainter old) =>
      old.scene != scene || old.radius != radius;
}

/// ─────────────────────────────────────────────────────────────────────
///  THE SKY BEHIND THE ORB (2026-11-02, Karthik: "in the background it is
///  black and nothing there — put something compatible"). In the orb's
///  own time-of-day colours:
///   * an aurora — big soft glows drifting in the corners;
///   * a quiet neural net — specks floating up, twinkling, joined by faint
///     lines when they pass near each other;
///  Painted on its own layer; still with "Remove animations", while
///  paused or hidden.
/// ─────────────────────────────────────────────────────────────────────
class NeuronSky extends StatefulWidget {
  const NeuronSky({
    super.key,
    this.mood = OrbMood.idle,
    this.levelListenable,
    this.speakerLevel,
    this.active = true,
    this.clock = DateTime.now,
  });

  final OrbMood mood;
  final ValueListenable<double>? levelListenable;
  final double Function()? speakerLevel;
  final bool active;
  final DateTime Function() clock;

  @override
  State<NeuronSky> createState() => _NeuronSkyState();
}

class _SkyScene extends ChangeNotifier {
  double sec = 0, energy = 0;
  NeuronPalette palette = NeuronPalette.at(DateTime.now());
  void changed() => notifyListeners();
}

class _NeuronSkyState extends State<NeuronSky>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onTick);
  Duration _last = Duration.zero;
  final _SkyScene _scene = _SkyScene();
  bool _still = false;
  double _paletteAge = 0;

  bool get _moving => widget.active && widget.mood != OrbMood.paused && !_still;

  @override
  void initState() {
    super.initState();
    _scene.palette = NeuronPalette.at(widget.clock());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = Motion.reduced(context);
    _sync();
  }

  @override
  void didUpdateWidget(NeuronSky old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (_moving && !_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    } else if (!_moving && _ticker.isActive) {
      _ticker.stop();
    }
  }

  void _onTick(Duration elapsed) {
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.1);
    _last = elapsed;
    final s = _scene;
    s.sec += dt;
    _paletteAge += dt;
    if (_paletteAge > 5) {
      _paletteAge = 0;
      s.palette = NeuronPalette.at(widget.clock());
    }
    final w = widget;
    final double l = switch (w.mood) {
      OrbMood.speaking =>
        (w.speakerLevel?.call() ?? w.levelListenable?.value ?? 0) * 1.6,
      OrbMood.listening => w.levelListenable?.value ?? 0,
      _ => 0.0,
    };
    final h = l.isFinite ? l.clamp(0.0, 1.0) : 0.0;
    final drive = h <= 0.02 ? 0.0 : math.sqrt((h - 0.02) / 0.98);
    s.energy = _NeuronOrbState._ease(s.energy, drive, drive > s.energy ? 20 : 3, dt);
    s.changed();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _scene.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: CustomPaint(
          painter: _SkyPainter(_scene),
          child: const SizedBox.expand(),
        ),
      );
}

class _SkyPainter extends CustomPainter {
  _SkyPainter(this.scene) : super(repaint: scene) {
    final rnd = math.Random(11);
    for (var i = 0; i < _n; i++) {
      _bx[i] = rnd.nextDouble();
      _by[i] = rnd.nextDouble();
      _sp[i] = 0.006 + rnd.nextDouble() * 0.014; // share of height per s
      _ph[i] = rnd.nextDouble() * 2 * math.pi;
      _sz[i] = 0.8 + rnd.nextDouble() * 1.6;
    }
  }

  static const int _n = 80;
  final _SkyScene scene;
  final Float32List _bx = Float32List(_n), _by = Float32List(_n);
  final Float32List _sp = Float32List(_n), _ph = Float32List(_n);
  final Float32List _sz = Float32List(_n);
  final Float32List _px = Float32List(_n), _py = Float32List(_n);
  final Float32List _lines = Float32List(_n * _n * 2);
  final Paint _fill = Paint();
  final Paint _p = Paint()
    ..strokeCap = StrokeCap.round
    ..isAntiAlias = true;

  @override
  void paint(Canvas canvas, Size size) {
    final s = scene;
    final t = s.sec;
    final pal = s.palette;
    final e = s.energy;
    final w = size.width, h = size.height;
    if (w <= 0 || h <= 0) return;

    // THE AURORA: three soft glows drifting slowly.
    void glow(double ax, double ay, double r, Color c, double a) {
      final o = Offset(ax * w, ay * h);
      _fill.shader = ui.Gradient.radial(o, r, [
        c.withValues(alpha: a),
        c.withValues(alpha: a * 0.35),
        c.withValues(alpha: 0),
      ], const [0.0, 0.45, 1.0]);
      canvas.drawCircle(o, r, _fill);
    }

    final big = math.max(w, h);
    glow(0.12 + 0.06 * math.sin(t * 0.13), 0.10 + 0.04 * math.cos(t * 0.11),
        big * 0.55, pal.a, 0.20 + 0.06 * e);
    glow(0.92 + 0.05 * math.cos(t * 0.09), 0.38 + 0.05 * math.sin(t * 0.12),
        big * 0.45, pal.b, 0.16 + 0.06 * e);
    glow(0.30 + 0.08 * math.sin(t * 0.07 + 1), 0.95 + 0.03 * math.cos(t * 0.1),
        big * 0.5, Color.lerp(pal.a, pal.b, 0.5)!, 0.14 + 0.05 * e);

    // THE NEURAL NET: specks rising slowly, swaying, twinkling.
    for (var i = 0; i < _n; i++) {
      var y = (_by[i] - t * _sp[i]) % 1.0;
      if (y < 0) y += 1;
      _px[i] = (_bx[i] + 0.015 * math.sin(t * 0.4 + _ph[i])) * w;
      _py[i] = y * h;
    }
    final reach = w * 0.2, reach2 = reach * reach;
    var m = 0;
    for (var i = 0; i < _n; i++) {
      for (var j = i + 1; j < _n; j++) {
        final dx = _px[i] - _px[j], dy = _py[i] - _py[j];
        if (dx * dx + dy * dy > reach2) continue;
        _lines[m * 4] = _px[i];
        _lines[m * 4 + 1] = _py[i];
        _lines[m * 4 + 2] = _px[j];
        _lines[m * 4 + 3] = _py[j];
        m++;
      }
    }
    if (m > 0) {
      _p
        ..strokeWidth = 0.6
        ..color = pal.a.withValues(alpha: 0.10);
      canvas.drawRawPoints(
          ui.PointMode.lines, Float32List.sublistView(_lines, 0, m * 4), _p);
    }
    for (var i = 0; i < _n; i++) {
      final tw = 0.5 + 0.5 * math.sin(t * 1.3 + _ph[i] * 3);
      _p
        ..strokeWidth = _sz[i] * (2.2 + 1.2 * tw)
        ..color = pal.a.withValues(alpha: 0.05 + 0.06 * tw);
      canvas.drawCircle(Offset(_px[i], _py[i]), _p.strokeWidth / 2, _p);
      _p.color = Color.lerp(pal.a, Colors.white, 0.6)!
          .withValues(alpha: 0.25 + 0.45 * tw);
      canvas.drawCircle(Offset(_px[i], _py[i]), _sz[i] * 0.7, _p);
    }

  }

  @override
  bool shouldRepaint(_SkyPainter old) => old.scene != scene;
}
