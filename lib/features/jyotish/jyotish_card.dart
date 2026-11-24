// JYOTISH CARD (2026-11-22) — the last card on Home: the way into the
// Vedic horoscope (jyotish_screen.dart). With a camera, to upload a
// horoscope for the assistant to read, and a mic, to talk about it
// (owner, 2026-11-23). Under them, today's horoscope for all twelve signs
// as a carousel (2026-11-24, today_horoscope.dart).

import 'package:flutter/material.dart';

import '../../design/neon_tokens.dart';
import '../../widgets/role_mic_orb.dart';
import 'jyotish_guru.dart';
import 'jyotish_screen.dart';
import 'jyotish_theme.dart';
import 'today_horoscope.dart';

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
          'Jyotish. Your Vedic horoscope: kundli, dasha and readings. Opens the horoscope',
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
                painter: StarsPainter(count: 28, seed: 3),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(children: [
                  Row(children: [
                    ExcludeSemantics(
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const RadialGradient(colors: [
                            Color(0xFFFFE3A3),
                            Cosmic.gold,
                            Color(0xFFB9852E)
                          ]),
                          boxShadow: [
                            BoxShadow(
                                color: Cosmic.gold.withValues(alpha: 0.45),
                                blurRadius: 18)
                          ],
                        ),
                        child: const Icon(Icons.auto_awesome_rounded,
                            color: Color(0xFF2A1B00), size: 26),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: ExcludeSemantics(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Jyotish',
                                  style: Cosmic.title(NeonType.headline)),
                              const SizedBox(height: 3),
                              Text(
                                  'Your Vedic horoscope — kundli, dasha and readings. Just tell me when and where you were born.',
                                  style: Cosmic.label(NeonType.footnote)),
                            ]),
                      ),
                    ),
                    const SizedBox(width: 8),
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
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black.withValues(alpha: 0.3),
                            border: Border.all(
                                color: Cosmic.gold.withValues(alpha: 0.7),
                                width: 1.5),
                          ),
                          child: const Icon(Icons.photo_camera_rounded,
                              color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // The mic: talk about the horoscope, here on Home (the
                    // male Jyotish voice and its tools). The everyday
                    // assistant is back when the conversation ends.
                    RoleMicOrb(
                      role: guruRole,
                      tint: Cosmic.gold,
                      size: 42,
                      showLabel: false,
                      endOnDispose: false,
                      resetRoleWhenDone: true,
                      topic: 'your horoscope',
                      openingNote: () => jyotishMicNote,
                    ),
                  ]),
                  const SizedBox(height: 16),
                  const TodayHoroscopeCarousel(),
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
