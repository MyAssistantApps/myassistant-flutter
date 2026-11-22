// KUNDLI DRAWINGS (2026-11-22) — the birth chart in the two common styles.
//
// North Indian: houses are fixed (house 1 is the top diamond, counting
// anticlockwise); each house shows its sign number. South Indian: signs
// are fixed (Pisces top-left, clockwise); the lagna's box is marked.
// Without a birth time both start from the Moon's sign (Chandra kundli).

import 'package:flutter/material.dart';

import 'jyotish_models.dart';

enum KundliStyle { north, south }

class KundliColors {
  const KundliColors({
    required this.line,
    required this.sign,
    required this.planet,
    required this.retro,
    required this.lagna,
    required this.fill,
  });
  final Color line, sign, planet, retro, lagna, fill;
}

class KundliChart extends StatelessWidget {
  const KundliChart({
    super.key,
    required this.chart,
    required this.style,
    required this.colors,
  });

  final Chart chart;
  final KundliStyle style;
  final KundliColors colors;

  @override
  Widget build(BuildContext context) {
    final first = chart.firstSign;
    // What a screen reader hears: every occupied house, in order.
    final parts = <String>[];
    for (var h = 1; h <= 12; h++) {
      final sign = (first + h - 1) % 12;
      final here = chart.planets.where((p) => p.sign == sign).map((p) => p.name);
      if (here.isNotEmpty) parts.add('house $h, ${kSigns[sign]}: ${here.join(', ')}');
    }
    final label =
        '${style == KundliStyle.north ? 'North' : 'South'} Indian ${chart.timeKnown ? 'birth chart, lagna ${kSigns[first]}' : 'Moon chart, starting from ${kSigns[first]}'}. ${parts.join('; ')}';
    return Semantics(
      label: label,
      image: true,
      child: AspectRatio(
        aspectRatio: 1,
        child: CustomPaint(
          painter: style == KundliStyle.north
              ? NorthKundliPainter(chart, colors)
              : SouthKundliPainter(chart, colors),
        ),
      ),
    );
  }
}

/// The planets in a sign, as short marks: "Su Me Sa℞".
List<(String, bool)> _marks(Chart chart, int sign) => [
      for (final p in chart.planets)
        if (p.sign == sign) (p.abbr, p.showRetro)
    ];

void _text(Canvas c, String s, Offset center, TextStyle style, {double maxWidth = 80}) {
  final tp = TextPainter(
    text: TextSpan(text: s, style: style),
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.center,
  )..layout(maxWidth: maxWidth);
  tp.paint(c, center - Offset(tp.width / 2, tp.height / 2));
}

/// Planet marks wrapped into lines of [perLine], centred on [center].
void _planets(Canvas c, List<(String, bool)> marks, Offset center, double size,
    KundliColors k, {int perLine = 2, double maxWidth = 80}) {
  if (marks.isEmpty) return;
  final lines = <List<(String, bool)>>[];
  for (var i = 0; i < marks.length; i += perLine) {
    lines.add(marks.sublist(i, (i + perLine).clamp(0, marks.length)));
  }
  final lineH = size * 1.25;
  var y = center.dy - (lines.length - 1) * lineH / 2;
  for (final line in lines) {
    final spans = <InlineSpan>[];
    for (var i = 0; i < line.length; i++) {
      if (i > 0) spans.add(const TextSpan(text: ' '));
      spans.add(TextSpan(text: line[i].$1));
      if (line[i].$2) {
        spans.add(TextSpan(text: 'R', style: TextStyle(color: k.retro, fontSize: size * 0.7)));
      }
    }
    final tp = TextPainter(
      text: TextSpan(
          style: TextStyle(color: k.planet, fontSize: size, fontWeight: FontWeight.w700),
          children: spans),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: maxWidth);
    tp.paint(c, Offset(center.dx - tp.width / 2, y - tp.height / 2));
    y += lineH;
  }
}

class NorthKundliPainter extends CustomPainter {
  NorthKundliPainter(this.chart, this.k);
  final Chart chart;
  final KundliColors k;

  // Where each house's contents sit, in a unit square (house 1 first).
  static const centers = [
    Offset(0.5, 0.27), Offset(0.25, 0.11), Offset(0.11, 0.25), Offset(0.27, 0.5),
    Offset(0.11, 0.75), Offset(0.25, 0.89), Offset(0.5, 0.73), Offset(0.75, 0.89),
    Offset(0.89, 0.75), Offset(0.73, 0.5), Offset(0.89, 0.25), Offset(0.75, 0.11),
  ];
  // Where each house's sign number sits (towards the centre for the diamonds).
  static const signAt = [
    Offset(0.5, 0.44), Offset(0.25, 0.2), Offset(0.2, 0.25), Offset(0.44, 0.5),
    Offset(0.2, 0.75), Offset(0.25, 0.8), Offset(0.5, 0.56), Offset(0.75, 0.8),
    Offset(0.8, 0.75), Offset(0.56, 0.5), Offset(0.8, 0.25), Offset(0.75, 0.2),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final r = Rect.fromLTWH(0, 0, w, w);
    final line = Paint()
      ..color = k.line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(6)), Paint()..color = k.fill);
    canvas.drawRect(r.deflate(0.7), line);
    canvas.drawLine(Offset.zero, Offset(w, w), line);
    canvas.drawLine(Offset(w, 0), Offset(0, w), line);
    final diamond = Path()
      ..moveTo(w / 2, 0)
      ..lineTo(w, w / 2)
      ..lineTo(w / 2, w)
      ..lineTo(0, w / 2)
      ..close();
    canvas.drawPath(diamond, line);
    final first = chart.firstSign;
    final fs = w / 26;
    for (var h = 0; h < 12; h++) {
      final sign = (first + h) % 12;
      _text(canvas, '${sign + 1}', signAt[h] * w,
          TextStyle(color: h == 0 ? k.lagna : k.sign, fontSize: fs * 0.85, fontWeight: FontWeight.w600));
      final diamondHouse = h % 3 == 0; // 1, 4, 7, 10 are the large diamonds
      _planets(canvas, _marks(chart, sign), centers[h] * w, fs, k,
          perLine: diamondHouse ? 3 : 2, maxWidth: w * (diamondHouse ? 0.3 : 0.18));
    }
    if (chart.timeKnown) {
      _text(canvas, 'Asc', Offset(w / 2, w * 0.08),
          TextStyle(color: k.lagna, fontSize: fs * 0.8, fontWeight: FontWeight.w700));
    }
  }

  @override
  bool shouldRepaint(NorthKundliPainter old) => old.chart != chart || old.k != k;
}

class SouthKundliPainter extends CustomPainter {
  SouthKundliPainter(this.chart, this.k);
  final Chart chart;
  final KundliColors k;

  /// The box (column, row) of each sign: Pisces top-left, then clockwise.
  static const cells = [
    (1, 0), (2, 0), (3, 0), (3, 1), (3, 2), (3, 3), // Aries … Virgo
    (2, 3), (1, 3), (0, 3), (0, 2), (0, 1), (0, 0), // Libra … Pisces
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final c = w / 4;
    final line = Paint()
      ..color = k.line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w, w), const Radius.circular(6)),
        Paint()..color = k.fill);
    final fs = w / 26;
    final first = chart.firstSign;
    for (var s = 0; s < 12; s++) {
      final (col, row) = cells[s];
      final box = Rect.fromLTWH(col * c, row * c, c, c);
      canvas.drawRect(box.deflate(0.7), line);
      _text(canvas, kSigns[s].substring(0, 3), box.topLeft + Offset(c * 0.22, c * 0.14),
          TextStyle(color: k.sign, fontSize: fs * 0.7));
      if (s == first) {
        // The lagna (or the Moon's sign): a slash across the corner.
        canvas.drawLine(box.topLeft + Offset(c * 0.62, 0), box.topLeft + Offset(c, c * 0.38),
            Paint()
              ..color = k.lagna
              ..strokeWidth = 2);
        _text(canvas, chart.timeKnown ? 'Asc' : 'Mo', box.topLeft + Offset(c * 0.86, c * 0.12),
            TextStyle(color: k.lagna, fontSize: fs * 0.62, fontWeight: FontWeight.w700));
      }
      _planets(canvas, _marks(chart, s), box.center + Offset(0, c * 0.1), fs, k,
          perLine: 2, maxWidth: c * 0.95);
    }
    _text(canvas, chart.timeKnown ? 'Rashi' : 'Chandra', Offset(w / 2, w / 2 - fs),
        TextStyle(color: k.sign, fontSize: fs * 1.1, fontWeight: FontWeight.w600));
    _text(canvas, 'kundli', Offset(w / 2, w / 2 + fs * 0.6),
        TextStyle(color: k.sign, fontSize: fs * 0.85));
  }

  @override
  bool shouldRepaint(SouthKundliPainter old) => old.chart != chart || old.k != k;
}
