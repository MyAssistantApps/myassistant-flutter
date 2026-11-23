// JYOTISH CARD (2026-11-22) — the last card on Home: the way into the
// Vedic horoscope (jyotish_screen.dart). Owner, 2026-11-23: the first
// Jyotish card's design and colours (deep indigo, starlight, the glowing
// gold circle), with Today's Horoscope on it, a camera to upload a horoscope
// for the assistant to read, and a mic to talk to Guruji.

import 'package:flutter/material.dart';

import '../../design/neon_tokens.dart';
import 'jyotish_screen.dart';
import 'jyotish_theme.dart';

String _month(int m) => const [
      'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
      'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'
    ][m - 1];

class JyotishCard extends StatelessWidget {
  const JyotishCard({super.key, this.onOpen});

  /// Opens the screen; Home passes its own navigator helper.
  final void Function(Widget page)? onOpen;

  void _go(BuildContext context, Widget page) {
    if (onOpen != null) {
      onOpen!(page);
    } else {
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = DateTime.now();
    final radius = BorderRadius.circular(Neon.rCard);
    return Semantics(
      container: true,
      button: true,
      label: "Jyotish, today's horoscope. Your Vedic horoscope: today's bhavishya, "
          'kundli and dasha. Opens Jyotish',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: radius,
          onTap: () => _go(context, const JyotishScreen()),
          child: Ink(
            decoration: BoxDecoration(
              gradient: Cosmic.brandGradient,
              borderRadius: radius,
              border: Border.all(color: Cosmic.gold.withValues(alpha: 0.35)),
              boxShadow: [
                BoxShadow(
                    color: const Color(0xFF2A1B6B).withValues(alpha: 0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 8)),
              ],
            ),
            child: ClipRRect(
              borderRadius: radius,
              child: CustomPaint(
                painter: StarsPainter(count: 28, seed: 3),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    ExcludeSemantics(
                      child: Row(children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const RadialGradient(
                                colors: [Color(0xFFFFE3A3), Cosmic.gold, Color(0xFFB9852E)]),
                            boxShadow: [
                              BoxShadow(color: Cosmic.gold.withValues(alpha: 0.45), blurRadius: 18),
                            ],
                          ),
                          child: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF2A1B00), size: 26),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text("TODAY'S HOROSCOPE · ${d.day} ${_month(d.month)}",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: NeonType.manrope(10.5, FontWeight.w800)
                                    .copyWith(color: Cosmic.gold, letterSpacing: 1.6)),
                            const SizedBox(height: 3),
                            Text('Jyotish', style: Cosmic.title(NeonType.headline)),
                            const SizedBox(height: 3),
                            Text(
                                "Your Vedic horoscope — today's bhavishya, kundli and dasha. "
                                'Just tell me when and where you were born.',
                                style: Cosmic.label(NeonType.footnote)),
                          ]),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.chevron_right_rounded, color: Cosmic.gold),
                      ]),
                    ),
                    const SizedBox(height: 14),
                    // The camera and the mic.
                    Row(children: [
                      Expanded(
                        child: _Action(
                          icon: Icons.photo_camera_rounded,
                          label: 'Upload Horoscope',
                          semanticLabel: 'Upload your horoscope for Guruji to read',
                          onTap: () => _go(context, const JyotishScreen(startWithUpload: true)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _Action(
                          icon: Icons.mic_rounded,
                          label: 'Talk to Guruji',
                          semanticLabel: 'Talk to Guruji',
                          gold: true,
                          onTap: () => _go(context, const JyotishScreen()),
                        ),
                      ),
                    ]),
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

/// A pill button: outlined gold for the camera, filled gold for the mic.
class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.label,
    required this.semanticLabel,
    required this.onTap,
    this.gold = false,
  });
  final IconData icon;
  final String label;
  final String semanticLabel;
  final VoidCallback onTap;
  final bool gold;

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF2A1B00);
    final r = BorderRadius.circular(22);
    return Semantics(
      container: true,
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: r,
          onTap: onTap,
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
            decoration: BoxDecoration(
              borderRadius: r,
              gradient: gold ? const LinearGradient(colors: [Color(0xFFFFE3A3), Cosmic.gold]) : null,
              color: gold ? null : Colors.white.withValues(alpha: 0.06),
              border: Border.all(color: Cosmic.gold.withValues(alpha: gold ? 0.9 : 0.6)),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, size: 18, color: gold ? ink : Cosmic.gold),
              const SizedBox(width: 6),
              Flexible(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: NeonType.manrope(13, FontWeight.w800)
                        .copyWith(color: gold ? ink : Cosmic.ink)),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
