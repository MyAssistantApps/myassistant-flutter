import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design/apple_kit.dart';
import '../../design/motion.dart';
import '../../design/neon_scaffold.dart';
import '../../design/neon_tokens.dart';
import 'airline_widgets.dart';
import 'airlines.dart';
import 'flight_results_screen.dart';
import 'flight_trip.dart';
import 'price_widgets.dart';

/// ─────────────────────────────────────────────────────────────────────────
///  FLIGHT COMPARE, ITS OWN PAGE (owner, 2026-11-04): what the booking
///  sites ask, in the app's glass — One-way / Round-trip / Multi-city,
///  From ⇄ To, the dates, travellers and class, a special fare and
///  non-stop only. "Search flights" compares the trip's fares
///  (PriceResultScreen, the same as every category).
/// ─────────────────────────────────────────────────────────────────────────
class FlightSearchScreen extends StatefulWidget {
  const FlightSearchScreen({super.key});

  @override
  State<FlightSearchScreen> createState() => _FlightSearchScreenState();
}

class _FlightSearchScreenState extends State<FlightSearchScreen> {
  FlightTrip _trip = const FlightTrip();
  String _error = '';

  DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  void _set(FlightTrip t) => setState(() {
        _trip = t;
        _error = '';
      });

  void _setLeg(int i, FlightLeg leg) {
    final legs = [..._trip.legs];
    legs[i] = leg;
    _set(_trip.copyWith(legs: legs));
  }

  Future<void> _pickAirport(int leg, {required bool from}) async {
    final picked = await showAppSheet<Airport>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _AirportPicker(title: from ? 'Flying from' : 'Flying to'),
    );
    if (picked == null) return;
    final l = _trip.legs[leg];
    _setLeg(leg, from ? l.copyWith(from: picked) : l.copyWith(to: picked));
    // Multi-city: the next flight starts where this one lands.
    if (!from && _trip.type == TripType.multiCity && leg + 1 < _trip.legs.length && _trip.legs[leg + 1].from == null) {
      _setLeg(leg + 1, _trip.legs[leg + 1].copyWith(from: picked));
    }
  }

  Future<DateTime?> _date(DateTime? initial, {DateTime? notBefore, String help = 'Departure'}) {
    final first = notBefore ?? _today;
    final start = initial != null && !initial.isBefore(first) ? initial : first;
    return showDatePicker(
      context: context,
      initialDate: start,
      firstDate: first,
      lastDate: _today.add(const Duration(days: 360)),
      helpText: help.toUpperCase(),
    );
  }

  Future<void> _pickDeparture(int leg) async {
    final prev = leg > 0 ? _trip.legs[leg - 1].date : null;
    final d = await _date(_trip.legs[leg].date, notBefore: prev);
    if (d == null) return;
    _setLeg(leg, _trip.legs[leg].copyWith(date: d));
    // A return before the new departure is dropped.
    if (leg == 0 && _trip.returnDate != null && _trip.returnDate!.isBefore(d)) {
      _set(_trip.copyWith(clearReturn: true));
    }
  }

  Future<void> _pickReturn() async {
    final d = await _date(_trip.returnDate ?? _trip.legs.first.date?.add(const Duration(days: 3)),
        notBefore: _trip.legs.first.date, help: 'Return');
    if (d == null) return;
    _set(_trip.copyWith(type: TripType.roundTrip, legs: [_trip.legs.first], returnDate: d));
  }

  Future<void> _pickTravellers() async {
    final t = await showAppSheet<FlightTrip>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _TravellersSheet(trip: _trip),
    );
    if (t != null) _set(t);
  }

  /// The airlines page; "Compare <airline> fares" comes back as the
  /// preferred airline.
  Future<void> _openAirlines(int index) async {
    final name = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => AirlinesScreen(initial: index)),
    );
    if (name == null || !mounted) return;
    _set(_trip.copyWith(airline: name));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$name fares will be shown first — now choose your route and date')),
    );
  }

  /// A popular route fills From and To of the first flight.
  void _route(PopularRoute r) {
    HapticFeedback.selectionClick();
    final l = _trip.legs.first;
    final legs = [..._trip.legs];
    legs[0] = FlightLeg(from: r.fromAirport, to: r.toAirport, date: l.date);
    if (_trip.type == TripType.multiCity && legs.length > 1) legs[1] = legs[1].copyWith(from: r.toAirport);
    _set(_trip.copyWith(legs: legs));
    if (l.date == null) _pickDeparture(0);
  }

  void _search() {
    final problem = _trip.problem();
    if (problem != null) {
      HapticFeedback.heavyImpact();
      setState(() => _error = problem);
      return;
    }
    HapticFeedback.mediumImpact();
    // Every trip type: the flight-by-flight results, one tab per flight.
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => FlightResultsScreen(trip: _trip),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return NeonScaffold(
      appBar: appleAppBar(context, 'Flight compare'),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 4, 16, 32 + MediaQuery.paddingOf(context).bottom),
        children: [
          AirlineCarousel(onOpen: _openAirlines),
          const SizedBox(height: 16),
          _tripTypes(),
          const SizedBox(height: 14),
          _label('POPULAR ROUTES'),
          const SizedBox(height: 8),
          _popular(),
          const SizedBox(height: 14),
          if (_trip.type == TripType.multiCity)
            for (final i in Iterable<int>.generate(_trip.legs.length)) ...[
              _legCard(i),
              const SizedBox(height: 10),
            ]
          else ...[
            _legCard(0),
            const SizedBox(height: 10),
          ],
          if (_trip.type == TripType.multiCity && _trip.legs.length < FlightTrip.maxLegs) ...[
            OutlinedButton.icon(
              onPressed: () {
                final last = _trip.legs.last;
                _set(_trip.copyWith(
                    legs: [..._trip.legs, FlightLeg(from: last.to, date: last.date?.add(const Duration(days: 2)))]));
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add another city'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
                side: BorderSide(color: Neon.violet.withValues(alpha: 0.6)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Neon.rMd)),
              ),
            ),
            const SizedBox(height: 10),
          ],
          _travellersBox(),
          const SizedBox(height: 18),
          _label('SPECIAL FARES'),
          const SizedBox(height: 8),
          _fares(),
          const SizedBox(height: 18),
          _label('PREFERRED AIRLINE'),
          const SizedBox(height: 8),
          _airlinesRow(),
          const SizedBox(height: 10),
          Container(
            decoration: Neon.glassBox(Neon.rLg, lift: false),
            child: SwitchListTile(
              value: _trip.nonStop,
              onChanged: (v) => _set(_trip.copyWith(nonStop: v)),
              title: Text('Non-stop flights only', style: NeonType.row.copyWith(color: Neon.textHi)),
              subtitle: Text('Skip flights with stops or changes',
                  style: TextStyle(color: Neon.textLo, fontSize: NeonType.footnote)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Neon.rLg)),
            ),
          ),
          const SizedBox(height: 18),
          if (_error.isNotEmpty) ...[
            Row(
              children: [
                Icon(Icons.error_outline_rounded, color: Neon.error, size: 18),
                const SizedBox(width: 6),
                Expanded(child: Text(_error, style: TextStyle(color: Neon.error, fontSize: 13.5))),
              ],
            ),
            const SizedBox(height: 10),
          ],
          ApplePrimaryButton(label: 'Search flights', icon: Icons.flight_takeoff_rounded, onPressed: _search),
          const SizedBox(height: 12),
          Text(
            'Fares are found on the web and change quickly — the airline or booking site shows the final fare '
            'before you pay. Special fares need proof at check-in.',
            style: TextStyle(color: Neon.textDim, fontSize: NeonType.caption, height: 1.4),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(onPressed: () => showPhotoCredits(context), child: const Text('Photo credits')),
          ),
        ],
      ),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(t, style: NeonType.eyebrow.copyWith(color: Neon.textLo)),
      );

  Widget _tripTypes() => Container(
        padding: const EdgeInsets.all(4),
        decoration: Neon.glassBox(Neon.rPill, lift: false),
        child: Row(
          children: [
            for (final t in TripType.values)
              Expanded(
                child: Semantics(
                  button: true,
                  selected: t == _trip.type,
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      if (t == TripType.roundTrip && _trip.returnDate == null) {
                        _set(_trip.asType(t));
                        _pickReturn();
                      } else {
                        _set(_trip.asType(t));
                      }
                    },
                    child: AnimatedContainer(
                      duration: Neon.fast,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(Neon.rPill),
                        color: t == _trip.type ? Neon.accentFill : Colors.transparent,
                      ),
                      child: Text(t.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: NeonType.manrope(13.5, FontWeight.w800)
                              .copyWith(color: t == _trip.type ? Neon.onAccent : Neon.textLo)),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );

  /// One flight: From over To with the swap button between them, then
  /// the dates.
  Widget _legCard(int i) {
    final leg = _trip.legs[i];
    final multi = _trip.type == TripType.multiCity;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: Neon.glassBox(Neon.rCard),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (multi)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 0, 6),
              child: Row(
                children: [
                  Text('FLIGHT ${i + 1}', style: NeonType.eyebrow.copyWith(color: Neon.violet)),
                  const Spacer(),
                  if (_trip.legs.length > 2)
                    IconButton(
                      tooltip: 'Remove flight ${i + 1}',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _set(_trip.copyWith(legs: [..._trip.legs]..removeAt(i))),
                      icon: Icon(Icons.close_rounded, size: 18, color: Neon.textLo),
                    ),
                ],
              ),
            ),
          Stack(
            children: [
              Column(
                children: [
                  _airportBox('FROM', leg.from, () => _pickAirport(i, from: true)),
                  const SizedBox(height: 8),
                  _airportBox('TO', leg.to, () => _pickAirport(i, from: false)),
                ],
              ),
              Positioned(
                right: 18,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Material(
                    color: Neon.accentFill,
                    shape: const CircleBorder(),
                    elevation: 3,
                    child: IconButton(
                      tooltip: 'Swap From and To',
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        _setLeg(i, leg.swapped());
                      },
                      icon: Icon(Icons.swap_vert_rounded, color: Neon.onAccent),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _dateBox('DEPARTURE', leg.date, () => _pickDeparture(i))),
              if (!multi) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: _dateBox(
                    'RETURN',
                    _trip.type == TripType.roundTrip ? _trip.returnDate : null,
                    _pickReturn,
                    empty: 'Tap to add',
                    onClear: _trip.type == TripType.roundTrip
                        ? () => _set(_trip.copyWith(type: TripType.oneWay, clearReturn: true))
                        : null,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _box({required Widget child, required VoidCallback onTap, String? semantics}) => Semantics(
        button: true,
        label: semantics,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(Neon.rMd),
            onTap: () {
              HapticFeedback.selectionClick();
              onTap();
            },
            child: Ink(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              decoration: BoxDecoration(
                color: Neon.surfaceHigh.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(Neon.rMd),
                border: Border.all(color: Neon.hairline),
              ),
              child: child,
            ),
          ),
        ),
      );

  Widget _airportBox(String label, Airport? a, VoidCallback onTap) => _box(
        onTap: onTap,
        semantics: '$label: ${a?.label ?? 'choose'}',
        child: Padding(
          padding: const EdgeInsets.only(right: 56),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: NeonType.eyebrow.copyWith(color: Neon.textDim, fontSize: 10.5)),
              const SizedBox(height: 2),
              if (a == null)
                Text('Choose city or airport',
                    style: NeonType.manrope(17, FontWeight.w700).copyWith(color: Neon.textDim))
              else ...[
                Text(a.city,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: NeonType.manrope(20, FontWeight.w800).copyWith(color: Neon.textHi, letterSpacing: -0.4)),
                Text('${a.code} · ${a.name}',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Neon.textLo, fontSize: 12.5)),
              ],
            ],
          ),
        ),
      );

  Widget _dateBox(String label, DateTime? d, VoidCallback onTap,
          {String empty = 'Choose date', VoidCallback? onClear}) =>
      _box(
        onTap: onTap,
        semantics: '$label: ${d == null ? empty : fullDate(d)}',
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: NeonType.eyebrow.copyWith(color: Neon.textDim, fontSize: 10.5)),
                  const SizedBox(height: 2),
                  Text(d == null ? empty : shortDate(d),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: NeonType.manrope(16, FontWeight.w800)
                          .copyWith(color: d == null ? Neon.textDim : Neon.textHi)),
                  if (d != null) Text('${d.year}', style: TextStyle(color: Neon.textLo, fontSize: 12)),
                ],
              ),
            ),
            if (onClear != null)
              GestureDetector(
                onTap: onClear,
                child: Icon(Icons.close_rounded, size: 18, color: Neon.textLo, semanticLabel: 'Remove return'),
              ),
          ],
        ),
      );

  Widget _travellersBox() => _box(
        onTap: _pickTravellers,
        semantics: 'Travellers and class: ${_trip.travellersLabel}, ${_trip.cabin.label}',
        child: Row(
          children: [
            Icon(Icons.people_alt_rounded, color: Neon.violet),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('TRAVELLERS & CLASS', style: NeonType.eyebrow.copyWith(color: Neon.textDim, fontSize: 10.5)),
                  const SizedBox(height: 2),
                  Text('${_trip.travellers} traveller${_trip.travellers == 1 ? '' : 's'} · ${_trip.cabin.label}',
                      style: NeonType.manrope(16, FontWeight.w800).copyWith(color: Neon.textHi)),
                  Text(_trip.travellersLabel, style: TextStyle(color: Neon.textLo, fontSize: 12.5)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Neon.textDim),
          ],
        ),
      );

  Widget _popular() {
    final first = _trip.legs.first;
    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: popularRoutes.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final r = popularRoutes[i];
          final on = first.from?.code == r.from && first.to?.code == r.to;
          return Semantics(
            button: true,
            selected: on,
            label: '${r.fromAirport.city} to ${r.toAirport.city}',
            excludeSemantics: true,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(Neon.rMd),
                onTap: () => _route(r),
                child: Ink(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(Neon.rMd),
                    color: on ? Neon.violet.withValues(alpha: 0.2) : Neon.surfaceHigh.withValues(alpha: 0.55),
                    border: Border.all(color: on ? Neon.violet : Neon.hairline, width: on ? 1.4 : 1),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(r.from, style: NeonType.manrope(15, FontWeight.w800).copyWith(color: Neon.textHi)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Icon(Icons.flight_rounded, size: 14, color: Neon.violet),
                          ),
                          Text(r.to, style: NeonType.manrope(15, FontWeight.w800).copyWith(color: Neon.textHi)),
                        ],
                      ),
                      Text('${r.fromAirport.city} – ${r.toAirport.city}',
                          maxLines: 1, style: TextStyle(color: Neon.textLo, fontSize: 11.5)),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _airlinesRow() => SizedBox(
        height: 40,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            for (final name in ['', for (final a in airlines) a.name])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(name.isEmpty ? 'Any airline' : name),
                  selected: _trip.airline == name,
                  showCheckmark: false,
                  selectedColor: Neon.accentFill,
                  backgroundColor: Neon.surfaceHigh.withValues(alpha: 0.6),
                  side: BorderSide(color: _trip.airline == name ? Colors.transparent : Neon.hairline),
                  labelStyle: NeonType.manrope(13, FontWeight.w700)
                      .copyWith(color: _trip.airline == name ? Neon.onAccent : Neon.textHi),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Neon.rPill)),
                  onSelected: (_) => _set(_trip.copyWith(airline: name)),
                ),
              ),
          ],
        ),
      );

  Widget _fares() => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final f in SpecialFare.values)
            ChoiceChip(
              label: Text(f.label),
              selected: f == _trip.fare,
              showCheckmark: false,
              tooltip: f.line.isEmpty ? null : f.line,
              selectedColor: Neon.accentFill,
              backgroundColor: Neon.surfaceHigh.withValues(alpha: 0.6),
              side: BorderSide(color: f == _trip.fare ? Colors.transparent : Neon.hairline),
              labelStyle:
                  NeonType.manrope(13, FontWeight.w700).copyWith(color: f == _trip.fare ? Neon.onAccent : Neon.textHi),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Neon.rPill)),
              onSelected: (_) => _set(_trip.copyWith(fare: f)),
            ),
        ],
      );
}

/// Search the airports: city, code or airport name.
class _AirportPicker extends StatefulWidget {
  const _AirportPicker({required this.title});
  final String title;

  @override
  State<_AirportPicker> createState() => _AirportPickerState();
}

class _AirportPickerState extends State<_AirportPicker> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final list = airports.where((a) => a.matches(_q)).toList();
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.85,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
              child: Text(widget.title, style: NeonType.manrope(19, FontWeight.w800).copyWith(color: Neon.textHi)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: AppleSearchField(hint: 'City, airport or code', onChanged: (v) => setState(() => _q = v)),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: list.isEmpty
                  ? Center(
                      child: Text('No airport matches "$_q"', style: TextStyle(color: Neon.textLo)),
                    )
                  : ListView.builder(
                      itemCount: list.length,
                      itemBuilder: (_, i) {
                        final a = list[i];
                        return ListTile(
                          leading: Container(
                            width: 46,
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Neon.violet.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(Neon.rSm),
                            ),
                            child:
                                Text(a.code, style: NeonType.manrope(13, FontWeight.w800).copyWith(color: Neon.violet)),
                          ),
                          title: Text(a.city, style: NeonType.row.copyWith(color: Neon.textHi)),
                          subtitle: Text('${a.name}${a.country == 'India' ? '' : ', ${a.country}'}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: Neon.textLo, fontSize: 12.5)),
                          onTap: () => Navigator.pop(context, a),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Adults, children, infants and the class.
class _TravellersSheet extends StatefulWidget {
  const _TravellersSheet({required this.trip});
  final FlightTrip trip;

  @override
  State<_TravellersSheet> createState() => _TravellersSheetState();
}

class _TravellersSheetState extends State<_TravellersSheet> {
  late FlightTrip t = widget.trip;

  Widget _stepper(String title, String line, int value, int min, int max, void Function(int) set) {
    Widget btn(IconData i, bool on, VoidCallback f) => IconButton.filledTonal(
          onPressed: on
              ? () {
                  HapticFeedback.selectionClick();
                  f();
                }
              : null,
          icon: Icon(i, size: 18),
        );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: NeonType.row.copyWith(color: Neon.textHi)),
                Text(line, style: TextStyle(color: Neon.textLo, fontSize: 12.5)),
              ],
            ),
          ),
          btn(Icons.remove_rounded, value > min, () => set(value - 1)),
          SizedBox(
            width: 34,
            child: Text('$value',
                textAlign: TextAlign.center, style: NeonType.manrope(17, FontWeight.w800).copyWith(color: Neon.textHi)),
          ),
          btn(Icons.add_rounded, value < max, () => set(value + 1)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final room = FlightTrip.maxTravellers - t.travellers;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Travellers & class', style: NeonType.manrope(19, FontWeight.w800).copyWith(color: Neon.textHi)),
            const SizedBox(height: 8),
            _stepper('Adults', '12 years and above', t.adults, 1, t.adults + room,
                (v) => setState(() => t = t.copyWith(adults: v, infants: t.infants > v ? v : null))),
            _stepper('Children', '2 – 12 years', t.children, 0, t.children + room,
                (v) => setState(() => t = t.copyWith(children: v))),
            _stepper(
                'Infants',
                'Under 2 years, on a lap',
                t.infants,
                0,
                [t.adults, t.infants + room].reduce((a, b) => a < b ? a : b),
                (v) => setState(() => t = t.copyWith(infants: v))),
            Text('Up to ${FlightTrip.maxTravellers} travellers; one infant per adult.',
                style: TextStyle(color: Neon.textDim, fontSize: 12)),
            const SizedBox(height: 16),
            Text('CLASS', style: NeonType.eyebrow.copyWith(color: Neon.textLo)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in CabinClass.values)
                  ChoiceChip(
                    label: Text(c.label),
                    selected: c == t.cabin,
                    showCheckmark: false,
                    selectedColor: Neon.accentFill,
                    labelStyle: NeonType.manrope(13, FontWeight.w700)
                        .copyWith(color: c == t.cabin ? Neon.onAccent : Neon.textHi),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Neon.rPill)),
                    onSelected: (_) => setState(() => t = t.copyWith(cabin: c)),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            ApplePrimaryButton(label: 'Done', onPressed: () => Navigator.pop(context, t)),
          ],
        ),
      ),
    );
  }
}
