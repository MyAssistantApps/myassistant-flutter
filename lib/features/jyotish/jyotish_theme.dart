// JYOTISH THEME (2026-11-22) — the horoscope's own night sky: always dark
// and cosmic (deep indigo, starlight, gold), whatever the app's theme.

import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../design/neon_tokens.dart';
import '../home/cosmic_painter.dart';
import 'kundli_chart.dart';

class Cosmic {
  static const top = Color(0xFF0B0820);
  static const mid = Color(0xFF1B1245);
  static const low = Color(0xFF0C1B3C);
  static const gold = Color(0xFFF5C76B);
  static const rose = Color(0xFFFF8FB1);
  static const sky = Color(0xFF8FD3FF);
  static const ink = Color(0xFFEDE8FF);
  static const dim = Color(0xFFB3AAD9);
  static const faint = Color(0xFF7D76A6);
  static const card = Color(0x14FFFFFF);
  static const edge = Color(0x2EFFFFFF);
  static const good = Color(0xFF7FE0A8);
  static const warn = Color(0xFFFFB86B);

  static const gradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [top, mid, low],
  );

  static const brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2A1B6B), Color(0xFF151040), Color(0xFF0E2350)],
  );

  static const kundli = KundliColors(
    line: Color(0x66F5C76B),
    sign: dim,
    planet: ink,
    retro: rose,
    lagna: gold,
    fill: Color(0x10FFFFFF),
  );

  static TextStyle title([double size = NeonType.headline]) =>
      NeonType.manrope(size, FontWeight.w700).copyWith(color: ink);
  static TextStyle body([double size = NeonType.body]) =>
      NeonType.manrope(size, FontWeight.w400).copyWith(color: ink, height: 1.45);
  static TextStyle label([double size = NeonType.footnote]) =>
      NeonType.manrope(size, FontWeight.w500).copyWith(color: dim);

  /// The dark theme the screen's own widgets (fields, chips, pickers) use.
  static ThemeData theme(BuildContext context) {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: Colors.transparent,
      colorScheme: const ColorScheme.dark(
        primary: gold,
        onPrimary: Color(0xFF241A00),
        secondary: sky,
        surface: Color(0xFF1A1440),
        onSurface: ink,
        error: rose,
      ),
      textTheme: base.textTheme.apply(bodyColor: ink, displayColor: ink),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card,
        labelStyle: label(),
        hintStyle: label().copyWith(color: faint),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: edge)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: edge)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: gold)),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: card,
        selectedColor: gold.withValues(alpha: 0.22),
        side: const BorderSide(color: edge),
        labelStyle: label().copyWith(color: ink),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: gold,
        unselectedLabelColor: dim,
        indicatorColor: gold,
        dividerColor: Colors.transparent,
      ),
      dividerColor: edge,
    );
  }
}

/// The night sky behind the screen: the gradient and a fixed scatter of stars.
class CosmicBackdrop extends StatelessWidget {
  const CosmicBackdrop({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: const BoxDecoration(gradient: Cosmic.gradient),
        child: CustomPaint(painter: StarsPainter(), child: child),
      );
}

class StarsPainter extends CustomPainter {
  StarsPainter({this.count = 70, this.seed = 7});
  final int count;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(seed);
    final p = Paint();
    for (var i = 0; i < count; i++) {
      final o = Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height);
      final r = rnd.nextDouble() * 1.2 + 0.3;
      p.color = Colors.white.withValues(alpha: 0.15 + rnd.nextDouble() * 0.45);
      canvas.drawCircle(o, r, p);
    }
  }

  @override
  bool shouldRepaint(StarsPainter old) => old.count != count || old.seed != seed;
}

/// A translucent panel on the sky.
class CosmicCard extends StatelessWidget {
  const CosmicCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.glow = false});
  final Widget child;
  final EdgeInsets padding;
  final bool glow;

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: Cosmic.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: glow ? Cosmic.gold.withValues(alpha: 0.55) : Cosmic.edge),
          boxShadow: glow
              ? [BoxShadow(color: Cosmic.gold.withValues(alpha: 0.18), blurRadius: 24)]
              : null,
        ),
        // List tiles inside paint their ink on this, not under the colour.
        child: Material(type: MaterialType.transparency, child: child),
      );
}

/// A small labelled fact: "Moon sign · Sagittarius".
class FactChip extends StatelessWidget {
  const FactChip({super.key, required this.label, required this.value, this.color = Cosmic.gold});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: Cosmic.label(NeonType.caption)),
            const SizedBox(height: 2),
            Text(value, style: Cosmic.title(NeonType.body).copyWith(color: color)),
          ],
        ),
      );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 10),
        child: Row(children: [
          Expanded(child: Semantics(header: true, child: Text(text, style: Cosmic.title()))),
          if (trailing != null) trailing!,
        ]),
      );
}

/// The always-visible note under every reading.
class Disclaimer extends StatelessWidget {
  const Disclaimer({super.key, this.text});
  final String? text;

  @override
  Widget build(BuildContext context) => Row(children: [
        const Icon(Icons.info_outline_rounded, size: 16, color: Cosmic.faint),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text ?? 'For entertainment and self-reflection only.',
              style: Cosmic.label(NeonType.caption).copyWith(color: Cosmic.faint)),
        ),
      ]);
}

String prettyDate(String? ymd) {
  if (ymd == null || ymd.length < 10) return '—';
  const mo = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final y = ymd.substring(0, 4), m = int.tryParse(ymd.substring(5, 7)) ?? 1, d = int.tryParse(ymd.substring(8, 10)) ?? 1;
  return '$d ${mo[(m - 1).clamp(0, 11)]} $y';
}

String prettyDay(DateTime? t) => t == null
    ? '—'
    : prettyDate('${t.year.toString().padLeft(4, '0')}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}');

/// "06:30" → "6:30 AM".
String prettyTime(String? hm) {
  if (hm == null) return 'Time unknown';
  final p = hm.split(':');
  final h = int.tryParse(p[0]) ?? 0;
  final m = p.length > 1 ? p[1] : '00';
  return '${h % 12 == 0 ? 12 : h % 12}:$m ${h < 12 ? 'AM' : 'PM'}';
}

/// THE ORIGINAL NIGHT SKY (owner, 2026-11-23: "the design and colour should
/// be like the first one"): the Today's Horoscope card's deep violet, its
/// nebula glow and a starfield that twinkles slowly — still when motion is
/// reduced, and under test, where a looping animation would never settle.
class TwinklingSky extends StatefulWidget {
  const TwinklingSky({super.key, this.seed = 7, this.child});
  final int seed;
  final Widget? child;

  @override
  State<TwinklingSky> createState() => _TwinklingSkyState();
}

class _TwinklingSkyState extends State<TwinklingSky> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 7));

  static final bool _underTest = Platform.environment.containsKey('FLUTTER_TEST');

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = _underTest || MediaQuery.maybeDisableAnimationsOf(context) == true;
    if (still) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, child) => CustomPaint(
            painter: CosmicPainter(seed: widget.seed, t: _c.value),
            child: child,
          ),
          child: widget.child,
        ),
      );
}
