// TODAY'S HOROSCOPE CAROUSEL (2026-11-24) — inside the Jyotish card: twelve
// slides, one per zodiac sign, each with the sign's gold constellation, the
// day's reading, a lucky colour and a lucky number. The words come from the
// server (GET /jyotish/today), which writes them once a day for everyone and
// renews them at 4 AM India time; the phone keeps the last set so the
// carousel shows at once, even offline.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/log.dart';
import '../../design/motion.dart';
import '../../design/neon_tokens.dart';
import '../../services/api_service.dart';
import '../home/cosmic_painter.dart';
import 'jyotish_theme.dart';

/// One sign's reading for the day.
@immutable
class DailySign {
  const DailySign({
    required this.id,
    required this.name,
    required this.symbol,
    required this.reading,
    required this.colour,
    required this.colourHex,
    required this.number,
  });
  final String id;
  final String name;
  final String symbol;
  final String reading;
  final String colour;
  final String colourHex;
  final int number;

  /// The lucky colour's dot; grey when the server sent none.
  Color get dot {
    final h = colourHex.replaceFirst('#', '');
    final v = h.length == 6 ? int.tryParse(h, radix: 16) : null;
    return v == null ? const Color(0xFF9E9E9E) : Color(0xFF000000 | v);
  }

  static DailySign? fromJson(Object? o) {
    if (o is! Map) return null;
    String s(String k) => (o[k] ?? '').toString().trim();
    final id = s('id').toLowerCase();
    final reading = s('reading');
    if (id.isEmpty || reading.isEmpty) return null;
    final n = o['number'];
    return DailySign(
      id: id,
      name: s('name').isEmpty ? id[0].toUpperCase() + id.substring(1) : s('name'),
      symbol: s('symbol'),
      reading: reading,
      colour: s('colour'),
      colourHex: s('colourHex'),
      number: n is num ? n.round() : int.tryParse('$n') ?? 0,
    );
  }

  Map<String, Object> toJson() => {
        'id': id, 'name': name, 'symbol': symbol, 'reading': reading,
        'colour': colour, 'colourHex': colourHex, 'number': number,
      };
}

/// The day's twelve readings.
@immutable
class DailyHoroscope {
  const DailyHoroscope(this.day, this.signs);

  /// YYYY-MM-DD, the server's horoscope day (it turns at 4 AM India time).
  final String day;
  final List<DailySign> signs;

  static DailyHoroscope? fromJson(Object? o) {
    if (o is! Map) return null;
    final day = (o['day'] ?? '').toString();
    final list = o['signs'];
    final signs = [
      if (list is List)
        for (final e in list)
          if (DailySign.fromJson(e) case final s?) s,
    ];
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(day) || signs.isEmpty) return null;
    return DailyHoroscope(day, signs);
  }

  Map<String, Object> toJson() => {'day': day, 'signs': [for (final s in signs) s.toJson()]};

  /// "24 NOV" for the slide's date line.
  String get dateLabel {
    const months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    final p = day.split('-');
    final m = int.tryParse(p[1]) ?? 1;
    return '${int.tryParse(p[2]) ?? p[2]} ${months[(m - 1).clamp(0, 11)]}';
  }
}

/// The horoscope day now, as the server counts it: India's date, turning
/// at 4 AM.
String horoscopeDayNow([DateTime? now]) {
  // +5:30 for India, −4 h so the day turns at 4 AM.
  final ist = (now ?? DateTime.now()).toUtc().add(const Duration(hours: 1, minutes: 30));
  String two(int v) => v.toString().padLeft(2, '0');
  return '${ist.year}-${two(ist.month)}-${two(ist.day)}';
}

/// Loads, keeps and refreshes the day's set.
class TodayHoroscopeService extends ValueNotifier<DailyHoroscope?> {
  TodayHoroscopeService._() : super(null);
  static final TodayHoroscopeService instance = TodayHoroscopeService._();

  static const _key = 'jyotish.today.v1';

  /// The server call; replaced in tests.
  @visibleForTesting
  Future<Map<String, dynamic>?> Function()? fetch;

  /// True once a load has failed with nothing to show.
  final ValueNotifier<bool> failed = ValueNotifier(false);

  bool _restored = false;
  Future<void>? _loading;
  DateTime? _lastTry;

  /// Shows the kept set at once, then fetches when it is from another day
  /// (or every 30 minutes at most while it is missing).
  Future<void> refresh({bool force = false}) {
    if (_loading != null) return _loading!;
    return _loading = _refresh(force).whenComplete(() => _loading = null);
  }

  Future<void> _refresh(bool force) async {
    if (!_restored) {
      _restored = true;
      try {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString(_key);
        if (raw != null && value == null) value = DailyHoroscope.fromJson(jsonDecode(raw));
      } catch (e) {
        AppLog.add('jyotish', 'today: restore failed: $e');
      }
    }
    final current = value?.day == horoscopeDayNow();
    final recent = _lastTry != null && DateTime.now().difference(_lastTry!) < const Duration(minutes: 30);
    if (!force && (current || recent)) return;
    _lastTry = DateTime.now();
    final j = await (fetch ?? () => ApiService.getJson('/jyotish/today', timeout: const Duration(seconds: 70)))();
    final got = DailyHoroscope.fromJson(j);
    if (got == null) {
      failed.value = value == null;
      return;
    }
    failed.value = false;
    value = got;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(got.toJson()));
    } catch (_) {}
  }
}

/// The carousel itself: swipe, or let it move on every few seconds.
class TodayHoroscopeCarousel extends StatefulWidget {
  const TodayHoroscopeCarousel({super.key, this.height = 196, this.autoEvery = const Duration(seconds: 5)});
  final double height;
  final Duration autoEvery;

  @override
  State<TodayHoroscopeCarousel> createState() => _TodayHoroscopeCarouselState();
}

class _TodayHoroscopeCarouselState extends State<TodayHoroscopeCarousel> with WidgetsBindingObserver {
  final svc = TodayHoroscopeService.instance;
  final _pages = PageController();
  Timer? _auto;
  int _page = 0;
  bool _touching = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    svc.refresh();
    _auto = Timer.periodic(widget.autoEvery, (_) => _next());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    // Back in the app after 4 AM: the new day's set.
    if (s == AppLifecycleState.resumed) svc.refresh();
  }

  void _next() {
    final n = svc.value?.signs.length ?? 0;
    if (!mounted || _touching || n < 2 || !_pages.hasClients || Motion.reduced(context)) return;
    _pages.animateToPage((_page + 1) % n, duration: const Duration(milliseconds: 600), curve: Curves.easeInOutCubic);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _auto?.cancel();
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<DailyHoroscope?>(
      valueListenable: svc,
      builder: (context, h, _) {
        if (h == null) {
          return ValueListenableBuilder<bool>(
            valueListenable: svc.failed,
            builder: (_, failed, __) => _Frame(
              height: widget.height,
              signId: 'gemini',
              child: Center(
                child: failed
                    ? TextButton.icon(
                        onPressed: () => svc.refresh(force: true),
                        icon: const Icon(Icons.refresh_rounded, color: Cosmic.gold),
                        label: Text("Unable to load today's horoscope. Tap to try again.",
                            style: Cosmic.label(NeonType.footnote)),
                      )
                    : Text("Loading today's horoscope…", style: Cosmic.label(NeonType.footnote)),
              ),
            ),
          );
        }
        return Column(
          children: [
            SizedBox(
              height: widget.height,
              child: Listener(
                onPointerDown: (_) => _touching = true,
                onPointerUp: (_) => _touching = false,
                onPointerCancel: (_) => _touching = false,
                child: PageView.builder(
                  controller: _pages,
                  itemCount: h.signs.length,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemBuilder: (_, i) => _Slide(sign: h.signs[i], date: h.dateLabel, index: i, height: widget.height),
                ),
              ),
            ),
            const SizedBox(height: 8),
            ExcludeSemantics(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < h.signs.length; i++)
                    AnimatedContainer(
                      duration: Motion.short,
                      margin: const EdgeInsets.symmetric(horizontal: 2.5),
                      width: i == _page ? 14 : 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: i == _page ? Cosmic.gold : Colors.white.withValues(alpha: 0.28),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The slide's night sky: the purple gradient, stars and the sign's gold
/// constellation on the right (CosmicPainter), a faint glyph behind it.
class _Frame extends StatelessWidget {
  const _Frame({required this.height, required this.signId, required this.child, this.symbol = '', this.seed = 7});
  final double height;
  final String signId;
  final String symbol;
  final int seed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(Neon.rLg);
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: r,
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: ClipRRect(
        borderRadius: r,
        child: CustomPaint(
          painter: CosmicPainter(seed: seed, signId: signId, constellationBox: const Rect.fromLTRB(.58, .14, .96, .92)),
          child: Stack(
            children: [
              if (symbol.isNotEmpty)
                Positioned(
                  right: 18,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: Text(symbol,
                        style: TextStyle(
                            fontSize: height * 0.62,
                            height: 1,
                            color: Colors.white.withValues(alpha: 0.06),
                            fontFamilyFallback: const ['Noto Sans Symbols', 'Noto Sans Symbols 2'])),
                  ),
                ),
              Positioned.fill(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

class _Slide extends StatelessWidget {
  const _Slide({required this.sign, required this.date, required this.index, required this.height});
  final DailySign sign;
  final String date;
  final int index;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: "Today's horoscope for ${sign.name}, $date. ${sign.reading} "
          'Lucky colour ${sign.colour}. Lucky number ${sign.number}.',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1),
        child: _Frame(
          height: height,
          signId: sign.id,
          symbol: sign.symbol,
          seed: 11 + index,
          child: Stack(
            children: [
              Positioned(
                top: 12,
                right: 12,
                child: Icon(Icons.north_east_rounded, size: 18, color: Colors.white.withValues(alpha: 0.6)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                child: FractionallySizedBox(
                  widthFactor: 0.64,
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("TODAY'S HOROSCOPE",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: NeonType.manrope(11, FontWeight.w800)
                              .copyWith(color: CosmicPainter.gold, letterSpacing: 1.6)),
                      const SizedBox(height: 3),
                      Text(date,
                          style: NeonType.manrope(10.5, FontWeight.w700)
                              .copyWith(color: Colors.white.withValues(alpha: 0.55), letterSpacing: 1.2)),
                      const SizedBox(height: 4),
                      Text(sign.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.cormorantGaramond(
                              fontSize: 34, fontWeight: FontWeight.w700, color: Colors.white, height: 1.05)),
                      const SizedBox(height: 4),
                      Expanded(
                        child: Text(sign.reading,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: NeonType.manrope(12.5, FontWeight.w500)
                                .copyWith(color: Colors.white.withValues(alpha: 0.88), height: 1.4)),
                      ),
                      Row(
                        children: [
                          Flexible(
                            child: _Chip(
                              leading: Container(
                                width: 11,
                                height: 11,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: sign.dot,
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 0.8),
                                ),
                              ),
                              text: sign.colour,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _Chip(text: 'No. ${sign.number}'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text, this.leading});
  final String text;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(Neon.rPill),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 6)],
          Flexible(
            child: Text(text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: NeonType.manrope(11.5, FontWeight.w700).copyWith(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
