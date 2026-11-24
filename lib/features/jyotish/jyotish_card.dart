// JYOTISH CARD (2026-11-22) — the last card on Home: the way into the
// Vedic horoscope (jyotish_screen.dart). With a camera, to upload a
// horoscope for the assistant to read, and a mic, to talk about it
// (owner, 2026-11-23). Behind them, the same night sky as the horoscope
// slides: violet nebula, stars and the gold constellation of Gemini
// (2026-11-24, CosmicPainter), kept clear of the text. Headed like the
// horoscope slides: TODAY'S HOROSCOPE in gold, then Your Vedic Horoscope
// in white; the camera and the mic centred below; a toran along the top
// (HinduMotifPainter) (owner, 2026-11-24).

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../design/neon_tokens.dart';
import '../../widgets/role_mic_orb.dart';
import '../home/cosmic_painter.dart';
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
        Navigator.of(context)
            .push(MaterialPageRoute<void>(builder: (_) => page));
      }
    }

    return Semantics(
      container: true,
      button: true,
      label:
          "Today's Horoscope. Your Vedic Horoscope: kundli, dasha and readings. Opens the horoscope",
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
              boxShadow: [
                BoxShadow(
                    color: const Color(0xFF2A1B6B).withValues(alpha: 0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 8))
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(Neon.rCard),
              child: CustomPaint(
                painter: CosmicPainter(
                    seed: 3,
                    signId: 'gemini',
                    constellationBox: const Rect.fromLTRB(.60, .08, .97, .64)),
                child: CustomPaint(
                painter: const HinduMotifPainter(),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 26, 20, 22),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                  // The words keep to the left 58%; Gemini has the right.
                  FractionallySizedBox(
                    widthFactor: 0.58,
                    alignment: Alignment.centerLeft,
                    child: ExcludeSemantics(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("TODAY'S HOROSCOPE",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: NeonType.manrope(11, FontWeight.w800)
                                    .copyWith(color: CosmicPainter.gold, letterSpacing: 1.6)),
                            const SizedBox(height: 6),
                            Text('Your Vedic Horoscope',
                                style: GoogleFonts.cormorantGaramond(
                                    fontSize: 30,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    height: 1.05)),
                            const SizedBox(height: 8),
                            Container(
                                width: 36,
                                height: 2,
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(1),
                                    gradient: LinearGradient(colors: [
                                      CosmicPainter.gold,
                                      CosmicPainter.gold.withValues(alpha: 0)
                                    ]))),
                            const SizedBox(height: 8),
                            Text(
                                'Kundli, dasha and readings. Just tell me when and where you were born.',
                                style: NeonType.manrope(12.5, FontWeight.w500).copyWith(
                                    color: Colors.white.withValues(alpha: 0.82), height: 1.4)),
                          ]),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Under the text: the camera and the mic.
                  Center(
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                    // The camera: upload a horoscope for the assistant to read.
                    Semantics(
                      container: true,
                      button: true,
                      label: 'Upload your horoscope',
                      excludeSemantics: true,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          const page = JyotishScreen(startWithUpload: true);
                          if (onOpen != null) {
                            onOpen!(page);
                          } else {
                            Navigator.of(context).push(
                                MaterialPageRoute<void>(builder: (_) => page));
                          }
                        },
                        child: Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black.withValues(alpha: 0.3),
                            border: Border.all(
                                color: Cosmic.gold.withValues(alpha: 0.7),
                                width: 1.5),
                          ),
                          child: const Icon(Icons.photo_camera_rounded,
                              color: Colors.white, size: 26),
                        ),
                      ),
                    ),
                    const SizedBox(width: 18),
                    // The mic: talk about the horoscope, here on Home (the
                    // male Jyotish voice and its tools). The everyday
                    // assistant is back when the conversation ends.
                    RoleMicOrb(
                      role: guruRole,
                      tint: Cosmic.gold,
                      size: 54,
                      showLabel: false,
                      endOnDispose: false,
                      resetRoleWhenDone: true,
                      topic: 'your horoscope',
                      openingNote: () => jyotishMicNote,
                    ),
                    ]),
                  ),
                  ]),
                ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
