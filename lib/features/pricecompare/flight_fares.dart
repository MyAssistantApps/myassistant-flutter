import 'price_models.dart';

/// ─────────────────────────────────────────────────────────────────────────
///  FLIGHT FARES, ONE FLIGHT PER ROW (2026-11-07, Manish: "do the same ui
///  for the price comparison in flight"): the results list as the travel
///  apps show it — each flight's airline, times, duration and stops, and
///  every booking site's fare for it, cheapest first. Nearby dates carry
///  the lowest fare found for each, for the date strip on top.
///
///  Never invented (§32): a flight with no fare, or no times, is dropped;
///  a nearby date with no fare is left out rather than guessed.
/// ─────────────────────────────────────────────────────────────────────────
class FlightFare {
  const FlightFare({required this.store, required this.price, this.url = ''});
  final String store;
  final double price;

  /// The booking page, when it is really the store's ('' otherwise).
  final String url;

  static FlightFare? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final store = '${raw['store'] ?? ''}'.trim();
    final price = moneyOf(raw['price']);
    if (store.isEmpty || price == null || price <= 0) return null;
    final url = '${raw['url'] ?? ''}'.trim();
    return FlightFare(store: store, price: price, url: url.startsWith('https://') ? url : '');
  }

  Map<String, Object?> toJson() => {'store': store, 'price': price, 'url': url};
}

class FlightOption {
  const FlightOption({
    required this.airline,
    required this.flightNo,
    required this.from,
    required this.to,
    required this.depart,
    required this.arrive,
    required this.fares,
    this.dayOffset = 0,
    this.durationMin,
    this.stops = 0,
    this.via = const [],
  });

  final String airline;
  final String flightNo;
  final String from;
  final String to;

  /// "05:40" — local times at each airport, as the airline lists them;
  /// '' when the web did not say (the flight is still shown, its fare
  /// being real).
  final String depart;
  final String arrive;

  /// 1 when it lands the next day ("+1").
  final int dayOffset;
  final int? durationMin;
  final int stops;
  final List<String> via;

  /// Cheapest first; never empty.
  final List<FlightFare> fares;

  FlightFare get best => fares.first;
  double get price => best.price;

  /// Minutes after midnight it leaves (for "earliest" and the filters).
  int? get departMin => _minutes(depart);

  /// The duration, from the answer or worked out from the two times.
  int get minutes {
    final d = durationMin;
    if (d != null && d > 0) return d;
    final a = _minutes(depart), b = _minutes(arrive);
    if (a == null || b == null) return 0;
    return b + dayOffset * 1440 - a;
  }

  String get durationLabel {
    final m = minutes;
    if (m <= 0) return '';
    final h = m ~/ 60, r = m % 60;
    return h == 0 ? '${r}m' : (r == 0 ? '${h}h' : '${h}h ${r}m');
  }

  String get stopsLabel =>
      stops == 0 ? 'Non-stop' : '$stops stop${stops == 1 ? '' : 's'}${via.isEmpty ? '' : ' · ${via.join(', ')}'}';

  /// One line for the price alert and Recently compared.
  String get title {
    final times = depart.isEmpty
        ? ''
        : ' · $depart${arrive.isEmpty ? '' : '–$arrive'}${dayOffset > 0 && arrive.isNotEmpty ? ' +$dayOffset' : ''}';
    return '$airline${flightNo.isEmpty ? '' : ' $flightNo'}$times · $stopsLabel';
  }

  static FlightOption? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final airline = '${raw['airline'] ?? ''}'.trim();
    final depart = _hhmm(raw['depart']);
    final arrive = _hhmm(raw['arrive']);
    final fares = [
      for (final f in (raw['fares'] as List?) ?? const [])
        if (FlightFare.fromJson(f) case final fare?) fare,
    ]..sort((a, b) => a.price.compareTo(b.price));
    if (airline.isEmpty || fares.isEmpty) return null;
    // One fare per site: the cheapest it showed.
    final seen = <String>{};
    final unique = [
      for (final f in fares)
        if (seen.add(f.store.toLowerCase())) f,
    ];
    final stops = (raw['stops'] is num) ? (raw['stops'] as num).round().clamp(0, 4) : 0;
    final dur = raw['durationMin'] is num ? (raw['durationMin'] as num).round() : null;
    final off = raw['arriveDayOffset'] is num ? (raw['arriveDayOffset'] as num).round().clamp(0, 2) : 0;
    return FlightOption(
      airline: airline,
      flightNo: '${raw['flightNo'] ?? ''}'.trim(),
      from: '${raw['from'] ?? ''}'.trim().toUpperCase(),
      to: '${raw['to'] ?? ''}'.trim().toUpperCase(),
      depart: depart ?? '',
      arrive: arrive ?? '',
      dayOffset: off,
      durationMin: dur != null && dur > 0 && dur < 3000 ? dur : null,
      stops: stops,
      via: [for (final v in (raw['via'] as List?) ?? const []) '$v'.trim().toUpperCase()]
        ..removeWhere((v) => v.isEmpty),
      fares: unique,
    );
  }

  Map<String, Object?> toJson() => {
        'airline': airline,
        'flightNo': flightNo,
        'from': from,
        'to': to,
        'depart': depart,
        'arrive': arrive,
        'arriveDayOffset': dayOffset,
        'durationMin': durationMin,
        'stops': stops,
        'via': via,
        'fares': [for (final f in fares) f.toJson()],
      };
}

class FlightFares {
  const FlightFares({required this.flights, this.nearby = const {}, this.advice = '', this.deals = const []});

  /// Cheapest first.
  final List<FlightOption> flights;

  /// The lowest fare found on other days near the departure, by date.
  final Map<DateTime, double> nearby;
  final String advice;
  final List<PriceDeal> deals;

  FlightOption? get cheapest => flights.isEmpty ? null : flights.first;

  FlightOption? get fastest {
    FlightOption? f;
    for (final o in flights) {
      if (o.minutes <= 0) continue;
      if (f == null || o.minutes < f.minutes || (o.minutes == f.minutes && o.price < f.price)) f = o;
    }
    return f;
  }

  /// Price and time together: each against the best of the list, a stop
  /// costing a little more. Lowest wins.
  double score(FlightOption o) {
    final lowP = cheapest?.price ?? o.price;
    final lowM = fastest?.minutes ?? o.minutes;
    final p = lowP > 0 ? o.price / lowP : 1.0;
    final m = (lowM > 0 && o.minutes > 0) ? o.minutes / lowM : 1.5;
    return p + 0.5 * m + 0.25 * o.stops;
  }

  FlightOption? get bestValue {
    FlightOption? b;
    for (final o in flights) {
      if (b == null || score(o) < score(b)) b = o;
    }
    return b;
  }

  /// A plain comparison (one price per site, the flight in words) as
  /// flight cards: the airline, flight number, times and stops read from
  /// each offer's title, offers for the same flight merged into one card.
  static FlightFares? fromOffers(PriceResult r) {
    final byKey = <String, List<(PriceOffer, String, String, String, String, int)>>{};
    for (final o in r.offers) {
      final text = '${o.title} ${o.note}';
      final airline = _airlineIn(text) ?? _airlineIn(o.store) ?? 'Flight';
      final no = RegExp(r'\b(6E|AI|IX|QP|SG|UK|I5|G8|EK|QR|SQ|EY|TG|MH|UL|BA|LH|AF)[ -]?(\d{2,4})\b')
          .firstMatch(text.toUpperCase());
      final flightNo = no == null ? '' : '${no.group(1)} ${no.group(2)}';
      final times = RegExp(r'\b\d{1,2}:\d{2}\s*(?:[AaPp][Mm])?').allMatches(text).map((m) => m.group(0)!).toList();
      final dep = times.isNotEmpty ? (_hhmm(times[0]) ?? '') : '';
      final arr = times.length > 1 ? (_hhmm(times[1]) ?? '') : '';
      final low = text.toLowerCase();
      final sm = RegExp(r'(\d)\s*stops?').firstMatch(low);
      final stops = RegExp(r'non-?stop|direct').hasMatch(low) ? 0 : (sm == null ? 0 : int.parse(sm.group(1)!));
      final key = '$airline|$flightNo|$dep';
      (byKey[key] ??= []).add((o, airline, flightNo, dep, arr, stops));
    }
    final flights = <FlightOption>[];
    for (final rows in byKey.values) {
      final first = rows.first;
      final seen = <String>{};
      final fares = [
        for (final (o, _, _, _, _, _) in rows)
          if (seen.add(o.store.toLowerCase())) FlightFare(store: o.store, price: o.price, url: o.url),
      ]..sort((a, b) => a.price.compareTo(b.price));
      flights.add(FlightOption(
        airline: first.$2,
        flightNo: first.$3,
        from: '',
        to: '',
        depart: first.$4,
        arrive: first.$5,
        stops: first.$6,
        fares: fares,
      ));
    }
    if (flights.isEmpty) return null;
    flights.sort((a, b) => a.price.compareTo(b.price));
    return FlightFares(flights: flights, advice: r.advice, deals: r.deals);
  }

  static FlightFares? parse(String text) {
    // A long answer can be cut off mid-way; then keep every flight that
    // arrived whole rather than losing them all.
    final j = firstJsonObject(text) ?? _salvage(text);
    if (j == null) return null;
    final flights = [
      for (final f in (j['flights'] as List?) ?? const [])
        if (FlightOption.fromJson(f) case final o?) o,
    ]..sort((a, b) => a.price.compareTo(b.price));
    if (flights.isEmpty) return null;
    final nearby = <DateTime, double>{};
    for (final d in (j['nearbyDates'] as List?) ?? const []) {
      if (d is! Map) continue;
      final at = DateTime.tryParse('${d['date']}');
      final low = moneyOf(d['lowest']);
      if (at != null && low != null && low > 0) nearby[DateTime(at.year, at.month, at.day)] = low;
    }
    return FlightFares(
      flights: flights.take(25).toList(),
      nearby: nearby,
      advice: '${j['advice'] ?? ''}'.trim(),
      deals: [
        for (final d in (j['deals'] as List?) ?? const [])
          if (PriceDeal.fromJson(d) case final deal?) deal,
      ].take(6).toList(),
    );
  }

  /// The same answer as a plain comparison, so Recently compared and the
  /// price alerts keep working: one offer per flight, at its best fare.
  PriceResult toResult({required String query, required String product, DateTime? at}) => PriceResult(
        category: PriceCategory.flights,
        query: query,
        product: product,
        offers: [
          for (final o in flights) PriceOffer(store: o.best.store, price: o.price, title: o.title, url: o.best.url),
        ],
        advice: advice,
        bestPick: bestValue?.best.store ?? '',
        deals: deals,
        at: at,
      );
}

const _airlineNames = [
  'Air India Express',
  'Air India',
  'IndiGo',
  'Akasa Air',
  'Akasa',
  'SpiceJet',
  'Vistara',
  'Alliance Air',
  'Star Air',
  'Fly91',
  'Emirates',
  'Qatar Airways',
  'Etihad',
  'Singapore Airlines',
  'Thai Airways',
  'Malaysia Airlines',
  'SriLankan',
  'British Airways',
  'Lufthansa',
  'Air France',
];

/// The airline named in [text], longest name first ("Air India Express"
/// before "Air India"); null when none is.
String? _airlineIn(String text) {
  final t = text.toLowerCase();
  for (final n in _airlineNames) {
    if (t.contains(n.toLowerCase())) return n == 'Akasa' ? 'Akasa Air' : n;
  }
  return null;
}

/// The whole `{...}` objects inside the answer's "flights" list, when the
/// answer as a whole does not close (cut off at the length limit).
Map? _salvage(String text) {
  final at = text.indexOf('"flights"');
  if (at < 0) return null;
  final open = text.indexOf('[', at);
  if (open < 0) return null;
  final flights = <Object?>[];
  var i = open + 1;
  while (i < text.length) {
    final start = text.indexOf('{', i);
    if (start < 0) break;
    final obj = firstJsonObject(text.substring(start));
    if (obj == null) break; // the cut-off one
    flights.add(obj);
    // Skip past this object: find its matching close.
    var depth = 0, inStr = false, esc = false, j = start;
    for (; j < text.length; j++) {
      final ch = text[j];
      if (inStr) {
        if (esc) {
          esc = false;
        } else if (ch == '\\') {
          esc = true;
        } else if (ch == '"') {
          inStr = false;
        }
        continue;
      }
      if (ch == '"') inStr = true;
      if (ch == '{') depth++;
      if (ch == '}' && --depth == 0) break;
    }
    i = j + 1;
    final next = text.substring(i).trimLeft();
    if (next.startsWith(']')) break;
  }
  return flights.isEmpty ? null : {'flights': flights};
}

/// "5:40", "05:40", "05:40 AM", "5:40 pm" → "05:40"; null when unreadable.
String? _hhmm(Object? v) {
  final m = RegExp(r'(\d{1,2}):(\d{2})\s*([AaPp][Mm])?').firstMatch('${v ?? ''}');
  if (m == null) return null;
  var h = int.parse(m.group(1)!);
  final min = int.parse(m.group(2)!);
  final ap = m.group(3)?.toLowerCase();
  if (ap == 'pm' && h < 12) h += 12;
  if (ap == 'am' && h == 12) h = 0;
  if (h > 23 || min > 59) return null;
  return '${h.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')}';
}

int? _minutes(String hhmm) {
  if (hhmm.isEmpty) return null;
  final p = hhmm.split(':');
  if (p.length != 2) return null;
  final h = int.tryParse(p[0]), m = int.tryParse(p[1]);
  return h == null || m == null ? null : h * 60 + m;
}
