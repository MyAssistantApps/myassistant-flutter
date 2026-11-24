import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../design/apple_kit.dart';
import '../../design/motion.dart';
import '../../design/neon_tokens.dart';
import '../../design/neon_widgets.dart';
import '../../services/api_service.dart';
import 'bus_search.dart' show busCities;
import '../pricecompare/price_models.dart' show rupees;
import 'flight_search.dart' show indianAirports, worldAirports;
import 'hotel_prices.dart';
import 'voice_booking.dart';

/// ─────────────────────────────────────────────────────────────────────────
///  HOTELS (client, 2026-11-05: "I think you missed adding the hotel
///  bookings"). Where, when, how many — then the stay is searched on the
///  partner chosen, through /go so the company's affiliate tracking rides
///  along. Booking.com and Agoda open on the search itself; MakeMyTrip and
///  Goibibo on their hotels page (their search links need their own city
///  codes).
/// ─────────────────────────────────────────────────────────────────────────
class HotelsScreen extends StatefulWidget {
  const HotelsScreen({super.key});

  @override
  State<HotelsScreen> createState() => _HotelsScreenState();
}

String _iso(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
const _mon = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];
String _short(DateTime d) => '${d.day} ${_mon[d.month - 1]}';

class _HotelsScreenState extends State<HotelsScreen> {
  final _city = TextEditingController(text: 'Goa');
  late DateTimeRange _stay = DateTimeRange(
      start: DateTime.now().add(const Duration(days: 1)),
      end: DateTime.now().add(const Duration(days: 2)));
  int _adults = 2;
  int _rooms = 1;

  /// LIVE PRICES (2026-11-24): Google Hotels through our server.
  bool _busy = false;
  List<HotelHit>? _hotels;
  String _error = '';
  int _run = 0;

  Future<void> _comparePrices() async {
    final place = _city.text.trim();
    if (place.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a city, area or hotel.')));
      return;
    }
    FocusScope.of(context).unfocus();
    HapticFeedback.mediumImpact();
    final run = ++_run;
    setState(() {
      _busy = true;
      _error = '';
      _hotels = null;
    });
    final r = await HotelPrices.search(
        place: place, checkIn: _iso(_stay.start), checkOut: _iso(_stay.end), adults: _adults);
    if (!mounted || run != _run) return;
    setState(() {
      _busy = false;
      _hotels = r.hotels;
      _error = r.error;
    });
  }

  Future<void> _openHotel(HotelHit h) async {
    if (h.link.isEmpty) return _open('booking');
    HapticFeedback.selectionClick();
    await launchUrl(Uri.parse(h.link), mode: LaunchMode.externalApplication);
  }

  @override
  void dispose() {
    _city.dispose();
    super.dispose();
  }

  /// Spoken: "Goa from 22 to 25 November, 2 adults, 1 room". Only what was
  /// said changes; returns what did ('' = nothing understood).
  String _heard(String said) {
    final v = VoiceBooking.stay(said, now: DateTime.now(), places: {
      ...busCities,
      for (final a in [...indianAirports, ...worldAirports]) a.city,
    });
    if (v.isEmpty) return '';
    final done = <String>[];
    setState(() {
      if (v.city != null) {
        _city.text = v.city!;
        done.add(v.city!);
      }
      var start = v.checkIn ?? _stay.start;
      var end = v.checkOut ??
          (v.nights != null
              ? start.add(Duration(days: v.nights!.clamp(1, 30)))
              : (v.checkIn != null ? start.add(Duration(days: _stay.duration.inDays.clamp(1, 30))) : _stay.end));
      if (!end.isAfter(start)) end = start.add(const Duration(days: 1));
      if (v.checkIn != null || v.checkOut != null || v.nights != null) {
        _stay = DateTimeRange(start: start, end: end);
        final n = end.difference(start).inDays;
        done.add('${_short(start)} → ${_short(end)} ($n night${n == 1 ? '' : 's'})');
      }
      if (v.adults != null) {
        _adults = v.adults!.clamp(1, 12);
        done.add('$_adults adult${_adults == 1 ? '' : 's'}');
      }
      if (v.rooms != null) {
        _rooms = v.rooms!.clamp(1, 6);
        done.add('$_rooms room${_rooms == 1 ? '' : 's'}');
      }
    });
    return done.join(' · ');
  }

  /// The form as the booking agent sees it: the fields, now, how to set
  /// them, and the sites it can open.
  BookingForm _voiceForm() => BookingForm(
        screen: 'Hotels',
        example: '"Goa, 22 to 25 Nov, 2 adults, 1 room"',
        fields: const {
          'city': 'the city, area or hotel to stay in (any place name)',
          'checkIn': 'check-in date, YYYY-MM-DD',
          'checkOut': 'check-out date, YYYY-MM-DD, after check-in',
          'adults': 'number of adults, 1 to 12',
          'rooms': 'number of rooms, 1 to 6',
        },
        state: () => {
          'city': _city.text.trim(),
          'checkIn': _iso(_stay.start),
          'checkOut': _iso(_stay.end),
          'adults': _adults,
          'rooms': _rooms,
        },
        apply: _applyVoice,
        parseLocal: _heard,
        actions: {
          'booking': ('open the search on Booking.com', () => _open('booking')),
          'agoda': ('open the search on Agoda', () => _open('agoda')),
          'makemytrip': ('open MakeMyTrip hotels', () => _open('makemytrip')),
          'goibibo': ('open Goibibo hotels', () => _open('goibibo')),
        },
      );

  /// What the booking agent set; returns what changed.
  String _applyVoice(Map<String, Object?> v) {
    final done = <String>[];
    setState(() {
      final city = voiceText(v['city']);
      if (city != null && city != _city.text.trim()) {
        _city.text = city;
        done.add(city);
      }
      final a = voiceDate(v['checkIn']), b = voiceDate(v['checkOut']);
      if (a != null || b != null) {
        final start = a ?? _stay.start;
        var end = b ?? (a != null ? start.add(Duration(days: _stay.duration.inDays.clamp(1, 30))) : _stay.end);
        if (!end.isAfter(start)) end = start.add(const Duration(days: 1));
        _stay = DateTimeRange(start: start, end: end);
        final n = end.difference(start).inDays;
        done.add('${_short(start)} → ${_short(end)} ($n night${n == 1 ? '' : 's'})');
      }
      final adults = voiceInt(v['adults']);
      if (adults != null) {
        _adults = adults.clamp(1, 12);
        done.add('$_adults adult${_adults == 1 ? '' : 's'}');
      }
      final rooms = voiceInt(v['rooms']);
      if (rooms != null) {
        _rooms = rooms.clamp(1, 6);
        done.add('$_rooms room${_rooms == 1 ? '' : 's'}');
      }
    });
    return done.join(' · ');
  }

  Future<void> _pickDates() async {
    final now = DateTime.now();
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
      initialDateRange: _stay,
    );
    if (r != null) setState(() => _stay = r);
  }

  String? _searchUrl(String partner) {
    final c = Uri.encodeQueryComponent(_city.text.trim());
    final a = _iso(_stay.start), b = _iso(_stay.end);
    return switch (partner) {
      'booking' => 'https://www.booking.com/searchresults.html?ss=$c'
          '&checkin=$a&checkout=$b&group_adults=$_adults&no_rooms=$_rooms',
      'agoda' => 'https://www.agoda.com/search?textToSearch=$c'
          '&checkIn=$a&checkOut=$b&adults=$_adults&rooms=$_rooms',
      'makemytrip' => 'https://www.makemytrip.com/hotels/',
      'goibibo' => 'https://www.goibibo.com/hotels/',
      _ => null,
    };
  }

  Future<void> _open(String partner) async {
    if (_city.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a city, area or hotel.')));
      return;
    }
    HapticFeedback.selectionClick();
    final target = _searchUrl(partner);
    final q = target == null ? '' : '?url=${Uri.encodeQueryComponent(target)}';
    final j = await ApiService.getJson('/go/$partner$q');
    final url = (j?['url'] as String?) ?? target;
    if (url != null) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nights = _stay.end.difference(_stay.start).inDays;
    return NeonScaffold(
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: BookingVoiceOrb(form: _voiceForm()),
      appBar: appleAppBar(context, 'Hotels'),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: ListView(
          padding: EdgeInsets.fromLTRB(
              16, 8, 16, 120 + MediaQuery.paddingOf(context).bottom),
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: SizedBox(
                height: 200,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset('assets/quick/hotels.jpg', fit: BoxFit.cover),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: const [0.4, 1],
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.8),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 18,
                      bottom: 16,
                      right: 18,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Find Your Stay',
                              style: NeonType.manrope(28, FontWeight.w800)
                                  .copyWith(
                                      color: Colors.white,
                                      letterSpacing: -0.6)),
                          Text('Hotels, resorts and homestays',
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontSize: 14)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              decoration: Neon.glassBox(Neon.rCard),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                    child: Row(children: [
                      Icon(Icons.location_on_rounded, color: Neon.violet),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _city,
                          textCapitalization: TextCapitalization.words,
                          style: NeonType.manrope(18, FontWeight.w800)
                              .copyWith(color: Neon.textHi),
                          decoration: InputDecoration(
                            labelText: 'CITY, AREA OR HOTEL',
                            labelStyle: NeonType.eyebrow
                                .copyWith(color: Neon.textLo),
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                          ),
                        ),
                      ),
                    ]),
                  ),
                  Divider(height: 1, color: Neon.hairline),
                  InkWell(
                    onTap: _pickDates,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(children: [
                        Icon(Icons.calendar_month_rounded, color: Neon.violet),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('CHECK-IN → CHECK-OUT',
                                  style: NeonType.eyebrow
                                      .copyWith(color: Neon.textLo)),
                              Text(
                                  '${_short(_stay.start)} → ${_short(_stay.end)}'
                                  '  ·  $nights night${nights == 1 ? '' : 's'}',
                                  style: NeonType.manrope(17, FontWeight.w800)
                                      .copyWith(color: Neon.textHi)),
                            ],
                          ),
                        ),
                      ]),
                    ),
                  ),
                  Divider(height: 1, color: Neon.hairline),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
                    child: Row(children: [
                      Icon(Icons.group_rounded, color: Neon.violet),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                            '$_adults adult${_adults == 1 ? '' : 's'} · '
                            '$_rooms room${_rooms == 1 ? '' : 's'}',
                            style: NeonType.manrope(16, FontWeight.w800)
                                .copyWith(color: Neon.textHi)),
                      ),
                      _step(Icons.person_remove_rounded,
                          _adults > 1 ? () => setState(() => _adults--) : null),
                      _step(Icons.person_add_rounded,
                          _adults < 12 ? () => setState(() => _adults++) : null),
                      _step(Icons.bed_rounded, () {
                        setState(() => _rooms = _rooms >= 6 ? 1 : _rooms + 1);
                      }),
                    ]),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: _busy ? null : _comparePrices,
                style: FilledButton.styleFrom(
                  backgroundColor: Neon.accentFill,
                  foregroundColor: Neon.onAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: _busy
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2))
                    : const Icon(Icons.price_check_rounded),
                label: Text(_busy ? 'Comparing Prices…' : 'Compare Prices',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
            ..._results(),
            const SizedBox(height: 22),
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 10),
              child: Text('SEARCH ON',
                  style: NeonType.eyebrow.copyWith(color: Neon.textLo)),
            ),
            for (final (id, name, line) in const [
              ('booking', 'Booking.com', 'Hotels worldwide · opens your search'),
              ('agoda', 'Agoda', 'Competitive rates in Asia · opens your search'),
              ('makemytrip', 'MakeMyTrip', 'Hotels across India'),
              ('goibibo', 'Goibibo', 'Hotels and homestays in India'),
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(Neon.rLg),
                    onTap: () => _open(id),
                    child: Ink(
                      padding: const EdgeInsets.all(12),
                      decoration: Neon.glassBox(Neon.rLg),
                      child: Row(children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.asset('assets/brands/$id.png',
                              width: 44, height: 44, fit: BoxFit.cover),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name,
                                  style: NeonType.manrope(15.5, FontWeight.w800)
                                      .copyWith(color: Neon.textHi)),
                              Text(line,
                                  style: TextStyle(
                                      color: Neon.textDim, fontSize: 12.5)),
                            ],
                          ),
                        ),
                        Icon(Icons.open_in_new_rounded,
                            color: Neon.textDim, size: 18),
                      ]),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// The live results: a note, the hotels cheapest first, or why not.
  List<Widget> _results() {
    final hotels = _hotels;
    if (_error.isNotEmpty) {
      return [
        const SizedBox(height: 12),
        EnterOnce(
          rise: 8,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: Neon.glassBox(Neon.rLg),
            child: Row(children: [
              Icon(Icons.info_outline_rounded, color: Neon.warning),
              const SizedBox(width: 10),
              Expanded(child: Text(_error, style: TextStyle(color: Neon.textLo, fontSize: 13.5, height: 1.35))),
            ]),
          ),
        ),
      ];
    }
    if (hotels == null) return const [];
    if (hotels.isEmpty) {
      return [
        const SizedBox(height: 12),
        Text('No hotels were found for this place and these dates. Please try another place or dates.',
            style: TextStyle(color: Neon.textLo, fontSize: 13.5)),
      ];
    }
    final nights = _stay.end.difference(_stay.start).inDays;
    return [
      const SizedBox(height: 18),
      Row(children: [
        Expanded(
          child: Text('${hotels.length} Hotels · Cheapest First',
              style: NeonType.manrope(17, FontWeight.w800).copyWith(color: Neon.textHi)),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: Neon.success.withValues(alpha: Neon.isDark ? 0.16 : 0.10),
            borderRadius: BorderRadius.circular(Neon.rPill),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.verified_rounded, size: 14, color: Neon.success),
            const SizedBox(width: 5),
            Text('Live · Google Hotels',
                style: TextStyle(color: Neon.success, fontSize: 12, fontWeight: FontWeight.w700)),
          ]),
        ),
      ]),
      const SizedBox(height: 12),
      for (final (i, h) in hotels.indexed)
        Reveal(
          delayMs: 40 * i,
          child: Padding(padding: const EdgeInsets.only(bottom: 10), child: _hotelCard(h, nights, cheapest: i == 0)),
        ),
      Text('Prices per night from Google Hotels; taxes and the final price are shown on the booking site.',
          style: TextStyle(color: Neon.textDim, fontSize: 11.5)),
    ];
  }

  Widget _hotelCard(HotelHit h, int nights, {required bool cheapest}) {
    final photo = Container(
      width: 92,
      height: 92,
      decoration: BoxDecoration(color: Neon.surfaceHigh, borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: h.image.isEmpty
          ? Icon(Icons.hotel_rounded, color: Neon.violet.withValues(alpha: 0.6), size: 34)
          : Image.network(h.image,
              fit: BoxFit.cover,
              cacheWidth: 300,
              errorBuilder: (_, __, ___) => Icon(Icons.hotel_rounded, color: Neon.violet.withValues(alpha: 0.6))),
    );
    return Tappable(
      onTap: () => _openHotel(h),
      scale: 0.985,
      semanticLabel: '${h.name}, ${rupees(h.pricePerNight)} a night',
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Neon.surface,
          borderRadius: BorderRadius.circular(Neon.rLg),
          border: Border.all(color: cheapest ? Neon.success.withValues(alpha: 0.6) : Neon.hairline, width: cheapest ? 1.4 : 1),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            photo,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(h.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: NeonType.manrope(15, FontWeight.w800).copyWith(color: Neon.textHi, height: 1.25)),
                  const SizedBox(height: 4),
                  Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    if (h.stars != null)
                      Text('${'★' * h.stars!} ${h.stars}-star',
                          style: TextStyle(color: Neon.warning, fontSize: 12, fontWeight: FontWeight.w600)),
                    if (h.rating != null)
                      Text('${h.rating!.toStringAsFixed(1)}/5${h.reviews == null ? '' : ' (${h.reviews})'}',
                          style: TextStyle(color: Neon.success, fontSize: 12, fontWeight: FontWeight.w700)),
                    if (cheapest)
                      Text('LOWEST PRICE',
                          style: TextStyle(color: Neon.success, fontSize: 10.5, fontWeight: FontWeight.w800)),
                  ]),
                  const SizedBox(height: 8),
                  Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(rupees(h.pricePerNight),
                            style: NeonType.manrope(18, FontWeight.w800).copyWith(color: Neon.textHi)),
                      ),
                    ),
                    Text(' / night', style: TextStyle(color: Neon.textLo, fontSize: 12.5)),
                  ]),
                  Text(
                    [
                      if (h.cheapestSite.isNotEmpty) 'Lowest on ${h.cheapestSite}',
                      if (h.total != null) '${rupees(h.total!)} for $nights night${nights == 1 ? '' : 's'}',
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Neon.textLo, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _step(IconData i, VoidCallback? onTap) => IconButton(
        visualDensity: VisualDensity.compact,
        onPressed: onTap,
        icon: Icon(i, size: 20),
        color: Neon.violet,
      );
}
