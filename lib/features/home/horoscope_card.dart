import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design/motion.dart';
import '../../design/neon_tokens.dart';
import '../../services/horoscope.dart';

/// Lets the user choose a zodiac sign. Returns the sign chosen, or null
/// when the sheet is dismissed. "Clear" removes the sign.
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
          Container(
            width: 38,
            height: 4,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
                color: Neon.textDim.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(2)),
          ),
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
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.15,
            children: [
              for (final s in Horoscope.signs)
                Material(
                  color: s.id == now?.id
                      ? Neon.violet.withValues(alpha: 0.22)
                      : Neon.violet.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => Navigator.pop(ctx, s.id),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(s.symbol,
                            style: TextStyle(fontSize: 24, color: Neon.violet)),
                        const SizedBox(height: 2),
                        Text(s.name,
                            style: NeonType.manrope(13.5, FontWeight.w700)
                                .copyWith(color: Neon.textHi)),
                        Text(s.dates,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Neon.textLo, fontSize: 10.5)),
                      ],
                    ),
                  ),
                ),
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

/// TODAY'S HOROSCOPE on Home (owner, 2026-11-15): after Your Assistant,
/// before Popular Apps. Without a sign it invites the user to choose one.
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
        return Tappable(
          onTap: () => pickZodiacSign(context),
          semanticLabel: r == null
              ? 'Today\'s horoscope. Select your zodiac sign.'
              : 'Today\'s horoscope for ${r.sign.name}. ${r.outlook} '
                  'Focus: ${r.focus}. Lucky colour ${r.luckyColour}, lucky number ${r.luckyNumber}.',
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: Neon.glassBox(Neon.rLg),
            child: ExcludeSemantics(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Neon.violet.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: r == null
                        ? Icon(Icons.auto_awesome_rounded,
                            color: Neon.violet, size: 24)
                        : Text(r.sign.symbol,
                            style: TextStyle(fontSize: 26, color: Neon.violet)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            r == null
                                ? 'Today\'s Horoscope'
                                : 'Today\'s Horoscope · ${r.sign.name}',
                            style: NeonType.manrope(16, FontWeight.w800)
                                .copyWith(color: Neon.textHi)),
                        const SizedBox(height: 4),
                        Text(
                            r == null
                                ? 'Select your zodiac sign to receive your daily reading.'
                                : r.outlook,
                            style: TextStyle(
                                color: Neon.textLo, fontSize: 13, height: 1.4)),
                        if (r != null) ...[
                          const SizedBox(height: 8),
                          Wrap(spacing: 8, runSpacing: 6, children: [
                            _chip('Focus: ${r.focus}'),
                            _chip('Colour: ${r.luckyColour}'),
                            _chip('Number: ${r.luckyNumber}'),
                          ]),
                        ],
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded,
                      color: Neon.textDim, size: 22),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _chip(String t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Neon.violet.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(t,
            style: TextStyle(
                color: Neon.violet, fontSize: 11.5, fontWeight: FontWeight.w600)),
      );
}
