// TODAY'S HOROSCOPE ON THE JYOTISH CARD (2026-11-23, owner-approved):
// the night-sky card with the sign's constellation, today's outlook, a
// lucky colour and number. The sign is the Moon sign (rashi) of the most
// recent saved Jyotish profile — the chart the Jyotish screen opens on —
// so there is no separate sign to choose. No saved profile: the card asks
// for the birth details instead.
//
// The day's words are composed on the phone, deterministically (same sign,
// same day, same reading), as the first Today's Horoscope card did
// (2026-11-15): Home never waits on an AI call. The full reading stays on
// the Jyotish screen.

import 'package:flutter/foundation.dart';

import 'jyotish_service.dart';

/// One of the twelve rashis, in the server's order (0 = Aries).
class ZodiacSign {
  const ZodiacSign(this.id, this.name, this.vedic, this.symbol, this.element);

  /// Lower-case English name; also the constellation's key in CosmicPainter.
  final String id;
  final String name;
  final String vedic;
  final String symbol;
  final String element;
}

/// A day's reading for one sign.
@immutable
class HoroscopeReading {
  const HoroscopeReading({
    required this.sign,
    required this.outlook,
    required this.focus,
    required this.luckyColour,
    required this.luckyNumber,
  });
  final ZodiacSign sign;
  final String outlook;
  final String focus;
  final String luckyColour;
  final int luckyNumber;
}

class TodayHoroscope {
  static const signs = <ZodiacSign>[
    ZodiacSign('aries', 'Aries', 'Mesha', '♈', 'Fire'),
    ZodiacSign('taurus', 'Taurus', 'Vrishabha', '♉', 'Earth'),
    ZodiacSign('gemini', 'Gemini', 'Mithuna', '♊', 'Air'),
    ZodiacSign('cancer', 'Cancer', 'Karka', '♋', 'Water'),
    ZodiacSign('leo', 'Leo', 'Simha', '♌', 'Fire'),
    ZodiacSign('virgo', 'Virgo', 'Kanya', '♍', 'Earth'),
    ZodiacSign('libra', 'Libra', 'Tula', '♎', 'Air'),
    ZodiacSign('scorpio', 'Scorpio', 'Vrishchika', '♏', 'Water'),
    ZodiacSign('sagittarius', 'Sagittarius', 'Dhanu', '♐', 'Fire'),
    ZodiacSign('capricorn', 'Capricorn', 'Makara', '♑', 'Earth'),
    ZodiacSign('aquarius', 'Aquarius', 'Kumbha', '♒', 'Air'),
    ZodiacSign('pisces', 'Pisces', 'Meena', '♓', 'Water'),
  ];

  static const _outlooks = <String>[
    'A productive day for decisive action. Matters you have deferred move forward with little resistance.',
    'Clarity comes early. Use the morning for your most important conversation of the day.',
    'Steady progress outweighs speed today. Complete what is in hand before taking on more.',
    'An excellent day for negotiation. Your judgement is sound and others are receptive.',
    'Collaboration brings the best results. A colleague’s perspective resolves an open question.',
    'Financial matters favour careful review. Verify the details before you commit.',
    'Your influence is strong today. Lead the discussion and set the agenda.',
    'A calm, measured approach serves you well. Avoid reacting to the first piece of news.',
    'New opportunities arrive through your network. Follow up on a recent introduction.',
    'Focus on long-term goals. A small step taken today compounds over the coming weeks.',
    'Good news on a pending matter is likely. Prepare to act on it promptly.',
    'Organisation is your advantage today. A clear plan turns a busy schedule into a successful one.',
    'Communication flows easily. It is a good day to resolve a misunderstanding.',
    'Trust your preparation. The groundwork you have laid begins to show results.',
    'Balance work with rest. A short pause in the afternoon restores your energy.',
    'A favourable day for learning. An insight from an unexpected source proves valuable.',
  ];

  static const _focus = <String>[
    'Career', 'Finance', 'Partnerships', 'Well-being', 'Family',
    'Learning', 'Strategy', 'Networking', 'Creativity', 'Personal Goals',
  ];

  static const colours = <String>[
    'Royal Blue', 'Emerald Green', 'Gold', 'Ivory', 'Maroon', 'Silver',
    'Saffron', 'Navy', 'Teal', 'Burgundy', 'Pearl White', 'Violet',
  ];

  /// The sign whose English name the server sent ("Gemini"), or null.
  static ZodiacSign? byName(String? name) {
    final n = name?.trim().toLowerCase();
    if (n == null || n.isEmpty) return null;
    for (final s in signs) {
      if (s.id == n || s.vedic.toLowerCase() == n) return s;
    }
    return null;
  }

  /// Today's reading for [sign] — the same all day, different tomorrow.
  static HoroscopeReading today(ZodiacSign sign, [DateTime? now]) {
    final d = now ?? DateTime.now();
    final day = DateTime(d.year, d.month, d.day).difference(DateTime(2026)).inDays;
    final s = signs.indexOf(sign) + 1;
    int pick(int salt, int n) => ((day * 31 + s * 17 + salt * 7) % n + n) % n;
    return HoroscopeReading(
      sign: sign,
      outlook: _outlooks[pick(1, _outlooks.length)],
      focus: _focus[pick(2, _focus.length)],
      luckyColour: colours[pick(3, colours.length)],
      luckyNumber: pick(4, 9) + 1,
    );
  }

  /// The card's sign: null while unknown (no saved profile, or not loaded).
  static final ValueNotifier<ZodiacSign?> sign = ValueNotifier(null);

  /// Who the sign belongs to (the saved profile's name).
  static String? owner;

  static Future<void>? _loading;

  /// Looks up the most recent saved profile's rashi. Safe to call often:
  /// one lookup at a time, and a failure leaves the last sign in place.
  static Future<void> load([JyotishService service = const JyotishService()]) =>
      _loading ??= _load(service).whenComplete(() => _loading = null);

  static Future<void> _load(JyotishService service) async {
    final list = await service.profiles();
    if (list == null) return; // offline: keep what we had
    if (list.isEmpty) {
      owner = null;
      sign.value = null;
      return;
    }
    final r = await service.chart(list.first.birth);
    if (r == null) return;
    owner = list.first.name;
    sign.value = byName(r.chart.rashi);
  }
}
