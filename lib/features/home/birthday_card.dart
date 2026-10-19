import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../design/neon_tokens.dart';
import '../../services/api_service.dart';
import '../../widgets/neon_cards.dart';

/// One well-known person born on today's date (backend src/birthdays).
class BirthdayPerson {
  const BirthdayPerson(
      {required this.id, required this.name, required this.role, this.age, this.photo});

  final String id;
  final String name;
  final String role;

  /// The age they turn today; null when the records disagree.
  final int? age;

  /// A small Wikimedia Commons picture, or null.
  final String? photo;

  static BirthdayPerson? fromJson(Object? j) {
    if (j is! Map) return null;
    final name = (j['name'] as String?)?.trim() ?? '';
    if (name.isEmpty) return null;
    final photo = j['photo'] as String?;
    return BirthdayPerson(
      id: j['id'] as String? ?? name,
      name: name,
      role: (j['role'] as String?)?.trim() ?? '',
      age: (j['age'] as num?)?.toInt(),
      photo: photo != null && photo.startsWith('https://') ? photo : null,
    );
  }
}

/// BORN TODAY (2026-10-19): the names for Home's birthday card. The server
/// fetches them once an India day for everyone; the phone keeps the last
/// answer, so the card is there at once on the next open the same day.
class BirthdaysService extends ChangeNotifier {
  BirthdaysService._();
  static final instance = BirthdaysService._();

  static const _prefsKey = 'birthdays_today_v1';

  String? _date;
  List<BirthdayPerson> _people = const [];
  bool _loaded = false;
  DateTime? _lastTry;

  /// Today's names; empty until they load, or when it is not today's list.
  List<BirthdayPerson> get people => _date == _indiaToday() ? _people : const [];

  static String _indiaToday() {
    final t = DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
    return '${t.year.toString().padLeft(4, '0')}-'
        '${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
  }

  /// Cheap to call often: it reads the saved list once, then asks the
  /// server only when that list is not today's (at most every 10 minutes).
  Future<void> ensureFresh() async {
    if (!_loaded) {
      _loaded = true;
      try {
        final p = await SharedPreferences.getInstance();
        final s = p.getString(_prefsKey);
        if (s != null) _apply(jsonDecode(s));
      } catch (_) {}
    }
    if (_date == _indiaToday() && _people.isNotEmpty) return;
    final last = _lastTry;
    if (last != null && DateTime.now().difference(last) < const Duration(minutes: 10)) return;
    _lastTry = DateTime.now();
    final j = await ApiService.getJson('/birthdays/today',
        timeout: const Duration(seconds: 50));
    if (j == null || !_apply(j)) return;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_prefsKey, jsonEncode(j));
    } catch (_) {}
  }

  bool _apply(Object? j) {
    if (j is! Map) return false;
    final date = j['date'] as String?;
    if (date == null) return false;
    _date = date;
    _people = [
      for (final e in (j['people'] as List? ?? const []))
        if (BirthdayPerson.fromJson(e) case final p?) p,
    ];
    notifyListeners();
    return true;
  }
}

/// ─────────────────────────────────────────────────────────────────────────
///  HOME'S BIRTHDAY CARD (2026-10-19), in the place the weather card had.
///  Owner: "today's birthday … names of celebrities whose birthday is
///  today … if there is more than two or three … automatic sliding".
///  Two names show at a time; with more, the card slides to the next two
///  every few seconds and loops. A swipe moves it by hand, and the timer
///  starts over from there.
/// ─────────────────────────────────────────────────────────────────────────
class BirthdayCard extends StatefulWidget {
  const BirthdayCard({super.key, required this.people, this.now = DateTime.now});

  final List<BirthdayPerson> people;
  final DateTime Function() now;

  @override
  State<BirthdayCard> createState() => _BirthdayCardState();
}

class _BirthdayCardState extends State<BirthdayCard> {
  static const _perPage = 2;
  static const _every = Duration(seconds: 4);
  static const _rowH = 64.0;

  // A large start page so the slide always moves forward and wraps
  // without a jump back to the first page.
  static const _origin = 1000;
  final _pager = PageController(initialPage: _origin);
  Timer? _timer;
  int _page = _origin;

  List<List<BirthdayPerson>> get _pages => [
        for (var i = 0; i < widget.people.length; i += _perPage)
          widget.people.sublist(i, (i + _perPage).clamp(0, widget.people.length)),
      ];

  @override
  void initState() {
    super.initState();
    _restart();
  }

  @override
  void didUpdateWidget(BirthdayCard old) {
    super.didUpdateWidget(old);
    if (old.people.length != widget.people.length) _restart();
  }

  void _restart() {
    _timer?.cancel();
    if (_pages.length < 2) return;
    _timer = Timer.periodic(_every, (_) {
      // Not on screen (another tab, the app in the background): hold still.
      if (!mounted || !TickerMode.valuesOf(context).enabled || !_pager.hasClients) return;
      _pager.nextPage(
          duration: const Duration(milliseconds: 650), curve: Curves.easeInOutCubic);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pager.dispose();
    super.dispose();
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  @override
  Widget build(BuildContext context) {
    final pages = _pages;
    final warm = NeonTone.action.rim;
    final now = widget.now();
    final rows = pages.isEmpty ? 1 : pages.first.length;
    return Semantics(
      container: true,
      label: 'Born today: ${widget.people.map((p) => p.name).join(', ')}',
      child: GlassCard(
        wash: warm.first,
        padding: const EdgeInsets.fromLTRB(Neon.s4, Neon.s4, Neon.s4, Neon.s3),
        child: ExcludeSemantics(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(Neon.rInner),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          warm.first.withValues(alpha: 0.85),
                          warm.last.withValues(alpha: 0.85)
                        ],
                      ),
                    ),
                    child: const Icon(Icons.cake_rounded, size: 20, color: Colors.white),
                  ),
                  const SizedBox(width: Neon.s3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Born today',
                            style: NeonType.glassTitle.copyWith(color: Neon.textHi)),
                        Text('Famous birthdays in India',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Neon.textLo, fontSize: NeonType.footnote)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: warm.first.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: warm.first.withValues(alpha: 0.3)),
                    ),
                    child: Text('${now.day} ${_months[now.month - 1]}',
                        style: NeonType.manrope(NeonType.caption, FontWeight.w700)
                            .copyWith(color: Neon.textHi, fontFeatures: NeonType.figures)),
                  ),
                ],
              ),
              const SizedBox(height: Neon.s3),
              SizedBox(
                height: _rowH * rows,
                child: pages.length < 2
                    ? _pageOf(pages.isEmpty ? const [] : pages.first)
                    : NotificationListener<ScrollStartNotification>(
                        // A hand on the card: the timer counts again from now.
                        onNotification: (n) {
                          if (n.dragDetails != null) _restart();
                          return false;
                        },
                        child: PageView.builder(
                          controller: _pager,
                          onPageChanged: (i) => setState(() => _page = i),
                          itemBuilder: (_, i) => _pageOf(pages[i % pages.length]),
                        ),
                      ),
              ),
              if (pages.length > 1) ...[
                const SizedBox(height: Neon.s2),
                _dots(pages.length, _page % pages.length, warm),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _pageOf(List<BirthdayPerson> people) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [for (final p in people) SizedBox(height: _rowH, child: _row(p))],
      );

  Widget _row(BirthdayPerson p) {
    final warm = NeonTone.action.rim;
    return Row(
      children: [
        _avatar(p, warm),
        const SizedBox(width: Neon.s3),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(p.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: NeonType.manrope(NeonType.callout, FontWeight.w700)
                      .copyWith(color: Neon.textHi)),
              if (p.role.isNotEmpty)
                Text(p.role,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Neon.textLo, fontSize: NeonType.footnote)),
            ],
          ),
        ),
        if (p.age != null && p.age! > 0) ...[
          const SizedBox(width: Neon.s2),
          Text('Turns ${p.age}',
              style: NeonType.manrope(NeonType.footnote, FontWeight.w600)
                  .copyWith(color: warm.first, fontFeatures: NeonType.figures)),
        ],
      ],
    );
  }

  Widget _avatar(BirthdayPerson p, List<Color> warm) {
    final initials = p.name
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();
    final fallback = Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [warm.first.withValues(alpha: 0.55), warm.last.withValues(alpha: 0.55)],
        ),
      ),
      child: Text(initials,
          style: NeonType.manrope(NeonType.callout, FontWeight.w700)
              .copyWith(color: Colors.white)),
    );
    return Container(
      width: 48,
      height: 48,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: warm),
      ),
      child: ClipOval(
        child: p.photo == null
            ? fallback
            : Image.network(
                p.photo!,
                fit: BoxFit.cover,
                alignment: const Alignment(0, -0.6),
                cacheWidth: 120,
                headers: const {'User-Agent': 'HariAssistant/1.0 (Android)'},
                errorBuilder: (_, __, ___) => fallback,
                frameBuilder: (_, child, frame, sync) =>
                    sync || frame != null ? child : fallback,
              ),
      ),
    );
  }

  Widget _dots(int n, int at, List<Color> warm) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < n; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == at ? 16 : 6,
              height: 6,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                color: i == at ? warm.first : Neon.textLo.withValues(alpha: 0.35),
              ),
            ),
        ],
      );
}
