import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../design/neon_tokens.dart';

/// HOME, REDESIGNED (owner, 2026-11-01: "with the exact same color theme
/// redesign the entire homepage"): the day's timeline row and its rail, in
/// the theme's own tokens (Neon.*), so the accent setting still recolours
/// it.

/// EACH ROW ITS OWN COLOUR (2026-11-22, Manish: "make them different
/// colours, different for each one"): Home's reminder rows and timeline
/// rows take a colour by position from this bright set, so no two rows
/// next to each other match. The same in both themes.
const homeRowColors = <Color>[
  Color(0xFFA855F7), // violet
  Color(0xFF14B8A6), // teal
  Color(0xFFF59E0B), // amber
  Color(0xFFEC4899), // pink
  Color(0xFF3B82F6), // blue
  Color(0xFF22C55E), // green
];

/// The colour of the [i]th row.
Color homeRowColor(int i) => homeRowColors[i % homeRowColors.length];

/// One row of the day's timeline: the time, a dot on the rail, the thing.
/// [first]/[last] trim the rail at the ends. [color] (optional) colours
/// its dot and tints the row.
class TimelineRow extends StatelessWidget {
  const TimelineRow({
    super.key,
    required this.time,
    required this.title,
    required this.icon,
    required this.first,
    required this.last,
    required this.onTap,
    this.color,
  });

  final Color? color;
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
        child: Container(
          constraints: const BoxConstraints(minHeight: 60),
          margin: color == null ? null : const EdgeInsets.symmetric(vertical: 3, horizontal: 2),
          decoration: color == null
              ? null
              : BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: LinearGradient(colors: [
                    color!.withValues(alpha: Neon.isDark ? 0.20 : 0.12),
                    color!.withValues(alpha: Neon.isDark ? 0.05 : 0.03),
                  ]),
                  border: Border.all(color: color!.withValues(alpha: 0.35)),
                ),
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
                      painter: _RailPainter(first: first, last: last, color: color)),
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
                Icon(icon, size: 18, color: color ?? Neon.textDim),
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
  _RailPainter({required this.first, required this.last, this.color});
  final bool first;
  final bool last;
  final Color? color;

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
    final c = color;
    canvas.drawCircle(Offset(cx, cy), 9,
        Paint()..color = (c ?? Neon.violet).withValues(alpha: c == null ? 0.22 : 0.32));
    canvas.drawCircle(
      Offset(cx, cy),
      5,
      c != null
          ? (Paint()..color = c)
          : (Paint()
            ..shader = ui.Gradient.linear(Offset(cx - 5, cy - 5),
                Offset(cx + 5, cy + 5), [Neon.cyan, Neon.violet])),
    );
  }

  @override
  bool shouldRepaint(_RailPainter old) =>
      old.first != first || old.last != last || old.color != color;
}
