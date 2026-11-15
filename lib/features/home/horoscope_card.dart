import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design/motion.dart';
import '../../design/neon_tokens.dart';
import '../../services/horoscope.dart';

/// The sign's artwork (assets/zodiac/<id>.jpg — gold emblems on a violet
/// starfield). Falls back to the sign's glyph if the image is missing.
class ZodiacArt extends StatelessWidget {
  const ZodiacArt(this.sign, {super.key, this.fit = BoxFit.cover, this.glyphSize = 26});
  final ZodiacSign sign;
  final BoxFit fit;
  final double glyphSize;

  @override
  Widget build(BuildContext context) => Image.asset(
        'assets/zodiac/${sign.id}.jpg',
        fit: fit,
        errorBuilder: (_, __, ___) => Container(
          alignment: Alignment.center,
          color: const Color(0xFF1B1036),
          child: Text(sign.symbol,
              style: TextStyle(fontSize: glyphSize, color: const Color(0xFFE6C36A))),
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
    backgroundColor: Neon.surface,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // The app's sheet theme draws the drag handle already.
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Select Your Zodiac Sign',
                style: NeonType.manrope(17, FontWeight.w800)
                    .copyWith(color: Neon.textHi)),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.82,
            children: [
              for (final s in Horoscope.signs) _SignTile(s, selected: s.id == now?.id,
                  onTap: () => Navigator.pop(ctx, s.id)),
            ],
          ),
          if (now != null)
            TextButton(
              onPressed: () => Navigator.pop(ctx, ''),
              child: const Text('Clear Sign'),
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
  const _SignTile(this.sign, {required this.selected, required this.onTap});
  final ZodiacSign sign;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '${sign.name}, ${sign.dates}',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Stack(fit: StackFit.expand, children: [
              ZodiacArt(sign, glyphSize: 34),
              // A dark fade at the foot so the name reads on any artwork.
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.45, 1],
                    colors: [Colors.transparent, Color(0xE6100822)],
                  ),
                ),
              ),
              Positioned(
                left: 8,
                right: 8,
                bottom: 8,
                child: ExcludeSemantics(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(sign.name,
                        style: NeonType.manrope(13.5, FontWeight.w800)
                            .copyWith(color: Colors.white)),
                    Text(sign.dates,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 10)),
                  ]),
                ),
              ),
              if (selected)
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE6C36A), width: 2),
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// TODAY'S HOROSCOPE on Home (owner, 2026-11-15): after Your Assistant,
/// before Popular Apps. The sign's artwork fills the right of the card;
/// without a sign it invites the user to choose one.
class HoroscopeCard extends StatefulWidget {
  const HoroscopeCard({super.key});

  @override
  State<HoroscopeCard> createState() => _HoroscopeCardState();
}

class _HoroscopeCardState extends State<HoroscopeCard> {
  static const _gold = Color(0xFFE6C36A);
  static const _night = Color(0xFF140B2B);

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
        return Tappable(
          onTap: () => pickZodiacSign(context),
          semanticLabel: r == null
              ? 'Today\'s horoscope. Select your zodiac sign.'
              : 'Today\'s horoscope for ${r.sign.name}. ${r.outlook} '
                  'Focus: ${r.focus}. Lucky colour ${r.luckyColour}, lucky number ${r.luckyNumber}.',
          child: ClipRRect(
            borderRadius: BorderRadius.circular(Neon.rLg),
            child: Container(
              decoration: BoxDecoration(
                color: _night,
                borderRadius: BorderRadius.circular(Neon.rLg),
                border: Border.all(color: _gold.withValues(alpha: 0.35)),
              ),
              child: ExcludeSemantics(
                child: LayoutBuilder(builder: (context, box) => Stack(children: [
                  // The artwork, filling the right of the card.
                  Positioned(
                    top: 0,
                    bottom: 0,
                    right: 0,
                    width: box.maxWidth * 0.52,
                    child: SizedBox.expand(
                      child: r == null
                          ? Image.asset('assets/zodiac/leo.jpg',
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const SizedBox())
                          : ZodiacArt(r.sign, glyphSize: 54),
                    ),
                  ),
                  // Night fading over the artwork's left edge, under the words.
                  const Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          stops: [0.38, 0.62, 1],
                          colors: [_night, Color(0xB3140B2B), Color(0x00140B2B)],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                    child: FractionallySizedBox(
                      widthFactor: 0.66,
                      alignment: Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('TODAY\'S HOROSCOPE',
                              style: NeonType.manrope(11, FontWeight.w800)
                                  .copyWith(color: _gold, letterSpacing: 1.4)),
                          const SizedBox(height: 6),
                          Text(r == null ? 'Your Daily Reading' : r.sign.name,
                              style: NeonType.manrope(22, FontWeight.w800)
                                  .copyWith(color: Colors.white, height: 1.1)),
                          if (r != null)
                            Text(r.sign.dates,
                                style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.6),
                                    fontSize: 11.5)),
                          const SizedBox(height: 8),
                          Text(
                              r == null
                                  ? 'Select your zodiac sign to receive a personal reading every morning.'
                                  : r.outlook,
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontSize: 13,
                                  height: 1.4)),
                          const SizedBox(height: 10),
                          if (r != null)
                            Wrap(spacing: 6, runSpacing: 6, children: [
                              _chip(Icons.track_changes_rounded, r.focus),
                              _chip(Icons.palette_rounded, r.luckyColour),
                              _chip(Icons.tag_rounded, '${r.luckyNumber}'),
                            ])
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: _gold,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text('Select Your Sign',
                                  style: NeonType.manrope(13, FontWeight.w800)
                                      .copyWith(color: _night)),
                            ),
                        ],
                      ),
                    ),
                  ),
                ])),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _chip(IconData icon, String t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _gold.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _gold.withValues(alpha: 0.35)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: _gold),
          const SizedBox(width: 4),
          Flexible(
            child: Text(t,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: _gold, fontSize: 11.5, fontWeight: FontWeight.w600)),
          ),
        ]),
      );
}
