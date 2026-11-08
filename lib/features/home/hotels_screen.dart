import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../design/apple_kit.dart';
import '../../design/neon_tokens.dart';
import '../../design/neon_widgets.dart';
import '../../services/api_service.dart';

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

  @override
  void dispose() {
    _city.dispose();
    super.dispose();
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
          const SnackBar(content: Text('Where are you staying?')));
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
      appBar: appleAppBar(context, 'Hotels'),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: ListView(
          padding: EdgeInsets.fromLTRB(
              16, 8, 16, 28 + MediaQuery.paddingOf(context).bottom),
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
                          Text('Find your stay',
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
            const SizedBox(height: 22),
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 10),
              child: Text('SEARCH ON',
                  style: NeonType.eyebrow.copyWith(color: Neon.textLo)),
            ),
            for (final (id, name, line) in const [
              ('booking', 'Booking.com', 'Hotels worldwide · opens your search'),
              ('agoda', 'Agoda', 'Great deals in Asia · opens your search'),
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

  Widget _step(IconData i, VoidCallback? onTap) => IconButton(
        visualDensity: VisualDensity.compact,
        onPressed: onTap,
        icon: Icon(i, size: 20),
        color: Neon.violet,
      );
}
