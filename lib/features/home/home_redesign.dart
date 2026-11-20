import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../design/neon_tokens.dart';

/// HOME, REDESIGNED (owner, 2026-11-01: "with the exact same color theme
/// redesign the entire homepage"): the day's timeline row and its rail, in
/// the theme's own tokens (Neon.*), so the accent setting still recolours
/// it.

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
