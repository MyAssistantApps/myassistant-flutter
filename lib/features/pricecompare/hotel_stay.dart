import 'flight_trip.dart' show fullDate, shortDate;
import 'price_models.dart' show rupees;

/// ─────────────────────────────────────────────────────────────────────────
///  A HOTEL STAY (owner, 2026-11-09: "make a dedicated hotels page"): what
///  the hotel compare page asks — where, check-in and check-out, rooms and
///  guests, the stars and extras wanted, a budget a night — and the one
///  line the price search is given ([query]).
/// ─────────────────────────────────────────────────────────────────────────
enum HotelStars {
  any('Any', 0),
  three('3★ & up', 3),
  four('4★ & up', 4),
  five('5★', 5);

  const HotelStars(this.label, this.min);
  final String label;
  final int min;
}

enum HotelExtra {
  freeCancellation('Free cancellation'),
  breakfast('Breakfast included'),
  pool('Swimming pool'),
  coupleFriendly('Couple friendly'),
  payAtHotel('Pay at hotel');

  const HotelExtra(this.label);
  final String label;
}

class HotelStay {
  const HotelStay({
    this.place = '',
    this.checkIn,
    this.checkOut,
    this.rooms = 1,
    this.adults = 2,
    this.children = 0,
    this.stars = HotelStars.any,
    this.extras = const {},
    this.budget,
  });

  static const maxRooms = 8, maxGuests = 24;

  final String place;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final int rooms;
  final int adults;
  final int children;
  final HotelStars stars;
  final Set<HotelExtra> extras;

  /// Most to pay a night, in rupees.
  final double? budget;

  int get guests => adults + children;

  int get nights => checkIn == null || checkOut == null ? 0 : checkOut!.difference(checkIn!).inDays;

  String get guestsLabel => [
        '$rooms room${rooms == 1 ? '' : 's'}',
        '$adults adult${adults == 1 ? '' : 's'}',
        if (children > 0) '$children child${children == 1 ? '' : 'ren'}',
      ].join(' · ');

  HotelStay copyWith({
    String? place,
    DateTime? checkIn,
    DateTime? checkOut,
    int? rooms,
    int? adults,
    int? children,
    HotelStars? stars,
    Set<HotelExtra>? extras,
    double? budget,
    bool clearBudget = false,
  }) =>
      HotelStay(
        place: place ?? this.place,
        checkIn: checkIn ?? this.checkIn,
        checkOut: checkOut ?? this.checkOut,
        rooms: rooms ?? this.rooms,
        adults: adults ?? this.adults,
        children: children ?? this.children,
        stars: stars ?? this.stars,
        extras: extras ?? this.extras,
        budget: clearBudget ? null : budget ?? this.budget,
      );

  /// What stops the search, said plainly, or null when it can run.
  String? problem() {
    if (place.trim().isEmpty) return 'Choose a city, area or hotel first.';
    if (checkIn == null || checkOut == null) return 'Choose your check-in and check-out dates.';
    if (nights < 1) return 'Check-out must be after check-in.';
    if (nights > 30) return 'Stays of up to 30 nights can be compared.';
    if (adults < rooms) return 'Each room needs at least one adult.';
    return null;
  }

  /// The line the hotel price search is given.
  String query() => [
        '${place.trim()}.',
        'Check-in ${fullDate(checkIn!)} (${shortDate(checkIn!)}), check-out ${fullDate(checkOut!)} '
            '(${shortDate(checkOut!)}), $nights night${nights == 1 ? '' : 's'}.',
        '$guestsLabel.',
        if (stars != HotelStars.any) stars == HotelStars.five ? '5-star hotels only.' : '${stars.min}-star or above.',
        if (extras.isNotEmpty) 'Must have: ${extras.map((e) => e.label.toLowerCase()).join(', ')}.',
        if (budget != null) 'Budget up to ${rupees(budget!)} a night.',
      ].join(' ');
}

/// Places people often compare, for one tap.
const popularHotelPlaces = [
  ('Goa', 'Beaches'),
  ('Mumbai', 'City'),
  ('Bengaluru', 'City'),
  ('New Delhi', 'City'),
  ('Jaipur', 'Heritage'),
  ('Udaipur', 'Lakes'),
  ('Manali', 'Hills'),
  ('Ooty', 'Hills'),
  ('Kochi', 'Backwaters'),
  ('Puducherry', 'Seaside'),
  ('Hyderabad', 'City'),
  ('Mysuru', 'Heritage'),
];
