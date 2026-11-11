/// ─────────────────────────────────────────────────────────────────────────
///  A FLIGHT SEARCH (owner, 2026-11-04: "Flight compare should open a page
///  that asks one-way, round-trip, multi-city and the other details"):
///  the trip as the booking sites ask for it — the legs, who is flying,
///  the class, a special fare and non-stop only. [describe] turns it into
///  the words the price search is asked about.
/// ─────────────────────────────────────────────────────────────────────────
library;

class Airport {
  const Airport(this.code, this.city, this.name, {this.country = 'India'});
  final String code;
  final String city;
  final String name;
  final String country;

  String get label => '$city ($code)';

  bool matches(String q) {
    final s = q.trim().toLowerCase();
    if (s.isEmpty) return true;
    return code.toLowerCase().startsWith(s) ||
        city.toLowerCase().contains(s) ||
        name.toLowerCase().contains(s) ||
        country.toLowerCase().startsWith(s);
  }
}

/// India's busiest airports first, then the usual trips abroad.
const airports = <Airport>[
  Airport('DEL', 'New Delhi', 'Indira Gandhi International'),
  Airport('BOM', 'Mumbai', 'Chhatrapati Shivaji Maharaj International'),
  Airport('BLR', 'Bengaluru', 'Kempegowda International'),
  Airport('HYD', 'Hyderabad', 'Rajiv Gandhi International'),
  Airport('MAA', 'Chennai', 'Chennai International'),
  Airport('CCU', 'Kolkata', 'Netaji Subhas Chandra Bose International'),
  Airport('AMD', 'Ahmedabad', 'Sardar Vallabhbhai Patel International'),
  Airport('COK', 'Kochi', 'Cochin International'),
  Airport('PNQ', 'Pune', 'Pune International'),
  Airport('GOI', 'Goa', 'Dabolim'),
  Airport('GOX', 'Goa (Mopa)', 'Manohar International'),
  Airport('IXE', 'Mangaluru', 'Mangaluru International'),
  Airport('TRV', 'Thiruvananthapuram', 'Trivandrum International'),
  Airport('CCJ', 'Kozhikode', 'Calicut International'),
  Airport('JAI', 'Jaipur', 'Jaipur International'),
  Airport('LKO', 'Lucknow', 'Chaudhary Charan Singh International'),
  Airport('GAU', 'Guwahati', 'Lokpriya Gopinath Bordoloi International'),
  Airport('PAT', 'Patna', 'Jay Prakash Narayan'),
  Airport('BBI', 'Bhubaneswar', 'Biju Patnaik International'),
  Airport('IXC', 'Chandigarh', 'Shaheed Bhagat Singh International'),
  Airport('SXR', 'Srinagar', 'Sheikh ul-Alam International'),
  Airport('IXB', 'Bagdogra', 'Bagdogra'),
  Airport('VNS', 'Varanasi', 'Lal Bahadur Shastri International'),
  Airport('ATQ', 'Amritsar', 'Sri Guru Ram Dass Jee International'),
  Airport('IDR', 'Indore', 'Devi Ahilya Bai Holkar'),
  Airport('NAG', 'Nagpur', 'Dr. Babasaheb Ambedkar International'),
  Airport('VTZ', 'Visakhapatnam', 'Visakhapatnam International'),
  Airport('CJB', 'Coimbatore', 'Coimbatore International'),
  Airport('IXZ', 'Port Blair', 'Veer Savarkar International'),
  Airport('IXL', 'Leh', 'Kushok Bakula Rimpochee'),
  Airport('UDR', 'Udaipur', 'Maharana Pratap'),
  Airport('DXB', 'Dubai', 'Dubai International', country: 'UAE'),
  Airport('AUH', 'Abu Dhabi', 'Zayed International', country: 'UAE'),
  Airport('DOH', 'Doha', 'Hamad International', country: 'Qatar'),
  Airport('SIN', 'Singapore', 'Changi', country: 'Singapore'),
  Airport('BKK', 'Bangkok', 'Suvarnabhumi', country: 'Thailand'),
  Airport('KUL', 'Kuala Lumpur', 'Kuala Lumpur International', country: 'Malaysia'),
  Airport('CMB', 'Colombo', 'Bandaranaike International', country: 'Sri Lanka'),
  Airport('MLE', 'Malé', 'Velana International', country: 'Maldives'),
  Airport('KTM', 'Kathmandu', 'Tribhuvan International', country: 'Nepal'),
  Airport('LHR', 'London', 'Heathrow', country: 'UK'),
  Airport('JFK', 'New York', 'John F. Kennedy International', country: 'USA'),
  Airport('SFO', 'San Francisco', 'San Francisco International', country: 'USA'),
  Airport('YYZ', 'Toronto', 'Pearson International', country: 'Canada'),
  Airport('SYD', 'Sydney', 'Kingsford Smith', country: 'Australia'),
  Airport('FRA', 'Frankfurt', 'Frankfurt am Main', country: 'Germany'),
  Airport('CDG', 'Paris', 'Charles de Gaulle', country: 'France'),
];

enum TripType {
  oneWay('One-way'),
  roundTrip('Round-trip'),
  multiCity('Multi-city');

  const TripType(this.label);
  final String label;
}

enum CabinClass {
  economy('Economy'),
  premiumEconomy('Premium Economy'),
  business('Business'),
  first('First');

  const CabinClass(this.label);
  final String label;
}

/// The special fares Indian booking sites offer (proof is shown at check-in).
enum SpecialFare {
  regular('Regular', ''),
  student('Student', 'Extra baggage & discounts'),
  senior('Senior citizen', 'For travellers 60+'),
  armedForces('Armed forces', 'Serving & retired personnel'),
  doctors('Doctors & nurses', 'For medical professionals');

  const SpecialFare(this.label, this.line);
  final String label;
  final String line;
}

class FlightLeg {
  const FlightLeg({this.from, this.to, this.date});
  final Airport? from;
  final Airport? to;
  final DateTime? date;

  bool get complete => from != null && to != null && date != null && from!.code != to!.code;

  FlightLeg copyWith({Airport? from, Airport? to, DateTime? date}) =>
      FlightLeg(from: from ?? this.from, to: to ?? this.to, date: date ?? this.date);

  FlightLeg swapped() => FlightLeg(from: to, to: from, date: date);
}

class FlightTrip {
  const FlightTrip({
    this.type = TripType.oneWay,
    this.legs = const [FlightLeg()],
    this.returnDate,
    this.adults = 1,
    this.children = 0,
    this.infants = 0,
    this.cabin = CabinClass.economy,
    this.fare = SpecialFare.regular,
    this.nonStop = false,
    this.airline = '',
  });

  final TripType type;

  /// One for one-way and round-trip; 2–5 for multi-city.
  final List<FlightLeg> legs;
  final DateTime? returnDate;
  final int adults;

  /// 2–12 years.
  final int children;

  /// Under 2, on a lap: never more than the adults.
  final int infants;
  final CabinClass cabin;
  final SpecialFare fare;
  final bool nonStop;

  /// A preferred airline ('' for any): asked first, others still compared.
  final String airline;

  static const maxTravellers = 9;
  static const maxLegs = 5;

  int get travellers => adults + children + infants;

  FlightTrip copyWith({
    TripType? type,
    List<FlightLeg>? legs,
    DateTime? returnDate,
    bool clearReturn = false,
    int? adults,
    int? children,
    int? infants,
    CabinClass? cabin,
    SpecialFare? fare,
    bool? nonStop,
    String? airline,
  }) =>
      FlightTrip(
        type: type ?? this.type,
        legs: legs ?? this.legs,
        returnDate: clearReturn ? null : (returnDate ?? this.returnDate),
        adults: adults ?? this.adults,
        children: children ?? this.children,
        infants: infants ?? this.infants,
        cabin: cabin ?? this.cabin,
        fare: fare ?? this.fare,
        nonStop: nonStop ?? this.nonStop,
        airline: airline ?? this.airline,
      );

  /// The trip as [type]: multi-city gets a second leg starting where the
  /// first ends; the others keep only the first leg.
  FlightTrip asType(TripType t) {
    if (t == TripType.multiCity) {
      final first = legs.first;
      final next =
          legs.length > 1 ? legs : [first, FlightLeg(from: first.to, date: first.date?.add(const Duration(days: 2)))];
      return copyWith(type: t, legs: next);
    }
    return copyWith(type: t, legs: [legs.first]);
  }

  /// What is still missing, in words; null when the trip can be searched.
  String? problem() {
    for (final (i, l) in legs.indexed) {
      final which = legs.length > 1 ? ' for flight ${i + 1}' : '';
      if (l.from == null) return 'Choose where you fly from$which';
      if (l.to == null) return 'Choose where you fly to$which';
      if (l.from!.code == l.to!.code) return 'From and To must be different$which';
      if (l.date == null) return 'Choose the departure date$which';
      if (i > 0 && legs[i - 1].date != null && l.date!.isBefore(legs[i - 1].date!)) {
        return 'Flight ${i + 1} can\'t leave before flight $i';
      }
    }
    if (type == TripType.roundTrip) {
      if (returnDate == null) return 'Choose the return date';
      if (legs.first.date != null && returnDate!.isBefore(legs.first.date!)) {
        return 'The return can\'t be before the departure';
      }
    }
    if (adults < 1) return 'At least one adult must fly';
    if (infants > adults) return 'Each infant needs an adult';
    if (travellers > maxTravellers) return 'Up to $maxTravellers travellers per booking';
    return null;
  }

  String get travellersLabel {
    final parts = [
      '$adults adult${adults == 1 ? '' : 's'}',
      if (children > 0) '$children child${children == 1 ? '' : 'ren'}',
      if (infants > 0) '$infants infant${infants == 1 ? '' : 's'}',
    ];
    return parts.join(', ');
  }

  /// "BLR → DEL", "BLR ⇄ DEL", "BLR → DEL → BOM".
  String get route {
    if (type == TripType.roundTrip) return '${legs.first.from?.code} ⇄ ${legs.first.to?.code}';
    final codes = <String>[legs.first.from?.code ?? '?'];
    for (final l in legs) {
      if (l.from != null && codes.last != l.from!.code) codes.add('/ ${l.from!.code}');
      codes.add(l.to?.code ?? '?');
    }
    return codes.join(' → ');
  }

  /// The trip in the words the price search is asked about.
  String describe() {
    final b = StringBuffer('${type.label} flight');
    if (type == TripType.multiCity) {
      b.write(' with ${legs.length} flights: ');
      b.write([
        for (final (i, l) in legs.indexed) '${i + 1}) ${l.from!.label} to ${l.to!.label} on ${fullDate(l.date!)}',
      ].join('; '));
    } else {
      final l = legs.first;
      b.write(' from ${l.from!.label} to ${l.to!.label}, departing ${fullDate(l.date!)}');
      if (type == TripType.roundTrip) b.write(', returning ${fullDate(returnDate!)}');
    }
    b.write('. Travellers: $travellersLabel. Class: ${cabin.label}.');
    if (fare != SpecialFare.regular) b.write(' ${fare.label} fare.');
    if (nonStop) b.write(' Non-stop flights only.');
    if (airline.isNotEmpty) b.write(' Preferred airline: $airline (show its fares first, then other airlines).');
    return b.toString();
  }
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// "20 Nov 2026".
String fullDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

/// "Fri, 20 Nov".
String shortDate(DateTime d) => '${_days[d.weekday - 1]}, ${d.day} ${_months[d.month - 1]}';
