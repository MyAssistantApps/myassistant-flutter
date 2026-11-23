// JYOTISH CARD (2026-11-22) — the last card on Home: the way into the
// Vedic horoscope (jyotish_screen.dart). Drawn as the original Today's
// Horoscope card (owner, 2026-11-23: "the design and colour should be like
// the first one, including Today's Horoscope; put the camera and the mic"):
// its violet night sky, gold overline and serif title — with a camera to
// upload a horoscope for the assistant to read, and a mic to talk to Guruji.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../design/neon_tokens.dart';
import 'jyotish_screen.dart';
import 'jyotish_theme.dart';

const _gold = Color(0xFFE6C36A);
const _ink = Color(0xFF0B0620);

TextStyle _serif(double size) => GoogleFonts.cormorantGaramond(
    fontSize: size,
    fontWeight: FontWeight.w700,
    color: Colors.white,
    height: 1.0);

TextStyle _overline({Color color = _gold}) =>
    NeonType.manrope(10.5, FontWeight.w800)
        .copyWith(color: color, letterSpacing: 2.2);

String _month(int m) => const [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC'
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
    return Semantics(
      container: true,
      button: true,
      label: "Today's horoscope. Talk to Guruji about your Vedic horoscope: "
          "today's bhavishya, your kundli and dasha. Opens Jyotish",
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(26),
          onTap: () => _go(context, const JyotishScreen()),
          child: Container(
            height: 214,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: _gold.withValues(alpha: 0.28)),
              boxShadow: [
                BoxShadow(
                    color: const Color(0xFF7B2FF7).withValues(alpha: 0.35),
                    blurRadius: 28,
                    offset: const Offset(0, 10)),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(25),
              child: TwinklingSky(
                seed: 7,
                child: Stack(children: [
                  // ॐ, faint and large, behind the stars (where the sign's
                  // glyph sat on the first card).
                  Positioned(
                    right: -4,
                    bottom: -34,
                    child: ExcludeSemantics(
                      child: Text('ॐ',
                          style: TextStyle(
                              fontSize: 150,
                              color: _gold.withValues(alpha: 0.07))),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 16, 16),
                    child: ExcludeSemantics(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("TODAY'S HOROSCOPE", style: _overline()),
                            const SizedBox(height: 2),
                            Text('${d.day} ${_month(d.month)}',
                                style: _overline(
                                        color:
                                            Colors.white.withValues(alpha: 0.5))
                                    .copyWith(fontSize: 9.5)),
                            const SizedBox(height: 10),
                            // The whole width: the title is never cut short.
                            Text('Discover Your Day',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: _serif(30)),
                            const SizedBox(height: 6),
                            Expanded(
                              child: Padding(
                                // room for the camera and the mic
                                padding: const EdgeInsets.only(right: 128),
                                child: Text(
                                    "Guruji reads your Vedic horoscope — today's bhavishya, your kundli and dasha.",
                                    maxLines: 4,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        color: Colors.white
                                            .withValues(alpha: 0.82),
                                        fontSize: 13,
                                        height: 1.4)),
                              ),
                            ),
                          ]),
                    ),
                  ),
                  // The camera and the mic, as on the professional pages.
                  Positioned(
                    right: 16,
                    bottom: 14,
                    child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _RoundAction(
                            icon: Icons.photo_camera_rounded,
                            label: 'Upload',
                            semanticLabel:
                                'Upload your horoscope for Guruji to read',
                            onTap: () => _go(context,
                                const JyotishScreen(startWithUpload: true)),
                          ),
                          const SizedBox(width: 12),
                          _RoundAction(
                            icon: Icons.mic_rounded,
                            label: 'Tap to Talk',
                            semanticLabel: 'Talk to Guruji',
                            gold: true,
                            onTap: () => _go(context, const JyotishScreen()),
                          ),
                        ]),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A round button with its caption under it: glass for the camera, gold
/// for the mic.
class _RoundAction extends StatelessWidget {
  const _RoundAction({
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
  Widget build(BuildContext context) => Semantics(
        container: true,
        button: true,
        label: semanticLabel,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: gold
                    ? const LinearGradient(
                        colors: [Color(0xFFF3D98B), Color(0xFFC9A04A)])
                    : null,
                color: gold ? null : Colors.black.withValues(alpha: 0.35),
                border: Border.all(
                    color: _gold.withValues(alpha: gold ? 0.9 : 0.7),
                    width: 1.5),
                boxShadow: [
                  BoxShadow(
                      color: _gold.withValues(alpha: gold ? 0.45 : 0.2),
                      blurRadius: 14),
                ],
              ),
              child: Icon(icon, size: 24, color: gold ? _ink : Colors.white),
            ),
            const SizedBox(height: 6),
            Text(label,
                style: NeonType.manrope(11.5, FontWeight.w700)
                    .copyWith(color: Colors.white)),
          ]),
        ),
      );
}
