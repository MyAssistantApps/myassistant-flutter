import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../design/apple_kit.dart';
import '../../design/motion.dart';
import '../../design/neon_tokens.dart';
import '../../design/neon_widgets.dart';
import 'buses_screen.dart' show BusKind, BusKindText;

/// ─────────────────────────────────────────────────────────────────────────
///  BUS SEARCH (owner, 2026-11-04): from, to and date for one kind of bus.
///
///  There is no free public API for Indian intercity buses (redBus, AbhiBus
///  and the aggregators are paid or partner-only; the State RTCs publish no
///  open timetables), so the results page says so plainly — live seats are
///  coming while we talk to bus API providers — and meanwhile hands the
///  route to the real booking sites: redBus with the route filled in,
///  AbhiBus, and for Government buses the official State RTC sites.
///  When a provider is signed, the list goes where the note is.
/// ─────────────────────────────────────────────────────────────────────────
const busCities = <String>[
  'Bengaluru', 'Chennai', 'Hyderabad', 'Mumbai', 'Pune', 'New Delhi',
  'Kolkata', 'Ahmedabad', 'Jaipur', 'Goa', 'Mangaluru', 'Mysuru',
  'Kochi', 'Thiruvananthapuram', 'Kozhikode', 'Coimbatore', 'Madurai',
  'Tiruchirappalli', 'Puducherry', 'Tirupati', 'Vijayawada',
  'Visakhapatnam', 'Hubballi', 'Belagavi', 'Shivamogga', 'Davanagere',
  'Udupi', 'Manipal', 'Nagpur', 'Nashik', 'Aurangabad', 'Kolhapur',
  'Indore', 'Bhopal', 'Lucknow', 'Varanasi', 'Chandigarh', 'Amritsar',
  'Dehradun', 'Shimla', 'Manali', 'Surat', 'Vadodara', 'Udaipur',
];

/// The State RTCs' own booking sites (Government buses).
const _rtcSites = <(String, String, String)>[
  ('KSRTC Karnataka', 'Airavat, Ambaari, Rajahamsa', 'https://ksrtc.in'),
  ('KSRTC Kerala (SWIFT)', 'Kerala State RTC', 'https://onlineksrtcswift.com'),
  ('MSRTC Maharashtra', 'Shivneri, Ashwamedh, Lalpari',
      'https://npublic.msrtcors.com'),
  ('TNSTC / SETC Tamil Nadu', 'State Express, Ultra Deluxe',
      'https://www.tnstc.in'),
  ('APSRTC Andhra Pradesh', 'Amaravathi, Garuda', 'https://www.apsrtconline.in'),
  ('TGSRTC Telangana', 'Rajadhani, Garuda Plus', 'https://www.tgsrtcbus.in'),
  ('GSRTC Gujarat', 'Gujarat State RTC', 'https://gsrtc.in'),
  ('RSRTC Rajasthan', 'Rajasthan State RTC', 'https://rsrtconline.rajasthan.gov.in'),
  ('UPSRTC Uttar Pradesh', 'Uttar Pradesh State RTC', 'https://www.upsrtconline.co.in'),
];

class BusSearchScreen extends StatefulWidget {
  const BusSearchScreen({super.key, required this.kind});
  final BusKind kind;

  @override
  State<BusSearchScreen> createState() => _BusSearchScreenState();
}

class _BusSearchScreenState extends State<BusSearchScreen> {
  String _from = 'Bengaluru';
  String _to = 'Chennai';
  DateTime _date = DateTime.now().add(const Duration(days: 1));

  Future<void> _pickCity({required bool from}) async {
    final c = await showAppSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          _CityPicker(title: from ? 'Leaving from' : 'Going to'),
    );
    if (c != null) setState(() => from ? _from = c : _to = c);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 90)),
    );
    if (d != null) setState(() => _date = d);
  }

  void _search() {
    if (_from == _to) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pick two different cities.')));
      return;
    }
    HapticFeedback.mediumImpact();
    Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => BusResultsScreen(
            kind: widget.kind, from: _from, to: _to, date: _date)));
  }

  @override
  Widget build(BuildContext context) {
    final k = widget.kind;
    return NeonScaffold(
      appBar: appleAppBar(context, '${k.title} buses'),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
            16, 8, 16, 28 + MediaQuery.paddingOf(context).bottom),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(Neon.rCard),
            child: AspectRatio(
              aspectRatio: 16 / 7,
              child: Image.asset(k.photo, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 14),
          Stack(
            alignment: Alignment.centerRight,
            children: [
              Container(
                decoration: Neon.glassBox(Neon.rCard),
                child: Column(
                  children: [
                    _place('FROM', _from, () => _pickCity(from: true),
                        Icons.trip_origin_rounded),
                    Divider(height: 1, indent: 18, endIndent: 18,
                        color: Neon.hairline),
                    _place('TO', _to, () => _pickCity(from: false),
                        Icons.location_on_rounded),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 18),
                child: Material(
                  color: Neon.accentFill,
                  shape: const CircleBorder(),
                  elevation: 4,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => setState(() {
                      final f = _from;
                      _from = _to;
                      _to = f;
                    }),
                    child: const Padding(
                      padding: EdgeInsets.all(10),
                      child: Icon(Icons.swap_vert_rounded,
                          color: Colors.white, size: 22),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(Neon.rLg),
              onTap: _pickDate,
              child: Ink(
                padding: const EdgeInsets.all(16),
                decoration: Neon.glassBox(Neon.rLg),
                child: Row(
                  children: [
                    Icon(Icons.calendar_month_rounded, color: Neon.violet),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('DATE OF JOURNEY',
                            style:
                                NeonType.eyebrow.copyWith(color: Neon.textLo)),
                        Text(_fmt(_date),
                            style: NeonType.manrope(17, FontWeight.w800)
                                .copyWith(color: Neon.textHi)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 26),
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(colors: [
                Color.lerp(Neon.accentFill, Colors.white, 0.12)!,
                Neon.accentFill,
              ]),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: _search,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 17),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.search_rounded,
                          color: Colors.white, size: 22),
                      const SizedBox(width: 8),
                      Text('Search buses',
                          style: NeonType.manrope(16, FontWeight.w800)
                              .copyWith(color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _place(String label, String city, VoidCallback onTap, IconData i) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Neon.rCard),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 76, 16),
          child: Row(
            children: [
              Icon(i, color: Neon.violet, size: 22),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: NeonType.eyebrow.copyWith(color: Neon.textLo)),
                  Text(city,
                      style: NeonType.manrope(19, FontWeight.w800)
                          .copyWith(color: Neon.textHi)),
                ],
              ),
            ],
          ),
        ),
      );
}

const _mon = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];
const _wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
String _fmt(DateTime d) =>
    '${_wd[d.weekday - 1]}, ${d.day} ${_mon[d.month - 1]} ${d.year}';

class _CityPicker extends StatefulWidget {
  const _CityPicker({required this.title});
  final String title;

  @override
  State<_CityPicker> createState() => _CityPickerState();
}

class _CityPickerState extends State<_CityPicker> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final q = _q.trim().toLowerCase();
    final list = q.isEmpty
        ? busCities
        : busCities.where((c) => c.toLowerCase().contains(q)).toList();
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.8,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(widget.title,
                style: NeonType.manrope(18, FontWeight.w800)
                    .copyWith(color: Neon.textHi)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              autofocus: true,
              onChanged: (v) => setState(() => _q = v),
              style: TextStyle(color: Neon.textHi),
              decoration: InputDecoration(
                hintText: 'Search a city',
                prefixIcon: Icon(Icons.search_rounded, color: Neon.textDim),
                filled: true,
                fillColor: Neon.glassFill.colors.first,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                for (final c in list)
                  ListTile(
                    leading: Icon(Icons.location_city_rounded,
                        color: Neon.violet),
                    title: Text(c,
                        style: TextStyle(
                            color: Neon.textHi, fontWeight: FontWeight.w700)),
                    onTap: () => Navigator.pop(context, c),
                  ),
                // A city not on the list: use what was typed.
                if (q.isNotEmpty && !list.any((c) => c.toLowerCase() == q))
                  ListTile(
                    leading: Icon(Icons.add_location_alt_rounded,
                        color: Neon.violet),
                    title: Text('Use "${_q.trim()}"',
                        style: TextStyle(color: Neon.textHi)),
                    onTap: () => Navigator.pop(context, _q.trim()),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/* ------------------------------------------------------------------ */

class BusResultsScreen extends StatelessWidget {
  const BusResultsScreen({
    super.key,
    required this.kind,
    required this.from,
    required this.to,
    required this.date,
  });
  final BusKind kind;
  final String from;
  final String to;
  final DateTime date;

  String _slug(String c) => c
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');

  Future<void> _open(BuildContext context, String url) async {
    HapticFeedback.selectionClick();
    final ok = await launchUrl(Uri.parse(url),
        mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't open that site.")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final redbus =
        'https://www.redbus.in/bus-tickets/${_slug(from)}-to-${_slug(to)}';
    return NeonScaffold(
      appBar: appleAppBar(context, '$from → $to'),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
            16, 4, 16, 28 + MediaQuery.paddingOf(context).bottom),
        children: [
          Text('${kind.title} buses · ${_fmt(date)}',
              textAlign: TextAlign.center,
              style: TextStyle(color: Neon.textLo, fontSize: 13)),
          const SizedBox(height: 14),
          // THE HONEST NOTE: no free bus data exists; providers are being
          // contacted.
          Reveal(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: Neon.glassBox(Neon.rCard).copyWith(
                border:
                    Border.all(color: Neon.violet.withValues(alpha: 0.45)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Neon.violet.withValues(alpha: 0.16),
                    ),
                    child: Icon(Icons.handshake_rounded,
                        color: Neon.violet, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Live seats & fares coming soon',
                            style: NeonType.manrope(16, FontWeight.w800)
                                .copyWith(color: Neon.textHi)),
                        const SizedBox(height: 4),
                        Text(
                            "We're in talks with bus booking API providers "
                            'to show live buses, seats and fares right here. '
                            'Until then, book on the trusted sites below — '
                            'your route is already filled in where they '
                            'allow it.',
                            style: TextStyle(
                                color: Neon.textLo,
                                fontSize: 13.5,
                                height: 1.4)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text('BOOK NOW ON',
                style: NeonType.eyebrow.copyWith(color: Neon.textLo)),
          ),
          if (kind != BusKind.government) ...[
            _site(context, 'redBus', 'India\'s largest bus booking site · '
                '$from to $to', Icons.directions_bus_filled_rounded, redbus),
            _site(context, 'AbhiBus', 'Private and RTC buses across India',
                Icons.confirmation_number_rounded, 'https://www.abhibus.com'),
          ],
          if (kind == BusKind.government) ...[
            for (final (name, line, url) in _rtcSites)
              _site(context, name, line, Icons.account_balance_rounded, url),
            const SizedBox(height: 6),
            _site(context, 'redBus', 'Also lists many State RTC buses',
                Icons.directions_bus_filled_rounded, redbus),
          ],
        ],
      ),
    );
  }

  Widget _site(BuildContext context, String name, String line, IconData icon,
          String url) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(Neon.rLg),
            onTap: () => _open(context, url),
            child: Ink(
              padding: const EdgeInsets.all(14),
              decoration: Neon.glassBox(Neon.rLg),
              child: Row(
                children: [
                  Icon(icon, color: Neon.violet),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: NeonType.manrope(15, FontWeight.w800)
                                .copyWith(color: Neon.textHi)),
                        Text(line,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: Neon.textDim, fontSize: 12.5)),
                      ],
                    ),
                  ),
                  Icon(Icons.open_in_new_rounded,
                      color: Neon.textDim, size: 18),
                ],
              ),
            ),
          ),
        ),
      );
}
