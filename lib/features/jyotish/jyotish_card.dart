// JYOTISH CARD (2026-11-22) — the last card on Home: the way into the
// Vedic horoscope (jyotish_screen.dart). With a camera, to upload a
// horoscope for the assistant to read, and a mic, to talk about it
// (owner, 2026-11-23).
//
// TODAY'S HOROSCOPE (2026-11-23, owner-approved): the card is the night
// sky of the first Today's Horoscope card — the rashi's constellation in
// gold, today's outlook, a lucky colour and number — for the most recent
// saved profile (today_horoscope.dart). Without one it asks for the birth
// details.

import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../design/neon_tokens.dart';
import '../../widgets/role_mic_orb.dart';
import '../home/cosmic_painter.dart';
import 'jyotish_guru.dart';
import 'jyotish_screen.dart';
import 'jyotish_theme.dart';
import 'today_horoscope.dart';

TextStyle _serif(double size) => GoogleFonts.cormorantGaramond(
    fontSize: size, fontWeight: FontWeight.w700, color: Colors.white, height: 1.0);

TextStyle _overline({Color color = Cosmic.gold}) =>
    NeonType.manrope(10.5, FontWeight.w800).copyWith(color: color, letterSpacing: 2.2);

/// The lucky colours as swatches.
const kLuckySwatches = <String, Color>{
  'Royal Blue': Color(0xFF4169E1),
  'Emerald Green': Color(0xFF50C878),
  'Gold': Color(0xFFD4AF37),
  'Ivory': Color(0xFFFFFFF0),
  'Maroon': Color(0xFF8B1A1A),
  'Silver': Color(0xFFC0C0C0),
  'Saffron': Color(0xFFF4C430),
  'Navy': Color(0xFF2B3A8C),
  'Teal': Color(0xFF14A3A3),
  'Burgundy': Color(0xFF8C1C3A),
  'Pearl White': Color(0xFFF8F6F0),
  'Violet': Color(0xFF8F00FF),
};

String _month(int m) =>
    const ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'][m - 1];

class JyotishCard extends StatefulWidget {
  const JyotishCard({super.key, this.onOpen, this.load = true});

  /// Opens the screen; Home passes its own navigator helper.
  final void Function(Widget page)? onOpen;

  /// For tests: false skips the profile lookup.
  final bool load;

  @override
  State<JyotishCard> createState() => _JyotishCardState();
}

class _JyotishCardState extends State<JyotishCard> {
  @override
  void initState() {
    super.initState();
    if (widget.load) unawaited(TodayHoroscope.load());
  }

  void _go(Widget page) {
    if (widget.onOpen != null) {
      widget.onOpen!(page);
    } else {
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ZodiacSign?>(
      valueListenable: TodayHoroscope.sign,
      builder: (context, sign, _) {
        final r = sign == null ? null : TodayHoroscope.today(sign);
        final d = DateTime.now();
        return Semantics(
          container: true,
          button: true,
          label: r == null
              ? "Jyotish. Today's horoscope: tell me when and where you were born. Opens the horoscope"
              : "Today's horoscope, ${d.day} ${_month(d.month)}. ${r.sign.name} (${r.sign.vedic}). ${r.outlook} "
                  'Lucky colour ${r.luckyColour}, lucky number ${r.luckyNumber}. Opens the horoscope',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(26),
              onTap: () => _go(const JyotishScreen()),
              child: Ink(
                height: 224,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: Cosmic.gold.withValues(alpha: 0.28)),
                  boxShadow: [
                    BoxShadow(
                        color: const Color(0xFF7B2FF7).withValues(alpha: 0.35),
                        blurRadius: 28,
                        offset: const Offset(0, 10)),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(25),
                  child: _Sky(
                    seed: sign == null ? 7 : TodayHoroscope.signs.indexOf(sign) + 1,
                    signId: sign?.id,
                    child: Stack(children: [
                      // The sign's glyph, faint and large, behind the stars.
                      if (sign != null)
                        Positioned(
                          right: -6,
                          bottom: -26,
                          child: ExcludeSemantics(
                            child: Text(sign.symbol,
                                style: TextStyle(fontSize: 150, color: Cosmic.gold.withValues(alpha: 0.07))),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 18, 16, 16),
                        child: LayoutBuilder(
                          builder: (context, box) => SizedBox(
                            width: box.maxWidth * (r == null ? 0.72 : 0.6),
                            child: ExcludeSemantics(child: _words(r, d)),
                          ),
                        ),
                      ),
                      if (r != null)
                        Positioned(
                          right: 14,
                          top: 14,
                          child: Icon(Icons.north_east_rounded,
                              size: 18, color: Colors.white.withValues(alpha: 0.6)),
                        ),
                      Positioned(right: 14, bottom: 14, child: _actions()),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _words(HoroscopeReading? r, DateTime d) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("TODAY'S HOROSCOPE", style: _overline()),
          const SizedBox(height: 2),
          Text('${d.day} ${_month(d.month)}',
              style: _overline(color: Colors.white.withValues(alpha: 0.5)).copyWith(fontSize: 9.5)),
          const SizedBox(height: 10),
          Text(r == null ? 'Jyotish' : r.sign.name,
              maxLines: 1, overflow: TextOverflow.ellipsis, style: _serif(r == null ? 32 : 36)),
          const SizedBox(height: 6),
          Expanded(
            child: Text(
                r == null
                    ? 'Your Vedic horoscope — kundli, dasha and readings. Just tell me when and where you were born.'
                    : r.outlook,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.82), fontSize: 13, height: 1.4)),
          ),
          if (r != null)
            Row(children: [
              _pill(swatch: kLuckySwatches[r.luckyColour], text: r.luckyColour),
              const SizedBox(width: 6),
              _pill(text: 'No. ${r.luckyNumber}'),
            ]),
        ],
      );

  /// The camera (upload a horoscope) and the mic (talk to Guruji).
  Widget _actions() => Row(mainAxisSize: MainAxisSize.min, children: [
        Semantics(
          container: true,
          button: true,
          label: 'Upload your horoscope',
          excludeSemantics: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _go(const JyotishScreen(startWithUpload: true)),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.3),
                border: Border.all(color: Cosmic.gold.withValues(alpha: 0.7), width: 1.5),
              ),
              child: const Icon(Icons.photo_camera_rounded, color: Colors.white, size: 19),
            ),
          ),
        ),
        const SizedBox(width: 10),
        // The mic: talk about the horoscope, here on Home (the male Jyotish
        // voice and its tools). The everyday assistant is back when the
        // conversation ends.
        RoleMicOrb(
          role: guruRole,
          tint: Cosmic.sky,
          size: 40,
          showLabel: false,
          endOnDispose: false,
          resetRoleWhenDone: true,
          topic: 'your horoscope',
          openingNote: () => jyotishMicNote,
        ),
      ]);

  Widget _pill({Color? swatch, required String text}) => Flexible(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (swatch != null) ...[
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: swatch,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 0.8),
                ),
              ),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: NeonType.manrope(11.5, FontWeight.w700).copyWith(color: Colors.white)),
            ),
          ]),
        ),
      );
}

/// A living night sky: twinkles slowly unless motion is reduced (and never
/// under test, where a looping animation would never settle). The
/// constellation sits top right, clear of the camera and mic.
class _Sky extends StatefulWidget {
  const _Sky({required this.seed, this.signId, this.child});
  final int seed;
  final String? signId;
  final Widget? child;

  @override
  State<_Sky> createState() => _SkyState();
}

class _SkyState extends State<_Sky> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 7));

  static final bool _underTest = Platform.environment.containsKey('FLUTTER_TEST');

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = _underTest || MediaQuery.maybeDisableAnimationsOf(context) == true;
    if (still) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, child) => CustomPaint(
          painter: CosmicPainter(
              seed: widget.seed,
              signId: widget.signId,
              t: _c.value,
              constellationBox: const Rect.fromLTRB(.62, .1, .94, .7)),
          child: child,
        ),
        child: widget.child,
      );
}
