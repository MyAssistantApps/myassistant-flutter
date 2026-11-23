// JYOTISH CARD (2026-11-22; redesigned 2026-11-23 for Guruji) — the last
// card on Home: the way into the Vedic horoscope (jyotish_screen.dart), in
// the screen's own temple palette.

import 'package:flutter/material.dart';

import '../../design/neon_tokens.dart';
import 'jyotish_guru.dart';
import 'jyotish_screen.dart';
import 'jyotish_theme.dart';

class JyotishCard extends StatelessWidget {
  const JyotishCard({super.key, this.onOpen});

  /// Opens the screen; Home passes its own navigator helper.
  final void Function(Widget page)? onOpen;

  @override
  Widget build(BuildContext context) {
    void open() {
      const page = JyotishScreen();
      if (onOpen != null) {
        onOpen!(page);
      } else {
        Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
      }
    }

    final radius = BorderRadius.circular(Neon.rCard);
    return Semantics(
      button: true,
      label: "Jyotish. Talk to Guruji: today's bhavishya, your kundli and dasha. Opens Jyotish",
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: radius,
          onTap: open,
          child: Ink(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF5A1424), Color(0xFF3A1238), Color(0xFF1E1145)],
              ),
              borderRadius: radius,
              border: Border.all(color: Mandir.gold.withValues(alpha: 0.45)),
              boxShadow: [
                BoxShadow(color: Mandir.saffron.withValues(alpha: 0.22), blurRadius: 24, offset: const Offset(0, 8)),
              ],
            ),
            child: ClipRRect(
              borderRadius: radius,
              child: CustomPaint(
                painter: TempleDoodlePainter(skylineOnly: true, opacity: 0.2),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
                  child: Row(children: [
                    // Guruji's mandala, still on Home.
                    SizedBox(
                      width: 84,
                      height: 84,
                      child: CustomPaint(painter: GuruOrbPainter(turn: 0, energy: 0, talking: false)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('VEDIC ASTROLOGY',
                            style: NeonType.manrope(10.5, FontWeight.w800)
                                .copyWith(color: Mandir.gold, letterSpacing: 1.6)),
                        const SizedBox(height: 3),
                        Text('Jyotish', style: Cosmic.title(NeonType.title3)),
                        const SizedBox(height: 4),
                        Text("Talk to Guruji — today's bhavishya, your kundli and dasha.",
                            style: Cosmic.label(NeonType.footnote).copyWith(color: Mandir.sandal)),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            gradient: const LinearGradient(colors: [Mandir.gold, Mandir.saffron]),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.mic_rounded, size: 16, color: Color(0xFF3A1206)),
                            const SizedBox(width: 6),
                            Text('Talk to Guruji',
                                style: NeonType.manrope(12.5, FontWeight.w800)
                                    .copyWith(color: const Color(0xFF3A1206))),
                          ]),
                        ),
                      ]),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: Mandir.gold),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
