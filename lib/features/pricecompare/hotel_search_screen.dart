import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design/apple_kit.dart';
import '../../design/motion.dart';
import '../../design/neon_scaffold.dart';
import '../../design/neon_tokens.dart';
import 'flight_trip.dart' show shortDate;
import 'hotel_stay.dart';
import 'price_models.dart';
import 'price_result_screen.dart';
import 'price_service.dart';
import 'price_widgets.dart';
import 'shop_browser.dart' show brandLogoFor;

/// ─────────────────────────────────────────────────────────────────────────
///  HOTEL COMPARE, ITS OWN PAGE (owner, 2026-11-09: "remove the old design
///  and make a dedicated hotels page"), as Flight compare has: where, the
///  dates with the nights between them, rooms and guests, the stars and
///  extras wanted and a budget a night. "Search hotels" compares the stay
///  (PriceResultScreen, the hotels layout); stays compared lately are under.
/// ─────────────────────────────────────────────────────────────────────────
class HotelSearchScreen extends StatefulWidget {
  const HotelSearchScreen({super.key, this.place = ''});

  /// A place to start with (typed on the Price compare page).
  final String place;

  @override
  State<HotelSearchScreen> createState() => _HotelSearchScreenState();
}

class _HotelSearchScreenState extends State<HotelSearchScreen> {
  late final _place = TextEditingController(text: widget.place);
  final _placeFocus = FocusNode();
  final svc = PriceService.instance;
  late HotelStay _stay;
  String _error = '';

  DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  @override
  void initState() {
    super.initState();
    // Tomorrow for one night: the stay most people look for first.
    final inD = _today.add(const Duration(days: 1));
    _stay = HotelStay(place: widget.place, checkIn: inD, checkOut: inD.add(const Duration(days: 1)));
    svc.addListener(_changed);
    _placeFocus.addListener(_changed);
    unawaited(svc.load());
  }

  @override
  void dispose() {
    svc.removeListener(_changed);
    _place.dispose();
    _placeFocus.dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _set(HotelStay s) => setState(() {
        _stay = s;
        _error = '';
      });

  Future<void> _pickDates() async {
    FocusScope.of(context).unfocus();
    final r = await showDateRangePicker(
      context: context,
      firstDate: _today,
      lastDate: _today.add(const Duration(days: 360)),
      initialDateRange: _stay.checkIn != null && _stay.checkOut != null && !_stay.checkIn!.isBefore(_today)
          ? DateTimeRange(start: _stay.checkIn!, end: _stay.checkOut!)
          : null,
      helpText: 'CHECK-IN – CHECK-OUT',
      saveText: 'Done',
    );
    if (r == null) return;
    // One day picked twice is one night, not none.
    final out = r.end.isAfter(r.start) ? r.end : r.start.add(const Duration(days: 1));
    _set(_stay.copyWith(checkIn: r.start, checkOut: out));
  }

  Future<void> _pickGuests() async {
    FocusScope.of(context).unfocus();
    final s = await showAppSheet<HotelStay>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _GuestsSheet(stay: _stay),
    );
    if (s != null) _set(s);
  }

  Future<void> _askBudget() async {
    final c = TextEditingController(text: _stay.budget?.round().toString() ?? '');
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Budget a night'),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(prefixText: '₹ ', hintText: 'Most you want to pay a night'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, ''), child: const Text('Clear')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Done')),
        ],
      ),
    );
    c.dispose();
    if (v == null || !mounted) return;
    final b = double.tryParse(v);
    _set(b == null || b <= 0 ? _stay.copyWith(clearBudget: true) : _stay.copyWith(budget: b));
  }

  void _search() {
    final stay = _stay.copyWith(place: _place.text);
    final problem = stay.problem();
    if (problem != null) {
      HapticFeedback.heavyImpact();
      setState(() => _error = problem);
      if (stay.place.trim().isEmpty) _placeFocus.requestFocus();
      return;
    }
    FocusScope.of(context).unfocus();
    HapticFeedback.mediumImpact();
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PriceResultScreen(category: PriceCategory.hotels, query: stay.query()),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final recent = svc.recent.where((r) => r.category == PriceCategory.hotels).take(5).toList();
    return NeonScaffold(
      appBar: appleAppBar(context, 'Hotel compare'),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 4, 16, 32 + MediaQuery.paddingOf(context).bottom),
          children: [
            _hero(),
            const SizedBox(height: 16),
            _stayCard(),
            const SizedBox(height: 18),
            _label('POPULAR PLACES'),
            const SizedBox(height: 8),
            _popular(),
            const SizedBox(height: 18),
            _label('HOTEL CLASS'),
            const SizedBox(height: 8),
            _starsRow(),
            const SizedBox(height: 18),
            _label('MUST HAVE'),
            const SizedBox(height: 8),
            _extras(),
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
            ApplePrimaryButton(label: 'Search hotels', icon: Icons.search_rounded, onPressed: _search),
            if (recent.isNotEmpty) ...[
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(child: _label('RECENTLY COMPARED')),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                decoration: Neon.glassBox(Neon.rCard),
                child: Column(
                  children: [
                    for (final r in recent)
                      AppleRow(
                        leading: IconTile(Icons.hotel_rounded, PriceCategory.hotels.tint(Neon.violet)),
                        title: r.product,
                        subtitle: r.lowest == null
                            ? 'Hotels'
                            : 'From ${rupees(r.lowest!.price)} a night on ${r.lowest!.store}',
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => PriceResultScreen(category: PriceCategory.hotels, query: r.query, earlier: r),
                        )),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            Text(
              'Room prices are found on the web and change quickly — the booking site shows the final price, '
              'taxes included, before you pay.',
              style: TextStyle(color: Neon.textDim, fontSize: NeonType.caption, height: 1.4),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(onPressed: () => showPhotoCredits(context), child: const Text('Photo credits')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(t, style: NeonType.eyebrow.copyWith(color: Neon.textLo)),
      );

  /// The photo with the promise and the sites it checks.
  Widget _hero() {
    final r = BorderRadius.circular(Neon.rCard);
    return Container(
      height: 168,
      decoration: BoxDecoration(
        borderRadius: r,
        border: Border.all(color: Neon.hairline, width: 1.2),
        image: DecorationImage(
          image: ResizeImage(AssetImage(PriceCategory.hotels.photo), width: 900),
          fit: BoxFit.cover,
        ),
      ),
      child: ClipRRect(
        borderRadius: r,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black.withValues(alpha: 0.82)],
              stops: const [0.2, 1],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text('Same room. Lower price.',
                    style: NeonType.manrope(21, FontWeight.w800)
                        .copyWith(color: Colors.white, letterSpacing: -0.5, height: 1.1)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (final s in PriceStores.hotels) ...[
                      _storeLogo(s),
                      const SizedBox(width: 6),
                    ],
                    const SizedBox(width: 2),
                    Expanded(
                      child: Text('compared for you',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12.5)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _storeLogo(PriceStore s) {
    final logo = brandLogoFor(store: s);
    return Tooltip(
      message: s.name,
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 1.5),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(5.5),
          child: logo == null ? StoreMark(s, size: 23) : Image.asset(logo, fit: BoxFit.cover, cacheWidth: 78),
        ),
      ),
    );
  }

  /// Where, the dates with the nights between them, and the guests.
  Widget _stayCard() {
    final s = _stay;
    final focused = _placeFocus.hasFocus;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: Neon.glassBox(Neon.rCard),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Where
          AnimatedContainer(
            duration: Motion.short,
            padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
            decoration: BoxDecoration(
              color: Neon.surfaceHigh.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(Neon.rMd),
              border: Border.all(color: focused ? Neon.violet : Neon.hairline, width: focused ? 1.5 : 1),
            ),
            child: Row(
              children: [
                Icon(Icons.location_on_rounded, color: Neon.violet, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('WHERE', style: NeonType.eyebrow.copyWith(color: Neon.textDim, fontSize: 10.5)),
                      TextField(
                        controller: _place,
                        focusNode: _placeFocus,
                        textInputAction: TextInputAction.done,
                        textCapitalization: TextCapitalization.words,
                        onChanged: (v) => _set(_stay.copyWith(place: v)),
                        style: NeonType.manrope(18, FontWeight.w800).copyWith(color: Neon.textHi),
                        decoration: InputDecoration(
                          hintText: 'City, area or hotel',
                          hintStyle: NeonType.manrope(17, FontWeight.w700).copyWith(color: Neon.textDim),
                          filled: false,
                          isDense: true,
                          contentPadding: const EdgeInsets.only(top: 2, bottom: 2),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_place.text.isNotEmpty)
                  IconButton(
                    tooltip: 'Clear',
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      _place.clear();
                      _set(_stay.copyWith(place: ''));
                    },
                    icon: Icon(Icons.close_rounded, size: 18, color: Neon.textLo),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // When: check-in · nights · check-out
          _box(
            onTap: _pickDates,
            semantics:
                'Dates: ${s.checkIn == null ? 'choose' : '${shortDate(s.checkIn!)} to ${shortDate(s.checkOut!)}'}',
            child: Row(
              children: [
                Expanded(child: _dateCell('CHECK-IN', s.checkIn)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Neon.violet.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(Neon.rPill),
                    border: Border.all(color: Neon.violet.withValues(alpha: 0.4)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.nights_stay_rounded, size: 14, color: Neon.violet),
                    const SizedBox(width: 4),
                    Text('${s.nights} night${s.nights == 1 ? '' : 's'}',
                        style: NeonType.manrope(12, FontWeight.w800).copyWith(color: Neon.violet)),
                  ]),
                ),
                Expanded(child: _dateCell('CHECK-OUT', s.checkOut, end: true)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Who
          Row(
            children: [
              Expanded(
                flex: 3,
                child: _box(
                  onTap: _pickGuests,
                  semantics: 'Rooms and guests: ${s.guestsLabel}',
                  child: Row(
                    children: [
                      Icon(Icons.people_alt_rounded, color: Neon.violet, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('ROOMS & GUESTS',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: NeonType.eyebrow.copyWith(color: Neon.textDim, fontSize: 10.5)),
                            const SizedBox(height: 2),
                            Text(
                                '${s.rooms} room${s.rooms == 1 ? '' : 's'} · ${s.guests} guest${s.guests == 1 ? '' : 's'}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: NeonType.manrope(15, FontWeight.w800).copyWith(color: Neon.textHi)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: _box(
                  onTap: _askBudget,
                  semantics: 'Budget a night: ${s.budget == null ? 'any' : rupees(s.budget!)}',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('BUDGET / NIGHT',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: NeonType.eyebrow.copyWith(color: Neon.textDim, fontSize: 10.5)),
                      const SizedBox(height: 2),
                      Text(s.budget == null ? 'Any' : rupees(s.budget!),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: NeonType.manrope(15, FontWeight.w800)
                              .copyWith(color: s.budget == null ? Neon.textLo : Neon.textHi)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dateCell(String label, DateTime? d, {bool end = false}) => Column(
        crossAxisAlignment: end ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(label, style: NeonType.eyebrow.copyWith(color: Neon.textDim, fontSize: 10.5)),
          const SizedBox(height: 2),
          Text(d == null ? 'Choose' : shortDate(d),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: NeonType.manrope(16, FontWeight.w800).copyWith(color: d == null ? Neon.textDim : Neon.textHi)),
        ],
      );

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

  Widget _popular() => SizedBox(
        height: 58,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: popularHotelPlaces.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final (city, kind) = popularHotelPlaces[i];
            final on = _place.text.trim().toLowerCase() == city.toLowerCase();
            return Semantics(
              button: true,
              selected: on,
              label: city,
              excludeSemantics: true,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(Neon.rMd),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    FocusScope.of(context).unfocus();
                    _place.text = city;
                    _set(_stay.copyWith(place: city));
                  },
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
                        Text(city, style: NeonType.manrope(14.5, FontWeight.w800).copyWith(color: Neon.textHi)),
                        Text(kind, maxLines: 1, style: TextStyle(color: Neon.textLo, fontSize: 11.5)),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );

  Widget _chip(String label, bool on, VoidCallback onTap) => ChoiceChip(
        label: Text(label),
        selected: on,
        showCheckmark: false,
        selectedColor: Neon.accentFill,
        backgroundColor: Neon.surfaceHigh.withValues(alpha: 0.6),
        side: BorderSide(color: on ? Colors.transparent : Neon.hairline),
        labelStyle: NeonType.manrope(13, FontWeight.w700).copyWith(color: on ? Neon.onAccent : Neon.textHi),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Neon.rPill)),
        onSelected: (_) {
          HapticFeedback.selectionClick();
          onTap();
        },
      );

  Widget _starsRow() => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final st in HotelStars.values) _chip(st.label, st == _stay.stars, () => _set(_stay.copyWith(stars: st))),
        ],
      );

  Widget _extras() => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final e in HotelExtra.values)
            _chip(e.label, _stay.extras.contains(e), () {
              final x = {..._stay.extras};
              x.contains(e) ? x.remove(e) : x.add(e);
              _set(_stay.copyWith(extras: x));
            }),
        ],
      );
}

/// Rooms, adults and children.
class _GuestsSheet extends StatefulWidget {
  const _GuestsSheet({required this.stay});
  final HotelStay stay;

  @override
  State<_GuestsSheet> createState() => _GuestsSheetState();
}

class _GuestsSheetState extends State<_GuestsSheet> {
  late HotelStay s = widget.stay;

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
    final room = HotelStay.maxGuests - s.guests;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Rooms & guests', style: NeonType.manrope(19, FontWeight.w800).copyWith(color: Neon.textHi)),
            const SizedBox(height: 8),
            _stepper('Rooms', 'At least one adult in each', s.rooms, 1, HotelStay.maxRooms,
                (v) => setState(() => s = s.copyWith(rooms: v, adults: s.adults < v ? v : null))),
            _stepper('Adults', '12 years and above', s.adults, s.rooms, s.adults + room,
                (v) => setState(() => s = s.copyWith(adults: v))),
            _stepper('Children', 'Under 12 years', s.children, 0, s.children + room,
                (v) => setState(() => s = s.copyWith(children: v))),
            Text('Up to ${HotelStay.maxRooms} rooms and ${HotelStay.maxGuests} guests.',
                style: TextStyle(color: Neon.textDim, fontSize: 12)),
            const SizedBox(height: 20),
            ApplePrimaryButton(label: 'Done', onPressed: () => Navigator.pop(context, s)),
          ],
        ),
      ),
    );
  }
}
