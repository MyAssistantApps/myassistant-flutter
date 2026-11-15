import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../design/motion.dart';
import '../../design/neon_tokens.dart';
import '../../services/horoscope.dart';
import 'cosmic_painter.dart';

const _gold = Color(0xFFE6C36A);
const _ink = Color(0xFF0B0620);

TextStyle _serif(double size, {Color color = Colors.white}) =>
    GoogleFonts.cormorantGaramond(
        fontSize: size, fontWeight: FontWeight.w700, color: color, height: 1.0);

TextStyle _overline({Color color = _gold}) => NeonType.manrope(10.5, FontWeight.w800)
    .copyWith(color: color, letterSpacing: 2.2);

const _swatches = <String, Color>{
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

String _month(int m) => const [
      'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
      'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'
    ][m - 1];

/// A living night sky: twinkles slowly unless motion is reduced (and never
/// under test, where a looping animation would never settle).
class CosmicSky extends StatefulWidget {
  const CosmicSky({super.key, required this.seed, this.signId, this.constellationBox, this.child});
  final int seed;
  final String? signId;
  final Rect? constellationBox;
  final Widget? child;

  @override
  State<CosmicSky> createState() => _CosmicSkyState();
}

class _CosmicSkyState extends State<CosmicSky> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 7));

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
  Widget build(BuildContext context) => RepaintBoundary(
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, child) => CustomPaint(
            painter: CosmicPainter(
                seed: widget.seed,
                signId: widget.signId,
                t: _c.value,
                constellationBox: widget.constellationBox),
            child: child,
          ),
          child: widget.child,
        ),
      );
}

/// Lets the user choose a zodiac sign. Returns the sign chosen, or null
/// when the sheet is dismissed. "Clear Sign" removes the sign.
Future<ZodiacSign?> pickZodiacSign(BuildContext context) async {
  HapticFeedback.selectionClick();
  final now = Horoscope.current.value;
  final picked = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: _ink,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('YOUR ZODIAC SIGN', style: _overline()),
          const SizedBox(height: 6),
          Text('Select Your Sign', style: _serif(28)),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.86,
            children: [
              for (final (i, s) in Horoscope.signs.indexed)
                _SignTile(s, seed: i + 11, selected: s.id == now?.id,
                    onTap: () => Navigator.pop(ctx, s.id)),
            ],
          ),
          if (now != null)
            TextButton(
              onPressed: () => Navigator.pop(ctx, ''),
              child: Text('Clear Sign',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7))),
            ),
        ]),
      ),
    ),
  );
  if (picked == null) return null;
  final sign = picked.isEmpty ? null : Horoscope.byId(picked);
  await Horoscope.save(sign);
  return sign;
}

class _SignTile extends StatelessWidget {
  const _SignTile(this.sign, {required this.seed, required this.selected, required this.onTap});
  final ZodiacSign sign;
  final int seed;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '${sign.name}, ${sign.dates}',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: selected ? _gold : Colors.white.withValues(alpha: 0.10),
                width: selected ? 1.6 : 1),
            boxShadow: selected
                ? [BoxShadow(color: _gold.withValues(alpha: 0.35), blurRadius: 16)]
                : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(17),
            child: CustomPaint(
              painter: CosmicPainter(
                  seed: seed,
                  signId: sign.id,
                  t: 0.25,
                  constellationBox: const Rect.fromLTRB(.12, .06, .88, .62)),
              child: ExcludeSemantics(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(6, 0, 6, 10),
                  child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                    Text(sign.name, style: _serif(19)),
                    const SizedBox(height: 3),
                    Text(sign.dates,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6), fontSize: 9.5)),
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

/// The full reading: the sky with the sign's constellation, the outlook,
/// focus, colour and number, and a way to change sign.
Future<void> showHoroscopeReading(BuildContext context, ZodiacSign sign) {
  HapticFeedback.selectionClick();
  final r = Horoscope.today(sign);
  final d = DateTime.now();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: _ink,
    clipBehavior: Clip.antiAlias,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => SafeArea(
      top: false,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          height: 250,
          child: CosmicSky(
            seed: Horoscope.signs.indexOf(sign) + 101,
            signId: sign.id,
            constellationBox: const Rect.fromLTRB(.18, .08, .82, .7),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('${d.day} ${_month(d.month)} · TODAY', style: _overline()),
                  const SizedBox(height: 6),
                  Text(sign.name, style: _serif(42)),
                  const SizedBox(height: 4),
                  Text('${sign.dates} · ${sign.element} sign',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.65), fontSize: 12)),
                ]),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('YOUR DAY', style: _overline()),
            const SizedBox(height: 8),
            Text(r.outlook,
                style: _serif(22, color: Colors.white.withValues(alpha: 0.95))
                    .copyWith(height: 1.3, fontWeight: FontWeight.w600)),
            const SizedBox(height: 18),
            Row(children: [
              Expanded(child: _Fact('FOCUS', r.focus)),
              const SizedBox(width: 10),
              Expanded(
                  child: _Fact('LUCKY COLOUR', r.luckyColour,
                      swatch: _swatches[r.luckyColour])),
              const SizedBox(width: 10),
              Expanded(child: _Fact('LUCKY NUMBER', '${r.luckyNumber}', big: true)),
            ]),
            const SizedBox(height: 14),
            Center(
              child: TextButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  pickZodiacSign(context);
                },
                icon: const Icon(Icons.swap_horiz_rounded, color: _gold, size: 18),
                label: const Text('Change Sign', style: TextStyle(color: _gold)),
              ),
            ),
          ]),
        ),
      ]),
    ),
  );
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value, {this.swatch, this.big = false});
  final String label;
  final String value;
  final Color? swatch;
  final bool big;

  @override
  Widget build(BuildContext context) => Container(
        height: 92,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: _overline(color: Colors.white.withValues(alpha: 0.55))
              .copyWith(fontSize: 9, letterSpacing: 1.4)),
          const Spacer(),
          if (swatch != null) ...[
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: swatch,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
              ),
            ),
            const SizedBox(height: 6),
          ],
          Text(value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: big
                  ? _serif(30, color: _gold)
                  : NeonType.manrope(12.5, FontWeight.w700)
                      .copyWith(color: Colors.white, height: 1.2)),
        ]),
      );
}

/// TODAY'S HOROSCOPE on Home (owner, 2026-11-15): after Your Assistant,
/// before Popular Apps. A living night sky with the sign's constellation;
/// tap for the full reading, or to choose a sign.
class HoroscopeCard extends StatefulWidget {
  const HoroscopeCard({super.key});

  @override
  State<HoroscopeCard> createState() => _HoroscopeCardState();
}

class _HoroscopeCardState extends State<HoroscopeCard> {
  @override
  void initState() {
    super.initState();
    Horoscope.load();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ZodiacSign?>(
      valueListenable: Horoscope.current,
      builder: (context, sign, _) {
        final r = sign == null ? null : Horoscope.today(sign);
        final d = DateTime.now();
        return Tappable(
          onTap: () => sign == null
              ? pickZodiacSign(context)
              : showHoroscopeReading(context, sign),
          semanticLabel: r == null
              ? 'Today\'s horoscope. Select your zodiac sign.'
              : 'Today\'s horoscope for ${r.sign.name}. ${r.outlook} '
                  'Focus: ${r.focus}. Lucky colour ${r.luckyColour}, lucky number ${r.luckyNumber}.',
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
              child: CosmicSky(
                seed: sign == null ? 7 : Horoscope.signs.indexOf(sign) + 1,
                signId: sign?.id,
                child: ExcludeSemantics(
                  child: Stack(children: [
                    // The sign's glyph, faint and large, behind the stars.
                    if (sign != null)
                      Positioned(
                        right: -6,
                        bottom: -26,
                        child: Text(sign.symbol,
                            style: TextStyle(
                                fontSize: 150,
                                color: _gold.withValues(alpha: 0.07))),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 16, 16),
                      child: LayoutBuilder(
                        builder: (context, box) => SizedBox(
                          width: box.maxWidth * (r == null ? 0.78 : 0.6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("TODAY'S HOROSCOPE", style: _overline()),
                              const SizedBox(height: 2),
                              Text('${d.day} ${_month(d.month)}',
                                  style: _overline(
                                          color: Colors.white.withValues(alpha: 0.5))
                                      .copyWith(fontSize: 9.5)),
                              const SizedBox(height: 10),
                              Text(r == null ? 'Discover Your Day' : r.sign.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: _serif(r == null ? 30 : 36)),
                              const SizedBox(height: 6),
                              Expanded(
                                child: Text(
                                    r == null
                                        ? 'Choose your zodiac sign for a personal reading every morning.'
                                        : r.outlook,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.82),
                                        fontSize: 13,
                                        height: 1.4)),
                              ),
                              if (r != null)
                                Row(children: [
                                  _pill(swatch: _swatches[r.luckyColour], text: r.luckyColour),
                                  const SizedBox(width: 6),
                                  _pill(text: 'No. ${r.luckyNumber}'),
                                ])
                              else
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 9),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(colors: [
                                      Color(0xFFF3D98B),
                                      Color(0xFFC9A04A)
                                    ]),
                                    borderRadius: BorderRadius.circular(22),
                                    boxShadow: [
                                      BoxShadow(
                                          color: _gold.withValues(alpha: 0.45),
                                          blurRadius: 14)
                                    ],
                                  ),
                                  child: Text('Select Your Sign',
                                      style: NeonType.manrope(13, FontWeight.w800)
                                          .copyWith(color: _ink)),
                                ),
                            ],
                          ),
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
                  ]),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

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
                  style: NeonType.manrope(11.5, FontWeight.w700)
                      .copyWith(color: Colors.white)),
            ),
          ]),
        ),
      );
}
