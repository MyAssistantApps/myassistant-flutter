import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design/apple_kit.dart';
import '../../design/motion.dart';
import '../../design/neon_tokens.dart';
import '../../design/neon_widgets.dart';
import '../../services/api_service.dart';
import 'flights_screen.dart' show FlightKind;

/// ─────────────────────────────────────────────────────────────────────────
///  FLIGHT SEARCH (owner, 2026-11-04): from, to, date, passengers and
///  class → the list of real flights (GET /travel/flights). Nothing is
///  invented: with no airline API connected the list says so.
/// ─────────────────────────────────────────────────────────────────────────
class Airport {
  const Airport(this.code, this.city, this.name, {this.country = 'India'});
  final String code;
  final String city;
  final String name;
  final String country;
  bool get india => country == 'India';
}

const indianAirports = <Airport>[
  Airport('DEL', 'New Delhi', 'Indira Gandhi International'),
  Airport('BOM', 'Mumbai', 'Chhatrapati Shivaji Maharaj International'),
  Airport('BLR', 'Bengaluru', 'Kempegowda International'),
  Airport('HYD', 'Hyderabad', 'Rajiv Gandhi International'),
  Airport('MAA', 'Chennai', 'Chennai International'),
  Airport('CCU', 'Kolkata', 'Netaji Subhas Chandra Bose International'),
  Airport('GOI', 'Goa', 'Dabolim'),
  Airport('GOX', 'Goa', 'Manohar International (Mopa)'),
  Airport('COK', 'Kochi', 'Cochin International'),
  Airport('PNQ', 'Pune', 'Pune'),
  Airport('AMD', 'Ahmedabad', 'Sardar Vallabhbhai Patel International'),
  Airport('JAI', 'Jaipur', 'Jaipur International'),
  Airport('LKO', 'Lucknow', 'Chaudhary Charan Singh International'),
  Airport('IXE', 'Mangaluru', 'Mangaluru International'),
  Airport('TRV', 'Thiruvananthapuram', 'Trivandrum International'),
  Airport('CJB', 'Coimbatore', 'Coimbatore International'),
  Airport('GAU', 'Guwahati', 'Lokpriya Gopinath Bordoloi International'),
  Airport('PAT', 'Patna', 'Jay Prakash Narayan'),
  Airport('BBI', 'Bhubaneswar', 'Biju Patnaik International'),
  Airport('IXC', 'Chandigarh', 'Chandigarh International'),
  Airport('SXR', 'Srinagar', 'Sheikh ul-Alam International'),
  Airport('IXB', 'Bagdogra', 'Bagdogra'),
  Airport('VNS', 'Varanasi', 'Lal Bahadur Shastri International'),
  Airport('NAG', 'Nagpur', 'Dr. Babasaheb Ambedkar International'),
  Airport('IDR', 'Indore', 'Devi Ahilya Bai Holkar'),
  Airport('VTZ', 'Visakhapatnam', 'Visakhapatnam International'),
  Airport('IXZ', 'Port Blair', 'Veer Savarkar International'),
  Airport('ATQ', 'Amritsar', 'Sri Guru Ram Dass Jee International'),
  Airport('IXM', 'Madurai', 'Madurai'),
  Airport('UDR', 'Udaipur', 'Maharana Pratap'),
];

const worldAirports = <Airport>[
  Airport('DXB', 'Dubai', 'Dubai International', country: 'UAE'),
  Airport('AUH', 'Abu Dhabi', 'Zayed International', country: 'UAE'),
  Airport('DOH', 'Doha', 'Hamad International', country: 'Qatar'),
  Airport('SIN', 'Singapore', 'Changi', country: 'Singapore'),
  Airport('BKK', 'Bangkok', 'Suvarnabhumi', country: 'Thailand'),
  Airport('KUL', 'Kuala Lumpur', 'Kuala Lumpur International',
      country: 'Malaysia'),
  Airport('LHR', 'London', 'Heathrow', country: 'UK'),
  Airport('CDG', 'Paris', 'Charles de Gaulle', country: 'France'),
  Airport('FRA', 'Frankfurt', 'Frankfurt', country: 'Germany'),
  Airport('AMS', 'Amsterdam', 'Schiphol', country: 'Netherlands'),
  Airport('IST', 'Istanbul', 'Istanbul', country: 'Türkiye'),
  Airport('JFK', 'New York', 'John F. Kennedy International',
      country: 'USA'),
  Airport('EWR', 'New York', 'Newark Liberty International', country: 'USA'),
  Airport('SFO', 'San Francisco', 'San Francisco International',
      country: 'USA'),
  Airport('ORD', 'Chicago', "O'Hare International", country: 'USA'),
  Airport('YYZ', 'Toronto', 'Pearson International', country: 'Canada'),
  Airport('SYD', 'Sydney', 'Kingsford Smith', country: 'Australia'),
  Airport('MEL', 'Melbourne', 'Melbourne', country: 'Australia'),
  Airport('HKG', 'Hong Kong', 'Hong Kong International', country: 'Hong Kong'),
  Airport('NRT', 'Tokyo', 'Narita International', country: 'Japan'),
  Airport('CMB', 'Colombo', 'Bandaranaike International',
      country: 'Sri Lanka'),
  Airport('KTM', 'Kathmandu', 'Tribhuvan International', country: 'Nepal'),
  Airport('MLE', 'Malé', 'Velana International', country: 'Maldives'),
  Airport('DPS', 'Bali', 'Ngurah Rai International', country: 'Indonesia'),
  Airport('JED', 'Jeddah', 'King Abdulaziz International',
      country: 'Saudi Arabia'),
  Airport('RUH', 'Riyadh', 'King Khalid International',
      country: 'Saudi Arabia'),
  Airport('MCT', 'Muscat', 'Muscat International', country: 'Oman'),
  Airport('BAH', 'Bahrain', 'Bahrain International', country: 'Bahrain'),
  Airport('KWI', 'Kuwait City', 'Kuwait International', country: 'Kuwait'),
];

enum Cabin { economy, premiumEconomy, business, first }

extension CabinLabel on Cabin {
  String get label => switch (this) {
        Cabin.economy => 'Economy',
        Cabin.premiumEconomy => 'Premium',
        Cabin.business => 'Business',
        Cabin.first => 'First',
      };

  /// What the server calls it.
  String get wire => this == Cabin.premiumEconomy ? 'premium_economy' : name;
}

class FlightSearchScreen extends StatefulWidget {
  const FlightSearchScreen({super.key, required this.kind});
  final FlightKind kind;

  @override
  State<FlightSearchScreen> createState() => _FlightSearchScreenState();
}

class _FlightSearchScreenState extends State<FlightSearchScreen> {
  late Airport? _from = indianAirports[2]; // Bengaluru
  late Airport? _to = widget.kind == FlightKind.domestic
      ? indianAirports[0] // New Delhi
      : worldAirports[0]; // Dubai
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  int _adults = 1;
  Cabin _cabin = Cabin.economy;

  bool get _domestic => widget.kind == FlightKind.domestic;

  List<Airport> get _choices =>
      _domestic ? indianAirports : [...indianAirports, ...worldAirports];

  Future<void> _pickAirport({required bool from}) async {
    final picked = await showAppSheet<Airport>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AirportPicker(
          title: from ? 'Flying from' : 'Flying to', airports: _choices),
    );
    if (picked == null) return;
    setState(() => from ? _from = picked : _to = picked);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 330)),
    );
    if (d != null) setState(() => _date = d);
  }

  void _swap() {
    HapticFeedback.selectionClick();
    setState(() {
      final f = _from;
      _from = _to;
      _to = f;
    });
  }

  void _search() {
    final f = _from, t = _to;
    if (f == null || t == null || f.code == t.code) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Pick two different airports.')));
      return;
    }
    if (!_domestic && f.india && t.india) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('For flights within India, use Domestic.')));
      return;
    }
    HapticFeedback.mediumImpact();
    Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => FlightResultsScreen(
            from: f, to: t, date: _date, adults: _adults, cabin: _cabin)));
  }

  @override
  Widget build(BuildContext context) {
    return NeonScaffold(
      appBar: appleAppBar(
          context, _domestic ? 'Domestic flights' : 'International flights'),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
            16, 8, 16, 28 + MediaQuery.paddingOf(context).bottom),
        children: [
          // FROM / TO, with the swap button between them.
          Stack(
            alignment: Alignment.centerRight,
            children: [
              Container(
                decoration: Neon.glassBox(Neon.rCard),
                child: Column(
                  children: [
                    _place('FROM', _from, () => _pickAirport(from: true),
                        Icons.flight_takeoff_rounded),
                    Divider(height: 1, indent: 18, endIndent: 18,
                        color: Neon.hairline),
                    _place('TO', _to, () => _pickAirport(from: false),
                        Icons.flight_land_rounded),
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
                    onTap: _swap,
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
          Row(
            children: [
              Expanded(
                child: _tile(
                  'DEPARTURE',
                  _fmtDate(_date),
                  _weekday(_date),
                  Icons.calendar_month_rounded,
                  _pickDate,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: _passengers()),
            ],
          ),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text('CLASS',
                style: NeonType.eyebrow.copyWith(color: Neon.textLo)),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in Cabin.values)
                ChoiceChip(
                  label: Text(c.label),
                  selected: _cabin == c,
                  onSelected: (_) => setState(() => _cabin = c),
                  selectedColor: Neon.accentFill,
                  labelStyle: TextStyle(
                      color: _cabin == c ? Colors.white : Neon.textHi,
                      fontWeight: FontWeight.w700),
                  backgroundColor: Neon.glassFill.colors.first,
                  side: BorderSide(color: Neon.glassEdge.first),
                  showCheckmark: false,
                ),
            ],
          ),
          const SizedBox(height: 28),
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(colors: [
                Color.lerp(Neon.accentFill, Colors.white, 0.12)!,
                Neon.accentFill,
              ]),
              boxShadow: [
                BoxShadow(
                    color: Neon.accentFill.withValues(alpha: 0.45),
                    blurRadius: 22,
                    spreadRadius: -6)
              ],
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
                      Text('Search flights',
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

  Widget _place(String label, Airport? a, VoidCallback onTap, IconData icon) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Neon.rCard),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 76, 14),
          child: Row(
            children: [
              Icon(icon, color: Neon.violet, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: NeonType.eyebrow.copyWith(color: Neon.textLo)),
                    const SizedBox(height: 2),
                    Text(a == null ? 'Choose airport' : '${a.city} · ${a.code}',
                        style: NeonType.manrope(19, FontWeight.w800)
                            .copyWith(color: Neon.textHi)),
                    if (a != null)
                      Text(a.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Neon.textDim, fontSize: 12.5)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  Widget _tile(String label, String value, String sub, IconData icon,
          VoidCallback onTap) =>
      Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(Neon.rLg),
          onTap: onTap,
          child: Ink(
            padding: const EdgeInsets.all(14),
            decoration: Neon.glassBox(Neon.rLg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(icon, size: 16, color: Neon.violet),
                  const SizedBox(width: 6),
                  Text(label,
                      style: NeonType.eyebrow.copyWith(color: Neon.textLo)),
                ]),
                const SizedBox(height: 6),
                Text(value,
                    style: NeonType.manrope(17, FontWeight.w800)
                        .copyWith(color: Neon.textHi)),
                Text(sub, style: TextStyle(color: Neon.textDim, fontSize: 12.5)),
              ],
            ),
          ),
        ),
      );

  Widget _passengers() => Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 8, 10),
        decoration: Neon.glassBox(Neon.rLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.person_rounded, size: 16, color: Neon.violet),
              const SizedBox(width: 6),
              Text('TRAVELLERS',
                  style: NeonType.eyebrow.copyWith(color: Neon.textLo)),
            ]),
            Row(
              children: [
                Text('$_adults',
                    style: NeonType.manrope(17, FontWeight.w800)
                        .copyWith(color: Neon.textHi)),
                Text(_adults == 1 ? ' adult' : ' adults',
                    style: TextStyle(color: Neon.textDim, fontSize: 12.5)),
                const Spacer(),
                _step(Icons.remove_rounded,
                    _adults > 1 ? () => setState(() => _adults--) : null),
                _step(Icons.add_rounded,
                    _adults < 9 ? () => setState(() => _adults++) : null),
              ],
            ),
          ],
        ),
      );

  Widget _step(IconData i, VoidCallback? onTap) => IconButton(
        visualDensity: VisualDensity.compact,
        onPressed: onTap,
        icon: Icon(i, size: 20),
        color: Neon.violet,
      );
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];
const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
String _fmtDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';
String _weekday(DateTime d) => _days[d.weekday - 1];
String _iso(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// A searchable list of airports.
class _AirportPicker extends StatefulWidget {
  const _AirportPicker({required this.title, required this.airports});
  final String title;
  final List<Airport> airports;

  @override
  State<_AirportPicker> createState() => _AirportPickerState();
}

class _AirportPickerState extends State<_AirportPicker> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final q = _q.trim().toLowerCase();
    final list = q.isEmpty
        ? widget.airports
        : widget.airports
            .where((a) =>
                a.code.toLowerCase().contains(q) ||
                a.city.toLowerCase().contains(q) ||
                a.name.toLowerCase().contains(q) ||
                a.country.toLowerCase().contains(q))
            .toList();
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
                hintText: 'City, airport or code',
                prefixIcon: Icon(Icons.search_rounded, color: Neon.textDim),
                filled: true,
                fillColor: Neon.glassFill.colors.first,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: list.length,
              itemBuilder: (_, i) {
                final a = list[i];
                return ListTile(
                  onTap: () => Navigator.pop(context, a),
                  leading: Container(
                    width: 52,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Neon.violet.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(a.code,
                        style: NeonType.manrope(14, FontWeight.w800)
                            .copyWith(color: Neon.violet)),
                  ),
                  title: Text(a.city,
                      style: TextStyle(
                          color: Neon.textHi, fontWeight: FontWeight.w700)),
                  subtitle: Text(
                      a.india ? a.name : '${a.name} · ${a.country}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Neon.textDim)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/* ------------------------------------------------------------------ */
/* RESULTS                                                             */
/* ------------------------------------------------------------------ */

enum _Sort { cheapest, fastest, earliest }

class FlightResultsScreen extends StatefulWidget {
  const FlightResultsScreen({
    super.key,
    required this.from,
    required this.to,
    required this.date,
    required this.adults,
    required this.cabin,
  });
  final Airport from;
  final Airport to;
  final DateTime date;
  final int adults;
  final Cabin cabin;

  @override
  State<FlightResultsScreen> createState() => _FlightResultsScreenState();
}

class _FlightResultsScreenState extends State<FlightResultsScreen> {
  bool _loading = true;
  bool _configured = true;
  String _error = '';
  List<Map<String, dynamic>> _flights = const [];
  _Sort _sort = _Sort.cheapest;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    final w = widget;
    final r = await ApiService.getJson(
        '/travel/flights?from=${w.from.code}&to=${w.to.code}'
        '&date=${_iso(w.date)}&adults=${w.adults}&cabin=${w.cabin.wire}',
        timeout: const Duration(seconds: 25));
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (r == null) {
        _error = "Couldn't reach the server. Check your connection.";
        return;
      }
      _configured = r['configured'] != false;
      _error = (r['error'] ?? '').toString();
      _flights = ((r['flights'] as List?) ?? const [])
          .whereType<Map>()
          .map((m) => m.cast<String, dynamic>())
          .toList();
    });
  }

  List<Map<String, dynamic>> get _sorted {
    final l = [..._flights];
    int n(dynamic v) => (v as num?)?.round() ?? 1 << 30;
    switch (_sort) {
      case _Sort.cheapest:
        l.sort((a, b) => n(a['price']).compareTo(n(b['price'])));
      case _Sort.fastest:
        l.sort((a, b) => n(a['durationMin']).compareTo(n(b['durationMin'])));
      case _Sort.earliest:
        l.sort((a, b) =>
            '${a['departure']}'.compareTo('${b['departure']}'));
    }
    return l;
  }

  @override
  Widget build(BuildContext context) {
    final w = widget;
    return NeonScaffold(
      appBar: appleAppBar(context, '${w.from.code} → ${w.to.code}'),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: Text(
              '${w.from.city} to ${w.to.city} · ${_weekday(w.date)}, '
              '${_fmtDate(w.date)} · ${w.adults} '
              '${w.adults == 1 ? 'adult' : 'adults'} · ${w.cabin.label}',
              textAlign: TextAlign.center,
              style: TextStyle(color: Neon.textLo, fontSize: 13),
            ),
          ),
          if (_flights.isNotEmpty)
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  for (final s in _Sort.values) ...[
                    ChoiceChip(
                      label: Text(switch (s) {
                        _Sort.cheapest => 'Cheapest',
                        _Sort.fastest => 'Fastest',
                        _Sort.earliest => 'Earliest',
                      }),
                      selected: _sort == s,
                      onSelected: (_) => setState(() => _sort = s),
                      selectedColor: Neon.accentFill,
                      labelStyle: TextStyle(
                          color: _sort == s ? Colors.white : Neon.textHi,
                          fontWeight: FontWeight.w700),
                      backgroundColor: Neon.glassFill.colors.first,
                      side: BorderSide(color: Neon.glassEdge.first),
                      showCheckmark: false,
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(
          child: NeonLoader.inline(size: 28, semanticLabel: 'Finding flights'));
    }
    if (!_configured) {
      return _message(
          Icons.cloud_off_rounded,
          'Live flight search is not connected yet',
          'Real flights and fares appear here once an airline data '
              'provider is connected to the app.');
    }
    if (_error.isNotEmpty) {
      return _message(Icons.error_outline_rounded, "Couldn't load flights",
          _error, retry: true);
    }
    if (_flights.isEmpty) {
      return _message(Icons.flight_rounded, 'No flights found',
          'Try another date or nearby airport.');
    }
    final list = _sorted;
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
          16, 8, 16, 24 + MediaQuery.paddingOf(context).bottom),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) => Reveal(
          delayMs: 30 * (i.clamp(0, 8)), child: _FlightTile(f: list[i])),
    );
  }

  Widget _message(IconData icon, String title, String body,
          {bool retry = false}) =>
      Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: Neon.violet),
              const SizedBox(height: 14),
              Text(title,
                  textAlign: TextAlign.center,
                  style: NeonType.manrope(18, FontWeight.w800)
                      .copyWith(color: Neon.textHi)),
              const SizedBox(height: 6),
              Text(body,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Neon.textLo, height: 1.4)),
              if (retry) ...[
                const SizedBox(height: 14),
                TextButton(onPressed: _load, child: const Text('Try again')),
              ],
            ],
          ),
        ),
      );
}

/// One flight: airline and number, times with the duration line between
/// them, stops, and the price.
class _FlightTile extends StatelessWidget {
  const _FlightTile({required this.f});
  final Map<String, dynamic> f;

  static String _time(dynamic iso) {
    final s = '$iso';
    return s.length >= 16 ? s.substring(11, 16) : '--:--';
  }

  static String _dur(dynamic m) {
    final n = (m as num?)?.toInt();
    if (n == null) return '';
    return '${n ~/ 60}h ${(n % 60).toString().padLeft(2, '0')}m';
  }

  static String _price(dynamic p, dynamic cur) {
    final n = (p as num?)?.round();
    if (n == null) return '';
    final s = n.toString();
    // Indian grouping: 1,23,456
    final last3 = s.length > 3 ? s.substring(s.length - 3) : s;
    var rest = s.length > 3 ? s.substring(0, s.length - 3) : '';
    final parts = <String>[];
    while (rest.length > 2) {
      parts.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) parts.insert(0, rest);
    final grouped = [...parts, last3].join(',');
    return cur == 'INR' || cur == null ? '₹$grouped' : '$cur $grouped';
  }

  @override
  Widget build(BuildContext context) {
    final stops = (f['stops'] as num?)?.toInt() ?? 0;
    final via = ((f['via'] as List?) ?? const []).join(', ');
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: Neon.glassBox(Neon.rCard),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Neon.violet.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                clipBehavior: Clip.antiAlias,
                // The airline's logo when the provider gives one
                // (Google Flights does), else its code.
                child: f['logo'] is String && (f['logo'] as String).isNotEmpty
                    ? Container(
                        color: Colors.white,
                        padding: const EdgeInsets.all(4),
                        child: Image.network(f['logo'] as String,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => Text(
                                '${f['carrier'] ?? ''}',
                                style: NeonType.manrope(12, FontWeight.w800)
                                    .copyWith(color: Neon.violet))),
                      )
                    : Text('${f['carrier'] ?? ''}',
                        style: NeonType.manrope(12, FontWeight.w800)
                            .copyWith(color: Neon.violet)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${f['airline'] ?? ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: Neon.textHi,
                            fontWeight: FontWeight.w700,
                            fontSize: 14.5)),
                    Text('${f['flight'] ?? ''}',
                        style: TextStyle(color: Neon.textDim, fontSize: 12.5)),
                  ],
                ),
              ),
              Text(_price(f['price'], f['currency']),
                  style: NeonType.manrope(19, FontWeight.w800)
                      .copyWith(color: Neon.textHi)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _end(_time(f['departure']), '${f['from'] ?? ''}',
                  CrossAxisAlignment.start),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Column(
                    children: [
                      Text(_dur(f['durationMin']),
                          style:
                              TextStyle(color: Neon.textLo, fontSize: 12.5)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                              child: Container(
                                  height: 1.4, color: Neon.hairline)),
                          Icon(Icons.flight_rounded,
                              size: 16, color: Neon.violet),
                          Expanded(
                              child: Container(
                                  height: 1.4, color: Neon.hairline)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                          stops == 0
                              ? 'Non-stop'
                              : '$stops stop${stops > 1 ? 's' : ''}'
                                  '${via.isEmpty ? '' : ' · $via'}',
                          style: TextStyle(
                              color: stops == 0 ? Neon.success : Neon.textLo,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
              _end(_time(f['arrival']), '${f['to'] ?? ''}',
                  CrossAxisAlignment.end),
            ],
          ),
        ],
      ),
    );
  }

  Widget _end(String time, String code, CrossAxisAlignment a) => Column(
        crossAxisAlignment: a,
        children: [
          Text(time,
              style: NeonType.manrope(20, FontWeight.w800)
                  .copyWith(color: Neon.textHi)),
          Text(code, style: TextStyle(color: Neon.textDim, fontSize: 12.5)),
        ],
      );
}
