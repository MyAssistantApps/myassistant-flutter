import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';

/// One of the twelve zodiac signs.
class ZodiacSign {
  const ZodiacSign(this.id, this.name, this.symbol, this.dates, this.element);
  final String id;
  final String name;
  final String symbol;
  final String dates;
  final String element;
}

/// A day's reading for one sign.
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

/// TODAY'S HOROSCOPE (owner, 2026-11-15): the user picks a sign at
/// registration or in Settings; Home shows today's reading for it.
///
/// The sign is kept on this phone, per account (like the Pro photo). The
/// reading is composed locally and deterministically — same sign, same
/// day, same reading — so it works offline and needs no server.
class Horoscope {
  static const signs = <ZodiacSign>[
    ZodiacSign('aries', 'Aries', '♈', '21 Mar – 19 Apr', 'Fire'),
    ZodiacSign('taurus', 'Taurus', '♉', '20 Apr – 20 May', 'Earth'),
    ZodiacSign('gemini', 'Gemini', '♊', '21 May – 20 Jun', 'Air'),
    ZodiacSign('cancer', 'Cancer', '♋', '21 Jun – 22 Jul', 'Water'),
    ZodiacSign('leo', 'Leo', '♌', '23 Jul – 22 Aug', 'Fire'),
    ZodiacSign('virgo', 'Virgo', '♍', '23 Aug – 22 Sep', 'Earth'),
    ZodiacSign('libra', 'Libra', '♎', '23 Sep – 22 Oct', 'Air'),
    ZodiacSign('scorpio', 'Scorpio', '♏', '23 Oct – 21 Nov', 'Water'),
    ZodiacSign('sagittarius', 'Sagittarius', '♐', '22 Nov – 21 Dec', 'Fire'),
    ZodiacSign('capricorn', 'Capricorn', '♑', '22 Dec – 19 Jan', 'Earth'),
    ZodiacSign('aquarius', 'Aquarius', '♒', '20 Jan – 18 Feb', 'Air'),
    ZodiacSign('pisces', 'Pisces', '♓', '19 Feb – 20 Mar', 'Water'),
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
    'Career and recognition',
    'Finance and investments',
    'Partnerships and agreements',
    'Health and well-being',
    'Family and home',
    'Learning and growth',
    'Planning and strategy',
    'Networking and relationships',
    'Creative work',
    'Personal goals',
  ];

  static const _colours = <String>[
    'Royal Blue', 'Emerald Green', 'Gold', 'Ivory', 'Maroon', 'Silver',
    'Saffron', 'Navy', 'Teal', 'Burgundy', 'Pearl White', 'Violet',
  ];

  /// Rebuilds the Home card when the sign changes.
  static final ValueNotifier<ZodiacSign?> current = ValueNotifier(null);

  static String get _key => 'zodiac_sign_${AuthService.instance.user?.id ?? 0}';

  static ZodiacSign? byId(String? id) =>
      signs.where((s) => s.id == id).firstOrNull;

  /// Loads the signed-in account's sign. Safe to call repeatedly.
  static Future<ZodiacSign?> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      current.value = byId(p.getString(_key));
    } catch (_) {
      current.value = null;
    }
    return current.value;
  }

  static Future<void> save(ZodiacSign? sign) async {
    current.value = sign;
    try {
      final p = await SharedPreferences.getInstance();
      if (sign == null) {
        await p.remove(_key);
      } else {
        await p.setString(_key, sign.id);
      }
    } catch (_) {}
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
      luckyColour: _colours[pick(3, _colours.length)],
      luckyNumber: pick(4, 9) + 1,
    );
  }
}
