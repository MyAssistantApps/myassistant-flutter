import 'package:flutter/material.dart';

import 'flight_trip.dart';

/// ─────────────────────────────────────────────────────────────────────────
///  THE AIRLINES (owner, 2026-11-04: "the banner should be the best
///  airlines — IndiGo and many more — sliding; tapping it opens a page with
///  the full pictures and their information"). Facts that rarely change —
///  the kind of airline, home airports, alliance, cabins — and nothing
///  that goes stale in a month (fleet sizes, prices, rankings). Each photo
///  is from Wikimedia Commons and credited ([airlineCredits]).
/// ─────────────────────────────────────────────────────────────────────────
class Airline {
  const Airline({
    required this.id,
    required this.name,
    required this.tagline,
    required this.kind,
    required this.hubs,
    required this.cabins,
    required this.highlights,
    required this.website,
    required this.color,
    required this.aircraft,
    required this.plane,
    required this.credit,
    this.alliance = '',
    this.gallery = const [],
  });

  final String id;
  final String name;

  /// One line for the banner.
  final String tagline;

  /// "Low-cost" or "Full-service".
  final String kind;
  final List<String> hubs;
  final String alliance;
  final List<String> cabins;
  final List<String> highlights;
  final String website;
  final Color color;

  /// The aircraft in the photo.
  final String aircraft;

  /// The plane in the photo, in detail.
  final Aircraft plane;

  /// "Photographer · licence".
  final String credit;

  /// More photos of this airline: other planes in its fleet and its cabins
  /// (owner, 2026-11-05: "add more images in every airline").
  final List<AirlinePhoto> gallery;

  String get photo => 'assets/pricecompare/airlines/$id.jpg';

  /// The main photo first, then the gallery.
  List<AirlinePhoto> get photos => [AirlinePhoto.main(this), ...gallery];
}

/// One photo on the airlines page, with what it shows and who took it.
class AirlinePhoto {
  const AirlinePhoto(this.file, this.caption, this.credit) : _path = '';
  AirlinePhoto.main(Airline a)
      : file = a.id,
        caption = a.aircraft,
        credit = a.credit,
        _path = a.photo;

  /// The name in assets/pricecompare/airlines/gallery/, without ".jpg".
  final String file;
  final String caption;

  /// "Photographer · licence".
  final String credit;
  final String _path;

  String get path => _path.isNotEmpty ? _path : 'assets/pricecompare/airlines/gallery/$file.jpg';
}

const airlines = <Airline>[
  Airline(
    id: 'indigo',
    name: 'IndiGo',
    tagline: "India's largest airline, with the most flights",
    kind: 'Low-cost',
    hubs: ['Delhi', 'Mumbai', 'Bengaluru', 'Kolkata', 'Hyderabad'],
    cabins: ['Economy', 'IndiGoStretch (select routes)'],
    highlights: [
      'The most domestic flights in India',
      'Growing international network: Gulf, South-East Asia, Europe',
      'Meals and seat choice are paid extras',
    ],
    website: 'https://www.goindigo.in/',
    color: Color(0xFF1B1D6D),
    aircraft: 'Airbus A320neo',
    plane: Aircraft(
      seats: '186, all economy (IndiGo layout)',
      engines: '2 × Pratt & Whitney PW1100G or CFM LEAP-1A',
      length: '37.6 m',
      wingspan: '35.8 m',
      range: 'about 6,300 km',
      speed: 'about 830 km/h (Mach 0.78)',
      usedFor: 'Domestic flights and short trips abroad',
      fact: 'IndiGo flies one of the world\'s largest A320neo-family fleets. "neo" means new engine option: '
          'about 15–20% less fuel than the older A320.',
    ),
    credit: 'Timothy A. Gonsalves · CC BY-SA 4.0',
    gallery: [
      AirlinePhoto('indigo_1', 'Airbus A321neo — the bigger jet for busy routes', 'Bahnfrend · CC BY-SA 4.0'),
      AirlinePhoto('indigo_2', 'ATR 72 turboprop — for smaller airports', 'Timothy A. Gonsalves · CC BY-SA 4.0'),
      AirlinePhoto('indigo_3', 'The all-economy cabin', 'Jer.dv · public domain'),
      AirlinePhoto('indigo_4', 'Boarding by the indigo tail', 'Bssasidhar · CC BY-SA 4.0'),
    ],
  ),
  Airline(
    id: 'airindia',
    name: 'Air India',
    tagline: "India's flag carrier — full service, worldwide",
    kind: 'Full-service',
    hubs: ['Delhi', 'Mumbai'],
    alliance: 'Star Alliance',
    cabins: ['Economy', 'Premium Economy', 'Business', 'First (select routes)'],
    highlights: [
      'Owned by the Tata Group; Vistara merged into it in 2024',
      'Non-stop flights to North America, Europe and Australia',
      'Meals and checked baggage included on most fares',
    ],
    website: 'https://www.airindia.com/',
    color: Color(0xFFD7182A),
    aircraft: 'Airbus A350-900',
    plane: Aircraft(
      seats: '316: 28 business, 24 premium economy, 264 economy',
      engines: '2 × Rolls-Royce Trent XWB-84',
      length: '66.8 m',
      wingspan: '64.8 m',
      range: 'about 15,000 km',
      speed: 'about 900 km/h (Mach 0.85)',
      usedFor: 'Non-stop flights to Europe, the US and beyond',
      fact: 'Air India\'s first A350s arrived in 2024 in the new red, purple and gold livery — the first '
          'Indian airline to fly the A350, with lie-flat suites in business.',
    ),
    credit: 'Pramodkraj12 · CC BY 4.0',
    gallery: [
      AirlinePhoto('airindia_1', 'Boeing 787 Dreamliner', 'Kokitakagi · CC BY 4.0'),
      AirlinePhoto('airindia_2', 'Boeing 777-300ER — long-haul flights', 'Tomo 121 · CC BY-SA 3.0'),
      AirlinePhoto('airindia_3', 'Business class on the 777', 'Prateek Karandikar · CC BY-SA 4.0'),
      AirlinePhoto('airindia_4', 'A320neo in Star Alliance colours', 'UB-TY144 · CC BY 4.0'),
    ],
  ),
  Airline(
    id: 'aix',
    name: 'Air India Express',
    tagline: 'Air India\'s low-cost arm — India and the Gulf',
    kind: 'Low-cost',
    hubs: ['Kochi', 'Delhi', 'Bengaluru'],
    cabins: ['Economy', 'Xpress Biz (select flights)'],
    highlights: [
      'Many flights from Kerala, Karnataka and the south to the Gulf',
      'Merged with AIX Connect (formerly AirAsia India) in 2024',
      'Hot meals can be pre-booked',
    ],
    website: 'https://www.airindiaexpress.com/',
    color: Color(0xFFE5541B),
    aircraft: 'Boeing 737 MAX 8',
    plane: Aircraft(
      seats: 'about 180, economy plus Xpress Biz on some jets',
      engines: '2 × CFM LEAP-1B',
      length: '39.5 m',
      wingspan: '35.9 m',
      range: 'about 6,500 km',
      speed: 'about 840 km/h (Mach 0.79)',
      usedFor: 'Domestic flights and the Gulf',
      fact: 'The tails of Air India Express jets carry Indian art patterns — Bandhani, Kalamkari, Kanjeevaram '
          'and more — so each one looks a little different.',
    ),
    credit: 'Krish Aarush · CC BY-SA 4.0',
    gallery: [
      AirlinePhoto('aix_1', 'Boeing 737 MAX 8', 'Alec Wilson · CC BY-SA 2.0'),
      AirlinePhoto('aix_2', 'Boeing 737-800 in an earlier tail design', 'Aeroprints.com · CC BY-SA 3.0'),
      AirlinePhoto('aix_3', 'Boarding at night', 'Nicksnaresh · CC BY-SA 4.0'),
    ],
  ),
  Airline(
    id: 'akasa',
    name: 'Akasa Air',
    tagline: "India's newest airline — young fleet, friendly fares",
    kind: 'Low-cost',
    hubs: ['Mumbai', 'Bengaluru'],
    cabins: ['Economy'],
    highlights: [
      'Flying since 2022, with an all-Boeing 737 MAX fleet',
      'Pets allowed in the cabin on select flights',
      'Café Akasa meals to pre-order',
    ],
    website: 'https://www.akasaair.com/',
    color: Color(0xFFFF6F3C),
    aircraft: 'Boeing 737 MAX 8',
    plane: Aircraft(
      seats: '189, all economy',
      engines: '2 × CFM LEAP-1B',
      length: '39.5 m',
      wingspan: '35.9 m',
      range: 'about 6,500 km',
      speed: 'about 840 km/h (Mach 0.79)',
      usedFor: 'Domestic flights and short trips abroad',
      fact: 'Akasa flies only the 737 MAX, one of the youngest fleets in India. The MAX burns about 14% less fuel '
          'than the 737s it replaced.',
    ),
    credit: 'Timothy A. Gonsalves · CC BY-SA 4.0',
    gallery: [
      AirlinePhoto('akasa_1', 'Boeing 737 MAX 8 at Chennai', 'Timothy A. Gonsalves · CC BY-SA 4.0'),
      AirlinePhoto('akasa_2', 'Boeing 737 MAX 8-200 — more seats, same size', 'Krish Aarush · CC BY-SA 4.0'),
      AirlinePhoto('akasa_3', 'At Goa\'s Mopa airport', 'Arunpnair 787 · CC BY-SA 4.0'),
    ],
  ),
  Airline(
    id: 'spicejet',
    name: 'SpiceJet',
    tagline: 'Low fares across India and to the Gulf',
    kind: 'Low-cost',
    hubs: ['Delhi', 'Mumbai', 'Hyderabad'],
    cabins: ['Economy', 'SpiceMax extra legroom'],
    highlights: [
      'Flies to many smaller cities too',
      'SpiceMax: more legroom, priority check-in, a meal',
      'Often has sale fares — compare before you book',
    ],
    website: 'https://www.spicejet.com/',
    color: Color(0xFFD71921),
    aircraft: 'Boeing 737-800',
    plane: Aircraft(
      seats: 'up to 189, mostly economy (SpiceMax rows up front)',
      engines: '2 × CFM56-7B',
      length: '39.5 m',
      wingspan: '35.8 m (with winglets)',
      range: 'about 5,400 km',
      speed: 'about 840 km/h (Mach 0.785)',
      usedFor: 'Domestic flights and the Gulf',
      fact: 'The 737-800 is one of the best-selling jets ever built — thousands fly worldwide, and a 737 '
          'takes off somewhere every few seconds.',
    ),
    credit: 'Oleg Yunakov · CC BY-SA 4.0',
    gallery: [
      AirlinePhoto('spicejet_1', 'Boeing 737 MAX 8', 'Md Shaifuzzaman Ayon · CC BY-SA 4.0'),
      AirlinePhoto('spicejet_2', 'Q400 turboprop — for regional routes', 'Premnath Kudva · CC BY-SA 3.0'),
      AirlinePhoto('spicejet_3', 'Boeing 737 MAX coming in to land', 'Anna Zvereva · CC BY-SA 2.0'),
    ],
  ),
  Airline(
    id: 'emirates',
    name: 'Emirates',
    tagline: 'Fly through Dubai to the world, on the A380',
    kind: 'Full-service',
    hubs: ['Dubai'],
    cabins: ['Economy', 'Premium Economy', 'Business', 'First'],
    highlights: [
      'Flies from many Indian cities to Dubai and beyond',
      'The A380 has an onboard lounge and First-class shower spa',
      'Generous baggage and the ice entertainment system',
    ],
    website: 'https://www.emirates.com/in/english/',
    color: Color(0xFFD71A21),
    aircraft: 'Airbus A380-800',
    plane: Aircraft(
      seats: '489 to 615, depending on layout (Emirates)',
      engines: '4 × Engine Alliance GP7200 or Rolls-Royce Trent 900',
      length: '72.7 m',
      wingspan: '79.8 m',
      range: 'about 15,000 km',
      speed: 'about 900 km/h (Mach 0.85)',
      usedFor: 'Busy long-haul routes through Dubai',
      fact: 'The world\'s largest passenger airliner, with two full decks. Emirates flies more A380s than any '
          'other airline, with First-class suites and showers on board.',
    ),
    credit: 'Alf van Beem · public domain',
    gallery: [
      AirlinePhoto('emirates_1', 'Boeing 777-300ER', 'Acabashi · CC BY-SA 4.0'),
      AirlinePhoto('emirates_2', 'A380 First Class suite (shown at ITB Berlin)', 'Travelarz · CC BY-SA 3.0 pl'),
      AirlinePhoto('emirates_3', 'The A380 onboard lounge (shown at ITB Berlin)', 'Travelarz · CC BY-SA 3.0'),
      AirlinePhoto('emirates_4', 'The A380 First Class shower spa (shown at ITB Berlin)', 'Travelarz · CC BY-SA 3.0'),
    ],
  ),
  Airline(
    id: 'qatar',
    name: 'Qatar Airways',
    tagline: 'Award-winning service through Doha',
    kind: 'Full-service',
    hubs: ['Doha'],
    alliance: 'oneworld',
    cabins: ['Economy', 'Business (Qsuite on many routes)', 'First (select routes)'],
    highlights: [
      'Qsuite business class with doors and shared suites',
      'Connections from India to Europe, the Americas and Africa',
      'Hamad International, one of the world\'s best-rated airports',
    ],
    website: 'https://www.qatarairways.com/en-in/',
    color: Color(0xFF5C0632),
    aircraft: 'Airbus A350-1000',
    plane: Aircraft(
      seats: '327 (Qsuite business + economy)',
      engines: '2 × Rolls-Royce Trent XWB-97',
      length: '73.8 m',
      wingspan: '64.8 m',
      range: 'about 16,000 km',
      speed: 'about 900 km/h (Mach 0.85)',
      usedFor: 'Long-haul flights from Doha',
      fact: 'Qatar Airways was the first airline to fly the A350-1000, in 2018 — the longest member of the '
          'A350 family, built largely from carbon-fibre composites.',
    ),
    credit: 'Ian Gratton · CC BY 2.0',
    gallery: [
      AirlinePhoto('qatar_1', 'Boeing 787 Dreamliner', 'Julian Herzog · CC BY 4.0'),
      AirlinePhoto('qatar_2', 'Boeing 777-300ER', 'Acroterion · CC BY-SA 4.0'),
      AirlinePhoto('qatar_3', 'Qsuite business class (shown at ITB Berlin)', 'Travelarz · CC BY-SA 3.0 pl'),
      AirlinePhoto('qatar_4', 'A Qsuite on board the 777', 'Raymondeuro · CC BY-SA 4.0'),
    ],
  ),
  Airline(
    id: 'singapore',
    name: 'Singapore Airlines',
    tagline: 'Legendary service through Changi',
    kind: 'Full-service',
    hubs: ['Singapore'],
    alliance: 'Star Alliance',
    cabins: ['Economy', 'Premium Economy', 'Business', 'Suites & First (select routes)'],
    highlights: [
      'Known for its cabin crew and award-winning service',
      'Connections to Australia, Japan and the US via Changi',
      'Book the Cook: choose your main course before you fly (premium cabins)',
    ],
    website: 'https://www.singaporeair.com/en_UK/in/',
    color: Color(0xFFF3A81C),
    aircraft: 'Airbus A350-900',
    plane: Aircraft(
      seats: '161 to 303 — three layouts, from ultra-long-range to regional',
      engines: '2 × Rolls-Royce Trent XWB-84',
      length: '66.8 m',
      wingspan: '64.8 m',
      range: 'up to about 18,000 km (ultra-long-range version)',
      speed: 'about 900 km/h (Mach 0.85)',
      usedFor: 'Long-haul and regional flights from Singapore',
      fact: 'A special ultra-long-range A350-900 flies Singapore to New York non-stop — among the longest '
          'flights in the world, about 18 hours.',
    ),
    credit: 'Ian Gratton · CC BY 2.0',
    gallery: [
      AirlinePhoto('singapore_1', 'Airbus A380', 'Bahnfrend · CC BY-SA 4.0'),
      AirlinePhoto('singapore_2', 'Boeing 787-10', 'Paul Schmid · CC BY-SA 4.0'),
      AirlinePhoto('singapore_3', 'A380 business class', 'Edwin Leong · CC BY-SA 2.0'),
      AirlinePhoto('singapore_4', 'A380 economy', 'Rudy Herman · CC BY 2.0'),
    ],
  ),
];

/// THE PLANE IN THE PHOTO (owner, 2026-11-04: "the details of that plane,
/// for every airline"): the airline's own seat layout where it is known,
/// otherwise the type's usual range; sizes and performance are the
/// manufacturer's published figures, rounded.
class Aircraft {
  const Aircraft({
    required this.seats,
    required this.engines,
    required this.length,
    required this.wingspan,
    required this.range,
    required this.speed,
    required this.usedFor,
    required this.fact,
  });

  final String seats;
  final String engines;
  final String length;
  final String wingspan;
  final String range;

  /// Typical cruise speed.
  final String speed;
  final String usedFor;

  /// One thing worth knowing about this plane at this airline.
  final String fact;
}

/// A route people search a lot, one tap to fill From and To.
class PopularRoute {
  const PopularRoute(this.from, this.to);
  final String from;
  final String to;

  Airport get fromAirport => airports.firstWhere((a) => a.code == from);
  Airport get toAirport => airports.firstWhere((a) => a.code == to);
}

const popularRoutes = <PopularRoute>[
  PopularRoute('BLR', 'DEL'),
  PopularRoute('BOM', 'DEL'),
  PopularRoute('IXE', 'BOM'),
  PopularRoute('BLR', 'BOM'),
  PopularRoute('DEL', 'GOI'),
  PopularRoute('MAA', 'DEL'),
  PopularRoute('HYD', 'BLR'),
  PopularRoute('CCU', 'DEL'),
  PopularRoute('BOM', 'DXB'),
  PopularRoute('BLR', 'SIN'),
  PopularRoute('DEL', 'LHR'),
  PopularRoute('COK', 'DXB'),
];

/// For the photo credits sheet.
List<(String, String, String)> get airlineCredits => [
      for (final a in airlines)
        for (final p in a.photos)
          (
            '${a.name}: ${p.caption}',
            p.credit.split(' · ').first,
            p.credit.split(' · ').last,
          ),
    ];
