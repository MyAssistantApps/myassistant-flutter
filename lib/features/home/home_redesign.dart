import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design/neon_tokens.dart';

/// HOME, REDESIGNED (owner, 2026-11-01: "with the exact same color theme
/// redesign the entire homepage"). One bold idea: the logo's ring — cyan
/// into violet into pink, the ring round the robot — used in ONE place, the
/// briefing bar ("Play my day": her voice, the app's signature). Everything
/// else is quiet glass in the theme's own tokens (Neon.*), so the accent
/// setting still recolours it.

/// The ring's light, from the theme.
List<Color> ringColors() => [Neon.cyan, Neon.violet, Neon.pink, Neon.cyan];

/// THE BRIEFING BAR: the day, read aloud, in the logo's ring.
class BriefingBar extends StatelessWidget {
  const BriefingBar({
    super.key,
    required this.title,
    required this.hint,
    required this.icon,
    required this.playing,
    required this.busy,
    required this.onPressed,
  });

  final String title;
  final String hint;
  final IconData icon;
  final bool playing;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(28);
    return Semantics(
      button: true,
      label: '$title. $hint',
      excludeSemantics: true,
      child: Container(
        // The ring: a 1.6 dp sweep of the logo's light, softly glowing.
        padding: const EdgeInsets.all(1.6),
        decoration: BoxDecoration(
          borderRadius: r,
          gradient: SweepGradient(
              colors: ringColors(),
              transform: const GradientRotation(-math.pi / 2)),
          boxShadow: [
            BoxShadow(
                color: Neon.violet.withValues(alpha: 0.35),
                blurRadius: 24,
                spreadRadius: -6),
          ],
        ),
        child: Material(
          color: Color.lerp(Neon.bg, Colors.black, 0.25),
          borderRadius: BorderRadius.circular(26.4),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: busy
                ? null
                : () {
                    HapticFeedback.selectionClick();
                    onPressed();
                  },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 18, 12),
              child: Row(
                children: [
                  _Disc(icon: icon, busy: busy),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(title,
                            style: NeonType.manrope(17, FontWeight.w800)
                                .copyWith(
                                    color: Neon.textHi, letterSpacing: -0.2)),
                        const SizedBox(height: 2),
                        Text(hint,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: Neon.textLo,
                                fontSize: NeonType.footnote)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Waveform(active: playing),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Disc extends StatelessWidget {
  const _Disc({required this.icon, required this.busy});
  final IconData icon;
  final bool busy;

  @override
  Widget build(BuildContext context) => Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Neon.cyan, Neon.violet, Neon.pink],
          ),
          boxShadow: [
            BoxShadow(color: Neon.cyan.withValues(alpha: 0.35), blurRadius: 14)
          ],
        ),
        child: busy
            ? const Padding(
                padding: EdgeInsets.all(15),
                child: CircularProgressIndicator(
                    strokeWidth: 2.4, color: Colors.white),
              )
            : Icon(icon, color: Colors.white, size: 30),
      );
}

/// Her voice as five bars: still at rest, moving only while she reads the
/// day (the one motion on Home that answers something).
class Waveform extends StatefulWidget {
  const Waveform({super.key, required this.active});
  final bool active;

  @override
  State<Waveform> createState() => _WaveformState();
}

class _WaveformState extends State<Waveform>
    with SingleTickerProviderStateMixin {
  late final AnimationController _t = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100));

  void _sync() {
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (widget.active && !still) {
      if (!_t.isAnimating) _t.repeat();
    } else {
      _t.stop();
      _t.value = 0;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(Waveform old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 34,
        height: 26,
        child: CustomPaint(painter: _WavePainter(_t, widget.active)),
      );
}

class _WavePainter extends CustomPainter {
  _WavePainter(this.t, this.active) : super(repaint: t);
  final Animation<double> t;
  final bool active;
  static const _rest = [0.35, 0.7, 1.0, 0.6, 0.3];

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width / (_rest.length * 2 - 1);
    final shader = ui.Gradient.linear(
        Offset.zero, Offset(size.width, 0), [Neon.cyan, Neon.pink]);
    final p = Paint()
      ..shader = shader
      ..strokeCap = StrokeCap.round
      ..strokeWidth = w;
    for (var i = 0; i < _rest.length; i++) {
      final level = active
          ? 0.3 +
              0.7 * (0.5 + 0.5 * math.sin((t.value + i * 0.17) * 2 * math.pi))
          : _rest[i] * 0.6;
      final h = math.max(w, size.height * level);
      final x = w / 2 + i * w * 2;
      canvas.drawLine(Offset(x, (size.height - h) / 2 + w / 2),
          Offset(x, (size.height + h) / 2 - w / 2), p);
    }
  }

  @override
  bool shouldRepaint(_WavePainter old) => old.active != active;
}

/// One row of the day's timeline: the time, a dot on the rail, the thing.
/// [first]/[last] trim the rail at the ends.
class TimelineRow extends StatelessWidget {
  const TimelineRow({
    super.key,
    required this.time,
    required this.title,
    required this.icon,
    required this.first,
    required this.last,
    required this.onTap,
  });

  final String time;
  final String title;
  final IconData icon;
  final bool first;
  final bool last;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$time, $title',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 60),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 70,
                  child: Center(
                    child: Text(
                      time,
                      textAlign: TextAlign.right,
                      style: NeonType.manrope(NeonType.body, FontWeight.w700)
                          .copyWith(
                        color: Neon.textLo,
                        fontFeatures: NeonType.figures,
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 34,
                  child: CustomPaint(
                      painter: _RailPainter(first: first, last: last)),
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: NeonType.manrope(NeonType.callout, FontWeight.w600)
                          .copyWith(color: Neon.textHi, height: 1.3),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Icon(icon, size: 18, color: Neon.textDim),
                const SizedBox(width: 6),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RailPainter extends CustomPainter {
  _RailPainter({required this.first, required this.last});
  final bool first;
  final bool last;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final rail = Paint()
      ..strokeWidth = 2
      ..shader = ui.Gradient.linear(Offset(cx, 0), Offset(cx, size.height), [
        Neon.cyan.withValues(alpha: 0.55),
        Neon.violet.withValues(alpha: 0.55)
      ]);
    if (!first) canvas.drawLine(Offset(cx, 0), Offset(cx, cy - 7), rail);
    if (!last) {
      canvas.drawLine(Offset(cx, cy + 7), Offset(cx, size.height), rail);
    }
    canvas.drawCircle(Offset(cx, cy), 9,
        Paint()..color = Neon.violet.withValues(alpha: 0.22));
    canvas.drawCircle(
      Offset(cx, cy),
      5,
      Paint()
        ..shader = ui.Gradient.linear(Offset(cx - 5, cy - 5),
            Offset(cx + 5, cy + 5), [Neon.cyan, Neon.violet]),
    );
  }

  @override
  bool shouldRepaint(_RailPainter old) =>
      old.first != first || old.last != last;
}

/// A tool on Home: a tinted icon over its name, the whole tile a target.
class ToolTile extends StatelessWidget {
  const ToolTile(
      {super.key,
      required this.label,
      required this.icon,
      required this.tint,
      required this.onTap});
  final String label;
  final IconData icon;
  final Color tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: 'Open $label',
        excludeSemantics: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(17),
                    color: tint.withValues(alpha: 0.14),
                    border: Border.all(color: tint.withValues(alpha: 0.35)),
                  ),
                  child: Icon(icon, color: tint, size: 25),
                ),
                const SizedBox(height: 7),
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: NeonType.manrope(12.5, FontWeight.w600)
                        .copyWith(color: Neon.textLo)),
              ],
            ),
          ),
        ),
      );
}
