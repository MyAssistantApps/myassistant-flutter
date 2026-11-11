import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../ai/types.dart';
import '../../design/apple_kit.dart';
import '../../design/motion.dart';
import '../../design/neon_scaffold.dart';
import '../../design/neon_tokens.dart';
import '../assistant/widgets/action_cards.dart' show SearchSuggestionChips;
import 'airlines.dart';
import 'flight_fares.dart';
import 'flight_trip.dart';
import 'price_models.dart';
import 'price_service.dart';
import 'price_widgets.dart';

/// ─────────────────────────────────────────────────────────────────────────
///  FLIGHT RESULTS, AS THE TRAVEL APPS SHOW THEM (2026-11-07, Manish: "do
///  the same ui for the price comparison in flight"): the route and trip
///  on top, a strip of nearby dates with each day's lowest fare (tap one to
///  search that day), Cheapest / Fastest / Best, a price alert and filters,
///  then one card per flight — airline, times, duration, stops, the best
///  fare with Book, the site it is on and "N more" for every other site's
///  fare. "Best value" and "Fastest" are marked on their cards.
///
///  The wait says what it is really doing (the sites being asked and the
///  seconds gone) — no made-up counts. A round trip or multi-city trip
///  gets one tab per flight, each searched as its own one-way fare.
/// ─────────────────────────────────────────────────────────────────────────
class FlightResultsScreen extends StatefulWidget {
  const FlightResultsScreen({super.key, required this.trip});
  final FlightTrip trip;

  @override
  State<FlightResultsScreen> createState() => _FlightResultsScreenState();
}

enum _Sort { cheapest, fastest, best }

class _FlightResultsScreenState extends State<FlightResultsScreen> {
  final svc = PriceService.instance;

  /// One search per flight of the trip: one-way has one, a round trip
  /// two (there and back), multi-city one per flight. Each keeps its own
  /// answer, date and fares, so switching tabs does not search again.
  late final List<_Leg> _legs = _legsOf(widget.trip);
  int _i = 0;
  bool _busy = false;
  int _busyLeg = -1;

  _Leg get _leg => _legs[_i];
  FlightTrip get _trip => _leg.trip;
  FlightAnswer? get _answer => _leg.answer;
  String get _error => _leg.error;
  Map<DateTime, double> get _dayLows => _leg.lows;
  bool get _loadingHere => _busy && _busyLeg == _i;

  static List<_Leg> _legsOf(FlightTrip t) {
    FlightTrip one(FlightLeg l) => t.copyWith(type: TripType.oneWay, legs: [l], clearReturn: true);
    final first = t.legs.first;
    return switch (t.type) {
      TripType.oneWay => [_Leg(one(first))],
      TripType.roundTrip => [
          _Leg(one(first)),
          _Leg(one(FlightLeg(from: first.to, to: first.from, date: t.returnDate ?? first.date))),
        ],
      TripType.multiCity => [for (final l in t.legs) _Leg(one(l))],
    };
  }

  int _elapsed = 0;
  Timer? _tick;
  int _run = 0;
  _Sort _sort = _Sort.cheapest;
  final Set<String> _open = {};

  // Filters.
  bool _nonStop = false;
  final Set<String> _airlinesOff = {};
  final Set<int> _slots = {}; // 0 before 6, 1 6–12, 2 12–18, 3 after 18

  DateTime get _date => _trip.legs.first.date!;

  @override
  void initState() {
    super.initState();
    svc.addListener(_changed);
    _search();
  }

  @override
  void dispose() {
    svc.removeListener(_changed);
    _tick?.cancel();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _search() async {
    final run = ++_run;
    final leg = _leg;
    setState(() {
      _busy = true;
      _busyLeg = _i;
      leg.error = '';
      leg.answer = null;
      _elapsed = 0;
      _open.clear();
    });
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed++);
    });
    try {
      final a = await svc.compareFlights(leg.trip);
      if (!mounted) return;
      // Kept for its own tab even when another tab was opened meanwhile.
      setState(() {
        leg.answer = a;
        a.fares.nearby.forEach((d, p) => leg.lows[d] = p);
        final low = a.fares.cheapest?.price;
        if (low != null) leg.lows[_day(leg.trip.legs.first.date!)] = low;
      });
      if (run == _run) HapticFeedback.lightImpact();
    } catch (e) {
      if (mounted) {
        setState(() => leg.error = e is PriceCompareException ? e.message : 'Something went wrong. Try again.');
      }
    } finally {
      if (run == _run) {
        _tick?.cancel();
        if (mounted) setState(() => _busy = false);
      }
    }
  }

  void _pickDay(DateTime d) {
    if (_day(d) == _day(_date)) return;
    HapticFeedback.selectionClick();
    final l = _trip.legs.first;
    _leg.trip = _trip.copyWith(legs: [FlightLeg(from: l.from, to: l.to, date: d)]);
    _search();
  }

  void _pickLeg(int i) {
    if (i == _i) return;
    HapticFeedback.selectionClick();
    setState(() {
      _i = i;
      _open.clear();
    });
    if (_leg.answer == null && _leg.error.isEmpty && !_loadingHere) _search();
  }

  // ── what is shown ────────────────────────────────────────────────────

  List<FlightOption> get _shown {
    final f = _answer?.fares;
    if (f == null) return const [];
    final l = f.flights.where((o) {
      if (_nonStop && o.stops > 0) return false;
      if (_airlinesOff.contains(o.airline)) return false;
      if (_slots.isNotEmpty) {
        final m = o.departMin;
        if (m == null || !_slots.contains(_slotOf(m))) return false;
      }
      return true;
    }).toList();
    switch (_sort) {
      case _Sort.cheapest:
        l.sort((a, b) => a.price.compareTo(b.price));
      case _Sort.fastest:
        l.sort((a, b) {
          final am = a.minutes <= 0 ? 1 << 20 : a.minutes, bm = b.minutes <= 0 ? 1 << 20 : b.minutes;
          return am != bm ? am.compareTo(bm) : a.price.compareTo(b.price);
        });
      case _Sort.best:
        l.sort((a, b) => f.score(a).compareTo(f.score(b)));
    }
    return l;
  }

  int get _filterCount => (_nonStop ? 1 : 0) + _airlinesOff.length + _slots.length;

  @override
  Widget build(BuildContext context) {
    final l = _trip.legs.first;
    final a = _answer;
    final shown = _shown;
    return NeonScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        toolbarHeight: 64,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_legs.length > 1)
              Text(widget.trip.route,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: NeonType.manrope(21, FontWeight.w800).copyWith(color: Neon.textHi, letterSpacing: 0.4))
            else
              Text.rich(
                TextSpan(children: [
                  TextSpan(text: l.from!.code),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(Icons.arrow_forward_rounded, size: 18, color: Neon.textHi),
                    ),
                  ),
                  TextSpan(text: l.to!.code),
                ]),
                style: NeonType.manrope(21, FontWeight.w800).copyWith(color: Neon.textHi, letterSpacing: 0.4),
              ),
            const SizedBox(height: 2),
            Text(_subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Neon.textLo, fontSize: 12.5, fontWeight: FontWeight.w500)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Share',
            onPressed: a == null ? null : () => _share(a),
            icon: Icon(Icons.share_rounded, color: Neon.violet),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_legs.length > 1) _legTabs(),
          _dateStrip(),
          _toolbar(a),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _search,
              child: ListView(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 32 + MediaQuery.paddingOf(context).bottom),
                children: [
                  if (_loadingHere)
                    ..._loading()
                  else if (_error.isNotEmpty)
                    _message(Icons.cloud_off_rounded, "Couldn't load fares", _error, retry: true)
                  else if (a != null && shown.isEmpty)
                    _message(Icons.filter_alt_off_rounded, 'No flights match',
                        'Loosen the filters to see the other ${a.fares.flights.length} flights.',
                        clear: true)
                  else if (a != null) ...[
                    for (final o in shown) ...[_card(o, a.fares), const SizedBox(height: 12)],
                    ..._footer(a),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String get _subtitle {
    final t = _trip;
    final n = t.travellers;
    final cabin = switch (t.cabin) {
      CabinClass.economy => 'Eco',
      CabinClass.premiumEconomy => 'Prem Eco',
      CabinClass.business => 'Business',
      CabinClass.first => 'First',
    };
    final w = widget.trip;
    final when = switch (w.type) {
      TripType.oneWay => '${_date.day} ${_mon(_date)}',
      TripType.roundTrip => '${_fmt(_legs[0].date)} – ${_fmt(_legs[1].date)}',
      TripType.multiCity => '${_legs.length} flights',
    };
    return '${w.type.label} · $when · $n Traveller${n == 1 ? '' : 's'} · $cabin';
  }

  static String _fmt(DateTime d) => '${d.day} ${_mon(d)}';

  // ── one tab per flight (round trip, multi-city) ──────────────────────

  Widget _legTabs() {
    final lows = [for (final l in _legs) l.answer?.fares.cheapest?.price];
    final all = lows.every((p) => p != null);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Neon.surfaceHigh.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(Neon.rMd),
              border: Border.all(color: Neon.hairline),
            ),
            child: Row(
              children: [
                for (final (i, l) in _legs.indexed)
                  Expanded(
                    child: Semantics(
                      button: true,
                      selected: i == _i,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(Neon.rSm),
                        onTap: () => _pickLeg(i),
                        child: AnimatedContainer(
                          duration: Motion.short,
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                          decoration: BoxDecoration(
                            color: i == _i ? Neon.violet.withValues(alpha: Neon.isDark ? 0.28 : 0.14) : null,
                            borderRadius: BorderRadius.circular(Neon.rSm),
                            border: i == _i ? Border.all(color: Neon.violet.withValues(alpha: 0.6)) : null,
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Column(
                              children: [
                                Text(
                                    _legs.length == 2 && widget.trip.type == TripType.roundTrip
                                        ? (i == 0 ? 'DEPART' : 'RETURN')
                                        : 'FLIGHT ${i + 1}',
                                    style: NeonType.manrope(10, FontWeight.w800)
                                        .copyWith(color: i == _i ? Neon.violet : Neon.textDim, letterSpacing: 1.1)),
                                const SizedBox(height: 2),
                                Text('${l.from} → ${l.to}',
                                    style: NeonType.manrope(15, FontWeight.w800)
                                        .copyWith(color: i == _i ? Neon.textHi : Neon.textLo)),
                                Text(
                                    '${_wd(l.date)}, ${_fmt(l.date)}'
                                    '${lows[i] == null ? '' : ' · ${rupees(lows[i]!)}'}',
                                    style: TextStyle(
                                        color: lows[i] == null ? Neon.textDim : Neon.success,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (all)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                  'Whole trip from ${rupees(lows.fold<double>(0, (a, p) => a + p!))} · cheapest of each flight, '
                  'booked separately',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Neon.textLo, fontSize: 12)),
            ),
        ],
      ),
    );
  }

  // ── the date strip ───────────────────────────────────────────────────

  Widget _dateStrip() {
    final today = _day(DateTime.now());
    final days = [
      for (var i = -3; i <= 10; i++)
        if (!_day(_date).add(Duration(days: i)).isBefore(today)) _day(_date).add(Duration(days: i)),
    ];
    final lows = [for (final d in days) _dayLows[d]].whereType<double>();
    final minLow = lows.isEmpty ? null : lows.reduce(math.min);
    return SizedBox(
      height: 24 + MediaQuery.textScalerOf(context).scale(52),
      child: Row(
        children: [
          Container(
            width: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Neon.violet.withValues(alpha: Neon.isDark ? 0.14 : 0.08),
              borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
            ),
            child: RotatedBox(
              quarterTurns: 3,
              child: Text(_mon(_date).toUpperCase(),
                  style: NeonType.manrope(11, FontWeight.w800).copyWith(color: Neon.textLo, letterSpacing: 1.4)),
            ),
          ),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              itemCount: days.length,
              itemBuilder: (_, i) {
                final d = days[i];
                final on = d == _day(_date);
                final low = _dayLows[d];
                final cheapest = low != null && low == minLow;
                return Semantics(
                  button: true,
                  selected: on,
                  label: '${_wd(d)} ${d.day} ${_mon(d)}${low == null ? '' : ', from ${rupees(low)}'}',
                  child: InkWell(
                    onTap: _loadingHere && on ? null : () => _pickDay(d),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 78,
                      padding: const EdgeInsets.only(top: 10),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: on ? Neon.violet : Colors.transparent, width: 3),
                        ),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.topCenter,
                        child: Column(
                          children: [
                            Text('${_wd(d)}, ${d.day.toString().padLeft(2, '0')}',
                                style: TextStyle(
                                    color: on ? Neon.textHi : Neon.textLo,
                                    fontSize: 13,
                                    fontWeight: on ? FontWeight.w800 : FontWeight.w500)),
                            const SizedBox(height: 3),
                            Text(low == null ? (on && _loadingHere ? '…' : '—') : rupees(low),
                                style: TextStyle(
                                    color: low == null
                                        ? Neon.textDim
                                        : (cheapest
                                            ? Neon.success
                                            : (on ? Neon.textHi : Neon.success.withValues(alpha: 0.75))),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── sort, alert, filter ──────────────────────────────────────────────

  Widget _toolbar(FlightAnswer? a) {
    final w = a == null ? null : svc.watchFor(PriceCategory.flights, a.result.query);
    final ready = a != null && !_loadingHere;
    return Container(
      padding: const EdgeInsets.fromLTRB(0, 10, 0, 10),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Neon.hairline))),
      child: SizedBox(
        height: 40,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            for (final s in _Sort.values) ...[
              _pill(
                switch (s) { _Sort.cheapest => 'Cheapest', _Sort.fastest => 'Fastest', _Sort.best => 'Best' },
                selected: _sort == s,
                onTap: ready ? () => setState(() => _sort = s) : null,
              ),
              const SizedBox(width: 8),
            ],
            _pill(
              w == null ? 'Set price alert' : 'Alert ${rupees(w.target)}',
              icon: w == null ? Icons.notifications_active_outlined : Icons.notifications_active_rounded,
              tinted: true,
              onTap: ready ? () => _setAlert(a) : null,
            ),
            const SizedBox(width: 4),
            Badge(
              isLabelVisible: _filterCount > 0,
              label: Text('$_filterCount'),
              backgroundColor: Neon.violet,
              offset: const Offset(-6, 4),
              child: IconButton(
                tooltip: 'Filters',
                onPressed: ready ? () => _filters(a.fares) : null,
                icon: Icon(Icons.filter_alt_outlined, color: ready ? Neon.textLo : Neon.textDim),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(String label, {bool selected = false, bool tinted = false, IconData? icon, VoidCallback? onTap}) {
    final on = onTap != null;
    final c = Neon.violet;
    return Opacity(
      opacity: on ? 1 : 0.45,
      child: Material(
        color: selected
            ? c.withValues(alpha: Neon.isDark ? 0.24 : 0.14)
            : (tinted ? c.withValues(alpha: Neon.isDark ? 0.14 : 0.08) : Neon.surfaceHigh.withValues(alpha: 0.6)),
        shape: StadiumBorder(
            side: BorderSide(
                color: selected || tinted ? c.withValues(alpha: 0.55) : Neon.hairline, width: selected ? 1.5 : 1)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap == null
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  onTap();
                },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[Icon(icon, size: 17, color: c), const SizedBox(width: 6)],
                Text(label,
                    style: TextStyle(
                        color: tinted ? c : (selected ? Neon.textHi : Neon.textLo),
                        fontSize: 14,
                        fontWeight: selected || tinted ? FontWeight.w700 : FontWeight.w500)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── waiting ──────────────────────────────────────────────────────────

  List<Widget> _loading() {
    const sites = PriceStores.flights;
    final now = sites[(_elapsed ~/ 3) % sites.length].name;
    // Eases toward the end without claiming to know it.
    final p = 1 - math.exp(-_elapsed / 18);
    return [
      const SizedBox(height: 12),
      Text('Finding your best fare…', style: NeonType.manrope(19, FontWeight.w800).copyWith(color: Neon.textHi)),
      const SizedBox(height: 4),
      Text('Checking airline and booking sites for today\'s fares.',
          style: TextStyle(color: Neon.textLo, fontSize: 13.5)),
      const SizedBox(height: 12),
      Row(
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: Neon.violet.withValues(alpha: Neon.isDark ? 0.18 : 0.10),
                borderRadius: BorderRadius.circular(Neon.rPill),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                      width: 8, height: 8, decoration: BoxDecoration(color: Neon.success, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Flexible(
                    child: AnimatedSwitcher(
                      duration: Motion.short,
                      child: Text('Checking $now…',
                          key: ValueKey(now),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Neon.violet, fontSize: 13.5, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text('${sites.length} sites · ${_elapsed}s', style: TextStyle(color: Neon.textLo, fontSize: 12.5)),
        ],
      ),
      const SizedBox(height: 12),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: p,
          minHeight: 6,
          color: Neon.violet,
          backgroundColor: Neon.violet.withValues(alpha: 0.14),
        ),
      ),
      const SizedBox(height: 18),
      for (var i = 0; i < 3; i++) ...[const _SkeletonCard(), const SizedBox(height: 12)],
    ];
  }

  Widget _message(IconData icon, String title, String line, {bool retry = false, bool clear = false}) => Padding(
        padding: const EdgeInsets.only(top: 48),
        child: Column(
          children: [
            Icon(icon, size: 44, color: Neon.textDim),
            const SizedBox(height: 12),
            Text(title, style: NeonType.manrope(17, FontWeight.w800).copyWith(color: Neon.textHi)),
            const SizedBox(height: 6),
            Text(line, textAlign: TextAlign.center, style: TextStyle(color: Neon.textLo, fontSize: 13.5)),
            const SizedBox(height: 16),
            if (retry) FilledButton.tonal(onPressed: _search, child: const Text('Try again')),
            if (clear)
              FilledButton.tonal(
                onPressed: () => setState(() {
                  _nonStop = false;
                  _airlinesOff.clear();
                  _slots.clear();
                }),
                child: const Text('Clear filters'),
              ),
          ],
        ),
      );

  // ── one flight ───────────────────────────────────────────────────────

  Widget _card(FlightOption o, FlightFares f) {
    final best = identical(o, f.bestValue);
    final fast = !best && identical(o, f.fastest) && f.flights.length > 1;
    final tag = best ? '★  BEST VALUE' : (fast ? 'FASTEST' : null);
    final tint = best ? Neon.success : Neon.violet;
    final key = '${o.airline}|${o.flightNo}|${o.depart}';
    final open = _open.contains(key);
    final more = o.fares.length - 1;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Neon.rLg),
        gradient: tag == null
            ? Neon.glassFill
            : LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color.alphaBlend(tint.withValues(alpha: Neon.isDark ? 0.16 : 0.10), Neon.glassFill.colors.first),
                  Neon.glassFill.colors.last,
                ],
              ),
        border: Border.all(color: tag == null ? Neon.glassEdge.first : tint.withValues(alpha: 0.35)),
        boxShadow: Neon.glassShadow,
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (tag != null) ...[
            Text(tag, style: NeonType.manrope(13, FontWeight.w800).copyWith(color: tint, letterSpacing: 1.2)),
            const SizedBox(height: 10),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 62, child: _AirlineBadge(option: o)),
              const SizedBox(width: 6),
              Expanded(child: _times(o)),
              const SizedBox(width: 8),
              _priceColumn(o, more, open, key),
            ],
          ),
          AnimatedSize(
            duration: Motion.short,
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: open && more > 0 ? _otherFares(o) : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }

  Widget _times(FlightOption o) {
    Widget end(String t, String code, CrossAxisAlignment a, {int plus = 0}) => Flexible(
          flex: 2,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: a == CrossAxisAlignment.start ? Alignment.topLeft : Alignment.topRight,
            child: Column(
              crossAxisAlignment: a,
              children: [
                Text.rich(
                  TextSpan(text: t.isEmpty ? '--:--' : t, children: [
                    if (plus > 0 && t.isNotEmpty)
                      TextSpan(
                          text: ' +$plus',
                          style: TextStyle(fontSize: 11, color: Neon.warning, fontWeight: FontWeight.w800)),
                  ]),
                  style: NeonType.manrope(19, FontWeight.w800).copyWith(color: Neon.textHi),
                ),
                const SizedBox(height: 4),
                Text(code, style: TextStyle(color: Neon.textLo, fontSize: 13.5, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        );
    final nonStop = o.stops == 0;
    final c = nonStop ? Neon.success : Neon.warning;
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            end(o.depart, o.from.isEmpty ? _trip.legs.first.from!.code : o.from, CrossAxisAlignment.start),
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Column(
                  children: [
                    Text(o.durationLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Neon.textLo, fontSize: 12.5)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(child: Divider(color: Neon.hairline, thickness: 1)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: Transform.rotate(
                              angle: math.pi / 2, child: Icon(Icons.flight_rounded, size: 14, color: Neon.textLo)),
                        ),
                        Expanded(child: Divider(color: Neon.hairline, thickness: 1)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            end(o.arrive, o.to.isEmpty ? _trip.legs.first.to!.code : o.to, CrossAxisAlignment.end, plus: o.dayOffset),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: c.withValues(alpha: Neon.isDark ? 0.16 : 0.10),
            borderRadius: BorderRadius.circular(Neon.rPill),
          ),
          child: Text(o.stopsLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: c, fontSize: 12.5, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }

  Widget _priceColumn(FlightOption o, int more, bool open, String key) => Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(rupees(o.price), style: NeonType.manrope(19, FontWeight.w800).copyWith(color: Neon.textHi)),
          const SizedBox(height: 6),
          _BookButton(onTap: () => _book(o.best, o)),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 96),
            child: Text('via ${o.best.store}',
                maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Neon.textLo, fontSize: 12.5)),
          ),
          if (more > 0)
            InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => open ? _open.remove(key) : _open.add(key));
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(open ? 'Hide ‹' : '$more more ›',
                    style: TextStyle(color: Neon.violet, fontSize: 13, fontWeight: FontWeight.w700)),
              ),
            ),
        ],
      );

  Widget _otherFares(FlightOption o) => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Column(
          children: [
            Divider(height: 1, color: Neon.hairline),
            for (final fare in o.fares.skip(1))
              InkWell(
                onTap: () => _book(fare, o),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      _StoreDot(name: fare.store),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(fare.store,
                            style: TextStyle(color: Neon.textHi, fontSize: 14, fontWeight: FontWeight.w600)),
                      ),
                      Text('+${rupees(fare.price - o.price)}', style: TextStyle(color: Neon.textDim, fontSize: 12)),
                      const SizedBox(width: 10),
                      Text(rupees(fare.price),
                          style: NeonType.manrope(15, FontWeight.w800).copyWith(color: Neon.textHi)),
                      const SizedBox(width: 4),
                      Icon(Icons.chevron_right_rounded, color: Neon.textDim, size: 20),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );

  // ── under the list ───────────────────────────────────────────────────

  List<Widget> _footer(FlightAnswer a) => [
        if (a.fares.advice.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4, bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: Neon.glassBox(Neon.rLg, lift: false),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.auto_awesome_rounded, color: Neon.violet, size: 20),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(a.fares.advice, style: TextStyle(color: Neon.textHi, fontSize: 13.5, height: 1.35))),
              ],
            ),
          ),
        if (a.fares.deals.isNotEmpty) ...[
          Text('Offers', style: NeonType.manrope(15, FontWeight.w800).copyWith(color: Neon.textHi)),
          const SizedBox(height: 8),
          for (final d in a.fares.deals)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.local_offer_rounded, size: 16, color: Neon.success),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                        '${d.store.isEmpty ? '' : '${d.store}: '}${d.text}${d.code.isEmpty ? '' : ' (code ${d.code})'}',
                        style: TextStyle(color: Neon.textLo, fontSize: 13)),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
        ],
        Text('Fares found on the web just now and can change at booking. Check the final price on the site.',
            style: TextStyle(color: Neon.textDim, fontSize: 11.5)),
        if (a.sources.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Sources', style: NeonType.manrope(13, FontWeight.w800).copyWith(color: Neon.textLo)),
          const SizedBox(height: 4),
          for (final s in a.sources.take(6)) _source(s),
        ],
        if (a.suggestions.isNotEmpty) ...[
          const SizedBox(height: 10),
          SearchSuggestionChips(suggestions: a.suggestions),
        ],
      ];

  Widget _source(SourceLink s) {
    final host = Uri.tryParse(s.uri)?.host ?? s.uri;
    return InkWell(
      onTap: () => openPriceLink(s.uri),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text((s.title?.isNotEmpty ?? false) ? s.title! : host,
            maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Neon.violet, fontSize: 12.5)),
      ),
    );
  }

  // ── actions ──────────────────────────────────────────────────────────

  void _book(FlightFare fare, FlightOption o) {
    HapticFeedback.mediumImpact();
    if (fare.url.isNotEmpty) {
      openPriceLink(fare.url);
      return;
    }
    final store = PriceStores.named(fare.store, PriceStores.flights);
    if (store != null && store.search.startsWith('https://')) {
      openPriceLink(store.urlFor(''));
      return;
    }
    final l = _trip.legs.first;
    final q = '${fare.store} ${o.airline} ${o.flightNo} ${l.from!.code} to ${l.to!.code} ${fullDate(_date)}';
    openPriceLink('https://www.google.com/search?q=${Uri.encodeQueryComponent(q)}');
  }

  void _share(FlightAnswer a) {
    final l = _trip.legs.first;
    final top = a.fares.flights.take(3).map((o) => '• ${o.title} — ${rupees(o.price)} on ${o.best.store}').join('\n');
    Share.share('${l.from!.city} → ${l.to!.city}, ${shortDate(_date)}\n$top', subject: 'Flight fares');
  }

  Future<void> _setAlert(FlightAnswer a) async {
    final r = a.result;
    final now = a.fares.cheapest!.price;
    final w = svc.watchFor(PriceCategory.flights, r.query);
    final c = TextEditingController(text: (w?.target ?? (now * 0.9)).round().toString());
    final target = await showAppSheet<double>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.viewInsetsOf(ctx).bottom),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Tell me when this trip drops to',
                  style: NeonType.manrope(18, FontWeight.w800).copyWith(color: Neon.textHi)),
              const SizedBox(height: 4),
              Text('Lowest now ${rupees(now)} on ${a.fares.cheapest!.best.store}',
                  style: TextStyle(color: Neon.textLo, fontSize: 13)),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                children: [
                  for (final pct in [5, 10, 15, 20])
                    ActionChip(
                      label: Text('$pct% less'),
                      onPressed: () => c.text = (now * (100 - pct) / 100).round().toString(),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: c,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: NeonType.manrope(20, FontWeight.w800).copyWith(color: Neon.textHi),
                decoration: InputDecoration(
                  prefixText: '₹ ',
                  filled: true,
                  fillColor: Neon.surfaceHigh,
                  border:
                      OutlineInputBorder(borderRadius: BorderRadius.circular(Neon.rMd), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
              ApplePrimaryButton(
                label: 'Set alert',
                icon: Icons.notifications_active_rounded,
                onPressed: () {
                  final v = double.tryParse(c.text);
                  if (v != null && v > 0) Navigator.pop(ctx, v);
                },
              ),
              if (w != null) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    svc.unwatch(w.id);
                    Navigator.pop(ctx);
                  },
                  child: const Text('Remove alert'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    c.dispose();
    if (target == null) return;
    svc.watch(r, target);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Alert set — ${rupees(target)} or less')));
    }
  }

  Future<void> _filters(FlightFares f) async {
    final names = {for (final o in f.flights) o.airline}.toList()..sort();
    const slotNames = ['Before 6 AM', '6 AM – 12 PM', '12 – 6 PM', 'After 6 PM'];
    await showAppSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) {
          void both(VoidCallback fn) {
            set(fn);
            setState(() {});
          }

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Filters', style: NeonType.manrope(18, FontWeight.w800).copyWith(color: Neon.textHi)),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Non-stop only'),
                    value: _nonStop,
                    onChanged: (v) => both(() => _nonStop = v),
                  ),
                  const SizedBox(height: 4),
                  Text('Departure', style: TextStyle(color: Neon.textLo, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (var i = 0; i < 4; i++)
                        FilterChip(
                          label: Text(slotNames[i]),
                          selected: _slots.contains(i),
                          onSelected: (v) => both(() => v ? _slots.add(i) : _slots.remove(i)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text('Airlines', style: TextStyle(color: Neon.textLo, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final n in names)
                        FilterChip(
                          label: Text(n),
                          selected: !_airlinesOff.contains(n),
                          onSelected: (v) => both(() => v ? _airlinesOff.remove(n) : _airlinesOff.add(n)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => both(() {
                          _nonStop = false;
                          _slots.clear();
                          _airlinesOff.clear();
                        }),
                        child: const Text('Clear all'),
                      ),
                      const Spacer(),
                      FilledButton(onPressed: () => Navigator.pop(ctx), child: Text('Show ${_shown.length} flights')),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// One flight of the trip and what its search found.
class _Leg {
  _Leg(this.trip);
  FlightTrip trip;
  FlightAnswer? answer;
  String error = '';

  /// Lowest fares seen per day, kept across date taps so the strip fills.
  final Map<DateTime, double> lows = {};

  DateTime get date => trip.legs.first.date!;
  String get from => trip.legs.first.from!.code;
  String get to => trip.legs.first.to!.code;
}

// ── small parts ──────────────────────────────────────────────────────────

/// The airline's code in its own colour (IndiGo navy, Air India red…),
/// its name under it. No logos are shipped, so no logo is faked.
class _AirlineBadge extends StatelessWidget {
  const _AirlineBadge({required this.option});
  final FlightOption option;

  @override
  Widget build(BuildContext context) {
    final o = option;
    final known = _airlineFor(o.airline);
    final color = known?.color ?? _hashColor(o.airline);
    final code = _code(o);
    return Column(
      children: [
        Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 8, offset: const Offset(0, 3))],
          ),
          child: Text(code,
              style: NeonType.manrope(code.length > 2 ? 12 : 15, FontWeight.w900)
                  .copyWith(color: Colors.white, letterSpacing: 0.2)),
        ),
        const SizedBox(height: 6),
        Text(o.airline,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Neon.textLo, fontSize: 11.5, fontWeight: FontWeight.w600, height: 1.15)),
        if (o.flightNo.isNotEmpty) Text(o.flightNo, style: TextStyle(color: Neon.textDim, fontSize: 10.5)),
      ],
    );
  }

  static String _code(FlightOption o) {
    final m = RegExp(r'^([A-Z0-9]{2})\s?-?\d').firstMatch(o.flightNo.toUpperCase());
    if (m != null) return m.group(1)!;
    final words = o.airline.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.length >= 2) return (words[0][0] + words[1][0]).toUpperCase();
    return o.airline.substring(0, math.min(2, o.airline.length)).toUpperCase();
  }
}

Airline? _airlineFor(String name) {
  final n = name.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
  if (n.isEmpty) return null;
  Airline? hit;
  for (final a in airlines) {
    final k = a.name.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    if (n == k) return a;
    if (n.startsWith(k) || k.startsWith(n)) hit ??= a;
  }
  return hit;
}

Color _hashColor(String s) {
  final h = s.codeUnits.fold<int>(7, (a, c) => (a * 31 + c) & 0xFFFFFF);
  return HSLColor.fromAHSL(1, (h % 360).toDouble(), 0.55, 0.42).toColor();
}

class _StoreDot extends StatelessWidget {
  const _StoreDot({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final s = PriceStores.named(name, PriceStores.flights);
    final c = s?.color ?? _hashColor(name);
    return Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(7)),
      child: Text(name.isEmpty ? '?' : name.characters.first.toUpperCase(),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
    );
  }
}

class _BookButton extends StatelessWidget {
  const _BookButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Neon.accentFill,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 7, 10, 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Book', style: NeonType.manrope(15, FontWeight.w800).copyWith(color: Colors.white)),
                const SizedBox(width: 6),
                const Icon(Icons.arrow_outward_rounded, size: 16, color: Colors.white),
              ],
            ),
          ),
        ),
      );
}

/// A placeholder card that breathes while the fares load (still when
/// animations are off).
class _SkeletonCard extends StatefulWidget {
  const _SkeletonCard();

  @override
  State<_SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<_SkeletonCard> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.stop();
      _c.value = 0.5;
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget bar(double w, double h) => Container(
          width: w,
          height: h,
          decoration:
              BoxDecoration(color: Neon.textDim.withValues(alpha: 0.22), borderRadius: BorderRadius.circular(6)),
        );
    return FadeTransition(
      opacity: Tween(begin: 0.45, end: 1.0).animate(_c),
      child: Container(
        height: 112,
        padding: const EdgeInsets.all(16),
        decoration: Neon.glassBox(Neon.rLg, lift: false),
        child: Row(
          children: [
            bar(44, 44),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [bar(double.infinity, 18), const SizedBox(height: 10), bar(120, 14)],
              ),
            ),
            const SizedBox(width: 24),
            bar(64, 22),
          ],
        ),
      ),
    );
  }
}

// ── dates ────────────────────────────────────────────────────────────────

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
int _slotOf(int min) => min < 360 ? 0 : (min < 720 ? 1 : (min < 1080 ? 2 : 3));
const _monNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _wdNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
String _mon(DateTime d) => _monNames[d.month - 1];
String _wd(DateTime d) => _wdNames[d.weekday - 1];
