// GURUJI (owner, 2026-11-23: "instead of the user typing, keep an orb with a
// Hindu theme … a guru kind of orb asking for the user's details if they are
// not saved; if saved it should say today's Jyotisha bhavishya and ask for
// more questions"). The Jyotish screen opens on this page: a lotus-mandala
// orb over a line drawing of temple architecture, a quiet tanpura drone
// behind, and the assistant speaking as Guruji — the same voice engine,
// tools and saved charts as everywhere else (backend src/jyotish/tools.js).

import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../ai/assistant_role.dart';
import '../../core/log.dart';
import '../../design/neon_tokens.dart';
import '../../widgets/role_mic_orb.dart';
import '../../widgets/voice_orb.dart' show OrbMood;
import '../assistant/state/assistant_engine.dart';
import '../assistant/state/assistant_state.dart';

/// The temple palette: saffron, vermilion, sandalwood and temple gold on a
/// maroon-to-indigo dusk.
abstract final class Mandir {
  static const saffron = Color(0xFFFF9933);
  static const deepSaffron = Color(0xFFE8731A);
  static const vermilion = Color(0xFFD9381E);
  static const maroon = Color(0xFF4A1020);
  static const gold = Color(0xFFF2C14E);
  static const sandal = Color(0xFFF3D9A4);
  static const dusk = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF2B0B1E), Color(0xFF3A1226), Color(0xFF1A0D33)],
    stops: [0, 0.45, 1],
  );
}

// ── Who speaks ─────────────────────────────────────────────────────────

/// Guruji: the assistant in this role on the Jyotish screen.
const guruRole = AssistantRole(
  'Guruji, the Jyotish guide',
  'You are a warm, wise Vedic astrologer (Jyotishi) on the Jyotish screen. '
      'Speak calmly and kindly, like a respected guru: short sentences, a '
      'gentle Namaste to begin, Sanskrit terms (rashi, nakshatra, lagna, '
      'dasha, gochar) explained simply. To cast a chart, collect their name, '
      'date of birth, place of birth and time of birth one question at a '
      'time (they may not know the time), then cast and save it with '
      'jyotish_chart. For readings use jyotish_reading: range today for '
      "today's bhavishya, or week, month or year, and a category (career, "
      'love, health, finance…) when they name one. Speak only from what '
      'those tools return — never invent planetary positions. Readings are '
      'for reflection, not certainty: never frighten anyone about doshas or '
      'sade sati, and never sell remedies. Reply in the language they speak.',
  tools: ['jyotish_chart', 'jyotish_reading'],
  // A natural male voice (owner, 2026-11-23: "I need a male voice for
  // Jyotish, like a real one"), whatever voice the everyday assistant uses.
  voice: 'cedar',
  voiceStyle: 'deep, calm and unhurried, like a wise elderly Indian guru, in gentle Indian English',
);

/// Guruji's first words: today's bhavishya for a saved chart, otherwise the
/// questions that cast one. [savedName] is the saved person's name, or
/// null when nothing is saved.
String guruOpeningNote(String? savedName) {
  if (savedName != null && savedName.trim().isNotEmpty) {
    return "[SYSTEM] I have just opened the Jyotish screen. My birth chart is "
        "saved (as ${savedName.trim()}). As Guruji, greet me with Namaste, then "
        "tell me today's Jyotisha Bhavishya — call jyotish_reading with range "
        "today — in three or four warm sentences, and then ask whether I have "
        "any other questions.";
  }
  return "[SYSTEM] I have just opened the Jyotish screen and no birth chart is "
      "saved yet. As Guruji, greet me with Namaste and ask for my name first; "
      "then my date of birth, place of birth and time of birth, one question "
      "at a time. When you have them, cast and save my chart with "
      "jyotish_chart, then tell me today's Jyotisha Bhavishya (jyotish_reading, "
      "range today) and ask whether I have any other questions.";
}

// ── The music ──────────────────────────────────────────────────────────

/// The quiet tanpura drone behind the screen (assets/jyotish/tanpura.wav, an
/// original loop made for the app). It mixes with other sound instead of
/// taking the audio focus, drops low while Guruji speaks or listens, pauses
/// when the app is left, and can be switched off (remembered).
class JyotishMusic {
  JyotishMusic();

  static const _prefKey = 'jyotish_music_on';
  static const _volume = 0.22;
  static const _duckedVolume = 0.05;

  /// Whether the music plays; the screen's music button flips it.
  final ValueNotifier<bool> on = ValueNotifier<bool>(true);

  AudioPlayer? _player;
  bool _ducked = false;
  bool _paused = false;

  Future<void> start() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      on.value = prefs.getBool(_prefKey) ?? true;
    } catch (_) {}
    if (on.value) await _play();
  }

  Future<void> _play() async {
    try {
      final p = _player ??= AudioPlayer();
      await p.setAudioContext(
          AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers)
              .build());
      await p.setReleaseMode(ReleaseMode.loop);
      await p.play(AssetSource('jyotish/tanpura.wav'),
          volume: _ducked ? _duckedVolume : _volume);
      _paused = false;
    } catch (e) {
      AppLog.add('jyotish', 'music unavailable: $e');
    }
  }

  /// Switch the music on or off; remembered for the next visit.
  Future<void> toggle() async {
    on.value = !on.value;
    try {
      (await SharedPreferences.getInstance()).setBool(_prefKey, on.value);
    } catch (_) {}
    if (on.value) {
      await _play();
    } else {
      try {
        await _player?.stop();
      } catch (_) {}
    }
  }

  /// Low under Guruji's voice (and while the microphone listens).
  void duck(bool down) {
    if (down == _ducked) return;
    _ducked = down;
    try {
      unawaited(_player?.setVolume(down ? _duckedVolume : _volume));
    } catch (_) {}
  }

  /// The app was left / came back.
  void pause() {
    if (_player == null || !on.value) return;
    _paused = true;
    try {
      unawaited(_player!.pause());
    } catch (_) {}
  }

  void resume() {
    if (_player == null || !on.value || !_paused) return;
    _paused = false;
    try {
      unawaited(_player!.resume());
    } catch (_) {}
  }

  Future<void> dispose() async {
    final p = _player;
    _player = null;
    try {
      await p?.stop();
      await p?.dispose();
    } catch (_) {}
  }
}

/// No sound at all (tests).
class SilentJyotishMusic extends JyotishMusic {
  @override
  Future<void> start() async {}
  @override
  Future<void> toggle() async => on.value = !on.value;
  @override
  void duck(bool down) {}
  @override
  void pause() {}
  @override
  void resume() {}
  @override
  Future<void> dispose() async {}
}

// ── The temple drawing ─────────────────────────────────────────────────

/// The dusk gradient with a faint line drawing of temple architecture:
/// a toran of bells along the top, carved pillars and a scalloped arch,
/// a skyline of shikharas and a gopuram, and diyas and lotuses between.
class TempleDoodle extends StatelessWidget {
  const TempleDoodle({super.key, this.child});
  final Widget? child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: const BoxDecoration(gradient: Mandir.dusk),
        child: CustomPaint(
          painter: TempleDoodlePainter(),
          child: child ?? const SizedBox.expand(),
        ),
      );
}

class TempleDoodlePainter extends CustomPainter {
  TempleDoodlePainter({this.color = Mandir.gold, this.opacity = 0.14, this.skylineOnly = false});
  final Color color;
  final double opacity;

  /// Only the temple skyline along the bottom (the Home card).
  final bool skylineOnly;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    if (w <= 0 || h <= 0) return;
    if (skylineOnly) {
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color.withValues(alpha: opacity);
      // Drawn as on a screen this much taller, so the towers keep their
      // proportions; the platform sits on the card's bottom edge.
      final virtualH = h * 2.4;
      canvas.save();
      canvas.translate(0, h - virtualH * 0.97);
      _skyline(canvas, p, w, virtualH);
      canvas.restore();
      return;
    }
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color.withValues(alpha: opacity);
    final strong = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color.withValues(alpha: opacity * 1.35);

    _toran(canvas, line, w, h * 0.035, h * 0.03);
    _pillar(canvas, line, Rect.fromLTWH(w * 0.035, h * 0.12, w * 0.07, h * 0.6));
    _pillar(canvas, line, Rect.fromLTWH(w * 0.895, h * 0.12, w * 0.07, h * 0.6));
    _arch(canvas, line, Offset(w * 0.07, h * 0.13), Offset(w * 0.93, h * 0.13),
        h * 0.07);
    _skyline(canvas, strong, w, h);
    final rnd = math.Random(11);
    final spots = <Offset>[
      Offset(w * 0.2, h * 0.3),
      Offset(w * 0.8, h * 0.27),
      Offset(w * 0.17, h * 0.58),
      Offset(w * 0.83, h * 0.6),
      Offset(w * 0.3, h * 0.72),
      Offset(w * 0.7, h * 0.71),
    ];
    for (var i = 0; i < spots.length; i++) {
      if (i.isEven) {
        _diya(canvas, line, spots[i], w * 0.035);
      } else {
        _lotus(canvas, line, spots[i], w * 0.04);
      }
    }
    final dot = Paint()..color = color.withValues(alpha: opacity * 1.1);
    for (var i = 0; i < 26; i++) {
      final o = Offset(w * (0.12 + rnd.nextDouble() * 0.76),
          h * (0.18 + rnd.nextDouble() * 0.55));
      // Keep the middle (the orb) clear.
      if ((o - Offset(w / 2, h * 0.42)).distance < w * 0.32) continue;
      _sparkle(canvas, dot, o, 1.2 + rnd.nextDouble() * 2.2);
    }
  }

  /// A garland across the top: a sagging string with bells and mango leaves.
  void _toran(Canvas c, Paint p, double w, double y, double sag) {
    final path = Path()
      ..moveTo(0, y)
      ..quadraticBezierTo(w / 2, y + sag * 2, w, y);
    c.drawPath(path, p);
    const n = 13;
    for (var i = 1; i < n; i++) {
      final t = i / n;
      final x = w * t;
      final yy = y + sag * 4 * t * (1 - t);
      if (i.isEven) {
        // a bell
        c.drawLine(Offset(x, yy), Offset(x, yy + sag * 0.8), p);
        final b = Path()
          ..moveTo(x - sag * 0.45, yy + sag * 1.6)
          ..quadraticBezierTo(x - sag * 0.45, yy + sag * 0.75, x, yy + sag * 0.75)
          ..quadraticBezierTo(x + sag * 0.45, yy + sag * 0.75, x + sag * 0.45, yy + sag * 1.6)
          ..close();
        c.drawPath(b, p);
        c.drawCircle(Offset(x, yy + sag * 1.8), sag * 0.12, p);
      } else {
        // a mango leaf
        final leaf = Path()
          ..moveTo(x, yy)
          ..quadraticBezierTo(x - sag * 0.4, yy + sag * 0.8, x, yy + sag * 1.5)
          ..quadraticBezierTo(x + sag * 0.4, yy + sag * 0.8, x, yy);
        c.drawPath(leaf, p);
      }
    }
  }

  /// A carved pillar: base, banded shaft and a bracketed capital.
  void _pillar(Canvas c, Paint p, Rect r) {
    final bw = r.width;
    final base = Rect.fromLTWH(r.left - bw * 0.15, r.bottom - bw * 0.5, bw * 1.3, bw * 0.5);
    c.drawRect(base, p);
    final shaft = Rect.fromLTRB(r.left + bw * 0.15, r.top + bw * 0.6, r.right - bw * 0.15, base.top);
    c.drawRect(shaft, p);
    for (var i = 1; i <= 4; i++) {
      final y = shaft.top + shaft.height * i / 5;
      c.drawLine(Offset(shaft.left, y), Offset(shaft.right, y), p);
      c.drawCircle(Offset(shaft.center.dx, y - shaft.height / 10), bw * 0.12, p);
    }
    final cap = Path()
      ..moveTo(r.left - bw * 0.25, r.top + bw * 0.6)
      ..lineTo(r.right + bw * 0.25, r.top + bw * 0.6)
      ..lineTo(r.right, r.top + bw * 0.25)
      ..lineTo(r.left, r.top + bw * 0.25)
      ..close();
    c.drawPath(cap, p);
    c.drawRect(Rect.fromLTWH(r.left - bw * 0.1, r.top, bw * 1.2, bw * 0.25), p);
  }

  /// A scalloped (multifoil) arch between two pillar tops.
  void _arch(Canvas c, Paint p, Offset a, Offset b, double rise) {
    const lobes = 11;
    final mid = Offset((a.dx + b.dx) / 2, a.dy);
    final half = (b.dx - a.dx) / 2;
    Offset at(double t) {
      final ang = math.pi * (1 - t);
      return Offset(mid.dx + half * math.cos(ang), mid.dy + rise - rise * 1.6 * math.sin(ang));
    }

    final path = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 0; i < lobes; i++) {
      final p0 = at(i / lobes), p1 = at((i + 1) / lobes);
      final m = Offset((p0.dx + p1.dx) / 2, (p0.dy + p1.dy) / 2);
      // each lobe bulges toward the arch's centre
      final inward = (Offset(mid.dx, mid.dy + rise * 2) - m);
      final ctrl = m + inward / inward.distance * rise * 0.35;
      path.quadraticBezierTo(ctrl.dx, ctrl.dy, p1.dx, p1.dy);
    }
    c.drawPath(path, p);
    // the keystone kalash at the crown
    final top = at(0.5);
    c.drawCircle(top.translate(0, -rise * 0.32), rise * 0.14, p);
    c.drawLine(top.translate(0, -rise * 0.46), top.translate(0, -rise * 0.7), p);
  }

  /// The skyline: a gopuram in the middle, a shikhara each side, small
  /// domed mandapas between, on a stepped platform.
  void _skyline(Canvas c, Paint p, double w, double h) {
    final base = h * 0.93;
    // platform steps
    for (var i = 0; i < 3; i++) {
      final y = base + i * h * 0.012;
      c.drawLine(Offset(w * (0.06 - i * 0.02), y), Offset(w * (0.94 + i * 0.02), y), p);
    }
    // gopuram: stacked tiers with a barrel roof and three finials
    final gx = w / 2, gw = w * 0.26, gh = h * 0.2;
    const tiers = 5;
    var y = base;
    for (var i = 0; i < tiers; i++) {
      final topW = gw * (1 - (i + 1) * 0.13);
      final botW = gw * (1 - i * 0.13);
      final th = gh / (tiers + 1.2);
      final tier = Path()
        ..moveTo(gx - botW / 2, y)
        ..lineTo(gx - topW / 2, y - th)
        ..lineTo(gx + topW / 2, y - th)
        ..lineTo(gx + botW / 2, y)
        ..close();
      c.drawPath(tier, p);
      // little niches along each tier
      final niches = 3 + (tiers - i);
      for (var k = 1; k < niches; k++) {
        final nx = gx - topW / 2 + topW * k / niches;
        c.drawLine(Offset(nx, y - th * 0.2), Offset(nx, y - th * 0.75), p);
      }
      y -= th;
    }
    final roofW = gw * (1 - tiers * 0.13);
    final roof = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(gx, y - h * 0.012), width: roofW * 1.1, height: h * 0.024),
        Radius.circular(h * 0.012));
    c.drawRRect(roof, p);
    for (final dx in [-roofW * 0.35, 0.0, roofW * 0.35]) {
      final top = Offset(gx + dx, y - h * 0.024);
      c.drawLine(top, top.translate(0, -h * 0.014), p);
      c.drawCircle(top.translate(0, -h * 0.018), h * 0.004, p);
    }
    // the doorway
    final door = Path()
      ..moveTo(gx - gw * 0.08, base)
      ..lineTo(gx - gw * 0.08, base - gh * 0.16)
      ..quadraticBezierTo(gx, base - gh * 0.26, gx + gw * 0.08, base - gh * 0.16)
      ..lineTo(gx + gw * 0.08, base);
    c.drawPath(door, p);

    // shikharas: curvilinear towers with ribs, an amalaka and a kalash
    for (final sx in [w * 0.2, w * 0.8]) {
      final bw = w * 0.15, sh = h * 0.17;
      final tower = Path()
        ..moveTo(sx - bw / 2, base)
        ..cubicTo(sx - bw / 2, base - sh * 0.55, sx - bw * 0.22, base - sh * 0.92, sx, base - sh)
        ..cubicTo(sx + bw * 0.22, base - sh * 0.92, sx + bw / 2, base - sh * 0.55, sx + bw / 2, base);
      c.drawPath(tower, p);
      for (var k = 1; k <= 4; k++) {
        final t = k / 5;
        final yy = base - sh * t;
        final half = bw / 2 * (1 - t * t * 0.75);
        c.drawPath(
            Path()
              ..moveTo(sx - half, yy)
              ..quadraticBezierTo(sx, yy - sh * 0.04, sx + half, yy),
            p);
      }
      c.drawLine(Offset(sx, base - sh * 0.15), Offset(sx, base - sh * 0.85), p);
      c.drawOval(Rect.fromCenter(center: Offset(sx, base - sh - h * 0.006), width: bw * 0.3, height: h * 0.012), p);
      c.drawCircle(Offset(sx, base - sh - h * 0.02), h * 0.006, p);
      c.drawLine(Offset(sx, base - sh - h * 0.026), Offset(sx, base - sh - h * 0.04), p);
      // a pennant
      c.drawPath(
          Path()
            ..moveTo(sx, base - sh - h * 0.04)
            ..lineTo(sx + bw * 0.18, base - sh - h * 0.034)
            ..lineTo(sx, base - sh - h * 0.028),
          p);
    }
    // mandapa domes between
    for (final mx in [w * 0.355, w * 0.645]) {
      final mw = w * 0.08, mh = h * 0.05;
      c.drawRect(Rect.fromLTWH(mx - mw / 2, base - mh, mw, mh), p);
      c.drawArc(Rect.fromCenter(center: Offset(mx, base - mh), width: mw, height: mw * 0.9), math.pi, math.pi, false, p);
      c.drawLine(Offset(mx, base - mh - mw * 0.45), Offset(mx, base - mh - mw * 0.65), p);
      for (var k = 1; k < 3; k++) {
        final px = mx - mw / 2 + mw * k / 3;
        c.drawLine(Offset(px, base), Offset(px, base - mh * 0.75), p);
      }
    }
  }

  void _diya(Canvas c, Paint p, Offset o, double s) {
    final bowl = Path()
      ..moveTo(o.dx - s, o.dy)
      ..quadraticBezierTo(o.dx, o.dy + s * 0.9, o.dx + s, o.dy)
      ..lineTo(o.dx + s * 1.2, o.dy - s * 0.15)
      ..moveTo(o.dx - s, o.dy)
      ..lineTo(o.dx + s * 1.2, o.dy - s * 0.15);
    c.drawPath(bowl, p);
    final flame = Path()
      ..moveTo(o.dx + s * 0.9, o.dy - s * 0.2)
      ..quadraticBezierTo(o.dx + s * 0.55, o.dy - s * 0.75, o.dx + s * 0.95, o.dy - s * 1.25)
      ..quadraticBezierTo(o.dx + s * 1.3, o.dy - s * 0.7, o.dx + s * 0.9, o.dy - s * 0.2);
    c.drawPath(flame, p);
  }

  void _lotus(Canvas c, Paint p, Offset o, double s) {
    for (final a in [-0.9, -0.45, 0.0, 0.45, 0.9]) {
      final tip = o + Offset(math.sin(a) * s * 1.2, -math.cos(a) * s * 1.2);
      final left = o + Offset(math.sin(a - 0.35) * s * 0.6, -math.cos(a - 0.35) * s * 0.6);
      final right = o + Offset(math.sin(a + 0.35) * s * 0.6, -math.cos(a + 0.35) * s * 0.6);
      c.drawPath(
          Path()
            ..moveTo(o.dx, o.dy)
            ..quadraticBezierTo(left.dx, left.dy, tip.dx, tip.dy)
            ..quadraticBezierTo(right.dx, right.dy, o.dx, o.dy),
          p);
    }
    c.drawPath(
        Path()
          ..moveTo(o.dx - s * 1.1, o.dy + s * 0.1)
          ..quadraticBezierTo(o.dx, o.dy + s * 0.6, o.dx + s * 1.1, o.dy + s * 0.1),
        p);
  }

  void _sparkle(Canvas c, Paint p, Offset o, double r) {
    final path = Path()
      ..moveTo(o.dx, o.dy - r * 2)
      ..quadraticBezierTo(o.dx, o.dy, o.dx + r * 2, o.dy)
      ..quadraticBezierTo(o.dx, o.dy, o.dx, o.dy + r * 2)
      ..quadraticBezierTo(o.dx, o.dy, o.dx - r * 2, o.dy)
      ..quadraticBezierTo(o.dx, o.dy, o.dx, o.dy - r * 2);
    c.drawPath(path, p);
  }

  @override
  bool shouldRepaint(TempleDoodlePainter old) =>
      old.color != color || old.opacity != opacity || old.skylineOnly != skylineOnly;
}

// ── The orb ────────────────────────────────────────────────────────────

/// Guruji's orb: a golden disc with ॐ, inside two rings of lotus petals
/// and a turning mala of beads, glowing saffron. While Guruji listens or
/// speaks it breathes with the voice.
class GuruOrb extends StatefulWidget {
  const GuruOrb({super.key, this.size = 220, this.talking = false, this.mood = OrbMood.idle});
  final double size;
  final bool talking;
  final OrbMood mood;

  @override
  State<GuruOrb> createState() => _GuruOrbState();
}

class _GuruOrbState extends State<GuruOrb> with SingleTickerProviderStateMixin {
  late final AnimationController _spin =
      AnimationController(vsync: this, duration: const Duration(seconds: 40));
  double _energy = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduced motion: a still mandala.
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (still) {
      _spin.stop();
    } else if (!_spin.isAnimating) {
      _spin.repeat();
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  double _level() {
    if (!widget.talking) return 0;
    final e = AssistantEngine.instance;
    final speaking = widget.mood == OrbMood.speaking;
    final v = speaking ? e.speakerLevelNow() : e.micLevel;
    return v.clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _spin,
        builder: (_, __) {
          // Smooth the level so the glow breathes instead of flickering.
          _energy += (_level() - _energy) * 0.18;
          return CustomPaint(
            painter: GuruOrbPainter(
              turn: _spin.value,
              energy: _energy,
              talking: widget.talking,
            ),
          );
        },
      ),
    );
  }
}

class GuruOrbPainter extends CustomPainter {
  GuruOrbPainter({required this.turn, required this.energy, required this.talking});
  final double turn;
  final double energy;
  final bool talking;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 * 0.5; // the golden disc
    final glowR = r * (2.0 + 0.25 * energy);
    canvas.drawCircle(
        c,
        glowR,
        Paint()
          ..shader = RadialGradient(colors: [
            Mandir.saffron.withValues(alpha: talking ? 0.55 + 0.3 * energy : 0.38),
            Mandir.deepSaffron.withValues(alpha: 0.12),
            Colors.transparent,
          ], stops: const [0.25, 0.6, 1]).createShader(Rect.fromCircle(center: c, radius: glowR)));

    // ripples while the voice is going
    if (talking) {
      for (var i = 0; i < 2; i++) {
        final ph = (turn * 12 + i * 0.5) % 1.0;
        canvas.drawCircle(
            c,
            r * (1.55 + 0.45 * ph),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.4
              ..color = Mandir.gold.withValues(alpha: (1 - ph) * (0.25 + 0.45 * energy)));
      }
    }

    // the mala: 27 beads, one for each nakshatra, turning slowly
    final bead = Paint()..color = Mandir.sandal.withValues(alpha: 0.75);
    for (var i = 0; i < 27; i++) {
      final a = 2 * math.pi * (i / 27 + turn);
      canvas.drawCircle(c + Offset(math.cos(a), math.sin(a)) * r * 1.62, r * 0.035, bead);
    }

    // two rings of lotus petals, turning against each other
    _petals(canvas, c, 16, r * 1.0, r * 1.48, -turn * 0.6, 0.11,
        [Mandir.gold.withValues(alpha: 0.85), Mandir.deepSaffron.withValues(alpha: 0.75)]);
    _petals(canvas, c, 8, r * 0.92, r * 1.25, turn * 0.4 + 1 / 16, 0.22,
        [Mandir.sandal.withValues(alpha: 0.9), Mandir.saffron.withValues(alpha: 0.7)]);

    // the golden disc
    final scale = 1 + 0.05 * energy;
    final disc = Rect.fromCircle(center: c, radius: r * scale);
    canvas.drawCircle(
        c,
        r * scale,
        Paint()
          ..shader = const RadialGradient(
            colors: [Color(0xFFFFF4CF), Color(0xFFF7C14D), Color(0xFFD9781E)],
            stops: [0, 0.6, 1],
          ).createShader(disc));
    canvas.drawCircle(
        c,
        r * scale,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xFFFFE7A3));
    canvas.drawCircle(
        c,
        r * 0.82 * scale,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = Mandir.maroon.withValues(alpha: 0.35));

    // ॐ
    final tp = TextPainter(
      text: TextSpan(
        text: 'ॐ',
        style: TextStyle(
          fontSize: r * 0.95 * scale,
          color: const Color(0xFF6B1D0E),
          fontWeight: FontWeight.w600,
          shadows: [Shadow(color: const Color(0xFFFFF4CF).withValues(alpha: 0.8), blurRadius: 6)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2 + r * 0.04));
  }

  void _petals(Canvas c, Offset o, int n, double r1, double r2, double rot, double halfWidth,
      List<Color> colors) {
    final fill = Paint()
      ..shader = RadialGradient(colors: colors, stops: const [0.55, 1])
          .createShader(Rect.fromCircle(center: o, radius: r2));
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = const Color(0xFFFFE7A3).withValues(alpha: 0.6);
    for (var i = 0; i < n; i++) {
      final a = 2 * math.pi * (i / n + rot);
      Offset pt(double radius, double da) => o + Offset(math.cos(a + da), math.sin(a + da)) * radius;
      final path = Path()
        ..moveTo(pt(r1, 0).dx, pt(r1, 0).dy)
        ..quadraticBezierTo(pt((r1 + r2) / 2, -halfWidth * 2).dx, pt((r1 + r2) / 2, -halfWidth * 2).dy,
            pt(r2, 0).dx, pt(r2, 0).dy)
        ..quadraticBezierTo(pt((r1 + r2) / 2, halfWidth * 2).dx, pt((r1 + r2) / 2, halfWidth * 2).dy,
            pt(r1, 0).dx, pt(r1, 0).dy)
        ..close();
      c.drawPath(path, fill);
      c.drawPath(path, edge);
    }
  }

  @override
  bool shouldRepaint(GuruOrbPainter old) =>
      old.turn != turn || old.energy != energy || old.talking != talking;
}

// ── The page ───────────────────────────────────────────────────────────

/// What the Jyotish screen opens on: Guruji's orb on the temple drawing,
/// what Guruji is saying under it, and [actions] at the bottom.
class GuruPage extends StatefulWidget {
  const GuruPage({
    super.key,
    required this.savedName,
    required this.music,
    this.autoStart = true,
    this.onChartSaved,
    this.actions = const [],
  });

  /// The saved person Guruji reads for; null when nothing is saved.
  final String? savedName;
  final JyotishMusic music;

  /// Guruji speaks as the page opens (off in tests).
  final bool autoStart;

  /// Guruji cast and saved a chart by voice: the screen shows it.
  final VoidCallback? onChartSaved;
  final List<Widget> actions;

  @override
  State<GuruPage> createState() => _GuruPageState();
}

class _GuruPageState extends State<GuruPage> {
  final _engine = AssistantEngine.instance;

  /// Chart casts already seen, so each is reported once.
  final Set<ToolActivity> _seen = {};

  @override
  void initState() {
    super.initState();
    _seen.addAll(_engine.activities);
    _engine.addListener(_changed);
  }

  @override
  void dispose() {
    _engine.removeListener(_changed);
    widget.music.duck(false);
    super.dispose();
  }

  bool get _mine => AssistantRole.current.value == guruRole;

  bool get _running =>
      _engine.starting ||
      _engine.inlineVoice ||
      _engine.liveActive ||
      (_engine.phase != AssistantPhase.idle && _engine.phase != AssistantPhase.completed);

  void _changed() {
    if (!mounted) return;
    widget.music.duck(_mine && _running);
    for (final a in _engine.activities) {
      if (a.tool == 'jyotish_chart' && a.completed && _seen.add(a)) {
        widget.onChartSaved?.call();
      }
    }
    setState(() {});
  }

  /// Guruji's latest words in this conversation.
  String? get _said {
    if (!_mine) return null;
    for (final e in _engine.transcript.reversed) {
      if (e.role == TranscriptRole.assistant && e.text.trim().isNotEmpty) return e.text.trim();
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final said = _said;
    final idleHint = widget.savedName != null
        ? "Tap the orb and Guruji will tell you today's bhavishya."
        : 'Tap the orb and tell Guruji your date, time and place of birth.';
    return LayoutBuilder(builder: (context, box) {
      final orb = math.min(box.maxWidth * 0.66, box.maxHeight * 0.4).clamp(160.0, 280.0);
      return Column(children: [
        const Spacer(flex: 2),
        RoleMicOrb(
          role: guruRole,
          tint: Mandir.saffron,
          size: orb,
          autoStart: widget.autoStart,
          openingNote: () => guruOpeningNote(widget.savedName),
          orbBuilder: (context, talking, mood, label) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GuruOrb(size: orb, talking: talking, mood: mood),
              const SizedBox(height: 10),
              Text(
                talking ? label : 'Tap to Talk to Guruji',
                style: NeonType.manrope(13, FontWeight.w800).copyWith(
                    color: Mandir.gold, letterSpacing: 1.2),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              said ?? idleHint,
              key: ValueKey(said ?? idleHint),
              textAlign: TextAlign.center,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: said != null ? Mandir.sandal : Mandir.sandal.withValues(alpha: 0.75),
                fontSize: said != null ? 16 : 14.5,
                height: 1.45,
                fontStyle: said != null ? FontStyle.normal : FontStyle.italic,
              ),
            ),
          ),
        ),
        const Spacer(flex: 3),
        if (widget.actions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 8,
              children: widget.actions,
            ),
          ),
      ]);
    });
  }
}

/// For tests: the opening note a page would send.
@visibleForTesting
String debugGuruOpening(String? savedName) => guruOpeningNote(savedName);
