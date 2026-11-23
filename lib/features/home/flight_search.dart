import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design/apple_kit.dart';
import '../../design/motion.dart';
import '../../design/neon_tokens.dart';
import '../../design/neon_widgets.dart';
import '../pricecompare/flight_results_screen.dart' as pcr;
import '../pricecompare/flight_trip.dart' as pc;
import 'flights_screen.dart' show FlightKind;
import 'voice_booking.dart';

/// ─────────────────────────────────────────────────────────────────────────
///  FLIGHT SEARCH (owner, 2026-11-04): from, to, date, passengers and
///  class, then the price-compare results
///  (pricecompare/flight_results_screen.dart).
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
          title: from ? 'Departure Airport' : 'Arrival Airport', airports: _choices),
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

  /// Spoken: "Bangalore to Delhi on 5th December, 2 passengers, business".
  /// Only what was said changes; returns what did ('' = nothing understood).
  String _heard(String said) {
    final v = VoiceBooking.trip(said, now: DateTime.now(), places: {for (final a in _choices) a.city});
    if (v.isEmpty) return '';
    Airport? at(String? city) => city == null ? null : _choices.firstWhere((a) => a.city == city);
    final done = <String>[];
    setState(() {
      final f = at(v.from), t = at(v.to);
      if (f != null) _from = f;
      if (t != null) _to = t;
      if (f != null || t != null) done.add('${_from?.city ?? '?'} → ${_to?.city ?? '?'}');
      if (v.date != null) {
        _date = v.date!;
        done.add(_fmtDate(_date));
      }
      if (v.people != null) {
        _adults = v.people!.clamp(1, 9);
        done.add('$_adults adult${_adults == 1 ? '' : 's'}');
      }
      if (v.cabin != null) {
        _cabin = switch (v.cabin) {
          'premium' => Cabin.premiumEconomy,
          'business' => Cabin.business,
          'first' => Cabin.first,
          _ => Cabin.economy,
        };
        done.add(_cabin.label);
      }
    });
    return done.join(' · ');
  }

  /// The form as the booking agent sees it.
  BookingForm _voiceForm() => BookingForm(
        screen: _domestic ? 'Domestic Flights' : 'International Flights',
        example: _domestic
            ? '"Bangalore to Delhi on 5th Dec, 2 people"'
            : '"Bangalore to Dubai next Friday, 2 people, business"',
        fields: {
          'from': 'departure city${_domestic ? '' : ' (one end must be outside India)'}',
          'to': 'arrival city',
          'date': 'departure date, YYYY-MM-DD',
          'adults': 'number of passengers, 1 to 9',
          'cabin': 'one of economy, premium, business, first',
        },
        places: {for (final a in _choices) a.city},
        state: () => {
          'from': _from?.city,
          'to': _to?.city,
          'date': BookingAgent.iso(_date),
          'adults': _adults,
          'cabin': switch (_cabin) {
            Cabin.economy => 'economy',
            Cabin.premiumEconomy => 'premium',
            Cabin.business => 'business',
            Cabin.first => 'first',
          },
        },
        apply: _applyVoice,
        parseLocal: _heard,
        actions: {
          'search': ('search flights with this form and show every site\'s fares', () async => _search()),
        },
      );

  /// What the booking agent set; returns what changed.
  String _applyVoice(Map<String, Object?> v) {
    Airport? at(Object? city) {
      final c = voiceText(city)?.toLowerCase();
      if (c == null) return null;
      final alias = VoiceBooking.aliases[c]?.toLowerCase() ?? c;
      for (final a in _choices) {
        if (a.city.toLowerCase() == alias || a.code.toLowerCase() == c) return a;
      }
      return null;
    }

    final done = <String>[];
    setState(() {
      final f = at(v['from']), t = at(v['to']);
      if (f != null) _from = f;
      if (t != null) _to = t;
      if (f != null || t != null) done.add('${_from?.city ?? '?'} → ${_to?.city ?? '?'}');
      final d = voiceDate(v['date']);
      if (d != null) {
        _date = d;
        done.add(_fmtDate(_date));
      }
      final n = voiceInt(v['adults']);
      if (n != null) {
        _adults = n.clamp(1, 9);
        done.add('$_adults adult${_adults == 1 ? '' : 's'}');
      }
      final cabin = voiceText(v['cabin'])?.toLowerCase();
      if (cabin != null) {
        _cabin = cabin.startsWith('prem')
            ? Cabin.premiumEconomy
            : cabin.startsWith('bus')
                ? Cabin.business
                : cabin.startsWith('first')
                    ? Cabin.first
                    : Cabin.economy;
        done.add(_cabin.label);
      }
    });
    return done.join(' · ');
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
          content: Text('Select two different airports.')));
      return;
    }
    if (!_domestic && f.india && t.india) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('For flights within India, please use Domestic.')));
      return;
    }
    HapticFeedback.mediumImpact();
    // 2026-11-07 (Manish): Quick tools' flights open the same results
    // page as Flight compare — each flight with every site's fare.
    pc.Airport conv(Airport a) => pc.Airport(a.code, a.city, a.name, country: a.country);
    final trip = pc.FlightTrip(
      legs: [pc.FlightLeg(from: conv(f), to: conv(t), date: _date)],
      adults: _adults,
      cabin: switch (_cabin) {
        Cabin.economy => pc.CabinClass.economy,
        Cabin.premiumEconomy => pc.CabinClass.premiumEconomy,
        Cabin.business => pc.CabinClass.business,
        Cabin.first => pc.CabinClass.first,
      },
    );
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => pcr.FlightResultsScreen(trip: trip)));
  }

  @override
  Widget build(BuildContext context) {
    return NeonScaffold(
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: BookingVoiceOrb(form: _voiceForm()),
      appBar: appleAppBar(
          context, _domestic ? 'Domestic Flights' : 'International Flights'),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
            16, 8, 16, 120 + MediaQuery.paddingOf(context).bottom),
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
                      Text('Search Flights',
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
                    Text(a == null ? 'Select Airport' : '${a.city} · ${a.code}',
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
