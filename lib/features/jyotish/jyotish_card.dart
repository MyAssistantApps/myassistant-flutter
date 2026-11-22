// JYOTISH CARD (2026-11-22) — the last card on Home: the way into the
// Vedic horoscope (jyotish_screen.dart).

import 'package:flutter/material.dart';

import '../../design/neon_tokens.dart';
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

    return Semantics(
      button: true,
      label: 'Jyotish. Your Vedic horoscope: kundli, dasha and readings. Opens the horoscope',
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(Neon.rCard),
          onTap: open,
          child: Ink(
            decoration: BoxDecoration(
              gradient: Cosmic.brandGradient,
              borderRadius: BorderRadius.circular(Neon.rCard),
              border: Border.all(color: Cosmic.gold.withValues(alpha: 0.35)),
              boxShadow: [BoxShadow(color: const Color(0xFF2A1B6B).withValues(alpha: 0.35), blurRadius: 20, offset: const Offset(0, 8))],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(Neon.rCard),
              child: CustomPaint(
                painter: StarsPainter(count: 28, seed: 3),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const RadialGradient(colors: [Color(0xFFFFE3A3), Cosmic.gold, Color(0xFFB9852E)]),
                        boxShadow: [BoxShadow(color: Cosmic.gold.withValues(alpha: 0.45), blurRadius: 18)],
                      ),
                      child: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF2A1B00), size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Jyotish', style: Cosmic.title(NeonType.headline)),
                        const SizedBox(height: 3),
                        Text('Your Vedic horoscope — kundli, dasha and readings. Just tell me when and where you were born.',
                            style: Cosmic.label(NeonType.footnote)),
                      ]),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.chevron_right_rounded, color: Cosmic.gold),
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
