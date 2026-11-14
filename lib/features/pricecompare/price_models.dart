import 'dart:convert';

import 'package:flutter/material.dart';

/// ─────────────────────────────────────────────────────────────────────────
///  PRICE COMPARE (2026-11-04, owner): one place to see what a thing costs
///  across the apps people in India actually use — shopping, flights,
///  hotels, cabs and groceries — laid out like BuyHatke: search on
///  top, the lowest price first, every store under it, the price history,
///  a "buy now or wait" verdict, the offers, and a price alert.
///
///  HONEST BY DESIGN (as deal_banners.dart): there is no price feed from
///  these platforms. Prices come from a Google-Search-grounded answer,
///  shown with the pages they came from and labelled "as found on the
///  web"; the price history is only what was reported on the web plus
///  the prices this phone itself saw on its own checks. A store's button
///  opens that store's OWN search for the thing, so the user always sees
///  the real, current price before paying.
/// ─────────────────────────────────────────────────────────────────────────

/// One app or site to compare: its name, colour and own search page.
class PriceStore {
  const PriceStore(this.name, this.color, this.search, {this.pkg = '', this.domains = const []});

  final String name;
  final Color color;

  /// The store's own search URL, `{q}` replaced by the query; '' when it
  /// has none (a cab app, an airline's home page).
  final String search;

  /// The Android app, opened for the link when installed.
  final String pkg;

  /// Hosts a link from the web answer may point at for this store.
  final List<String> domains;

  String get initial => name.characters.first.toUpperCase();

  /// The store's own page for [query].
  String urlFor(String query) => search.replaceAll('{q}', Uri.encodeComponent(query.trim()));

  /// Whether [url] really belongs to this store (https, its own host).
  bool owns(String url) {
    final u = Uri.tryParse(url);
    if (u == null || u.scheme != 'https' || u.host.isEmpty) return false;
    final host = u.host.toLowerCase();
    return domains.any((d) => host == d || host.endsWith('.$d'));
  }
}

/// What can be compared, each with its own stores and its own form.
enum PriceCategory {
  shopping('Shopping', 'Amazon, Flipkart, Croma', Icons.shopping_bag_rounded, 0, 'Search a product or paste a link',
      'e.g. iPhone 16 128GB, boAt Airdopes 141'),
  flights('Flights', 'Airlines & booking sites', Icons.flight_takeoff_rounded, -58, 'From → To, and when',
      'e.g. Bengaluru to Delhi, 20 Nov'),
  hotels('Hotels', 'Rooms, ratings, amenities', Icons.hotel_rounded, 52, 'City or hotel, and dates',
      'e.g. Goa, 2 nights from 12 Dec'),
  cabs(
      'Cabs', 'Uber, Ola, Rapido', Icons.local_taxi_rounded, -86, 'From → To', 'e.g. Indiranagar to Bengaluru airport'),
  grocery('Grocery', 'Blinkit, Zepto, Instamart', Icons.local_grocery_store_rounded, 120, 'What do you need?',
      'e.g. Amul butter 500g, Aashirvaad atta 5kg');

  const PriceCategory(this.label, this.line, this.icon, this.hue, this.ask, this.example);

  /// What the app OFFERS (owner, 2026-11-14: flights, hotels, rides and
  /// grocery removed from Price compare). The other values stay so saved
  /// history and the server's prompts still parse.
  static const shown = [PriceCategory.shopping];

  final String label;
  final String line;
  final IconData icon;

  /// Degrees round the colour wheel from the accent (as the Try now
  /// cards), so the tiles belong to the page.
  final double hue;
  final String ask;
  final String example;

  List<PriceStore> get stores => switch (this) {
        shopping => PriceStores.shopping,
        flights => PriceStores.flights,
        hotels => PriceStores.hotels,
        cabs => PriceStores.cabs,
        grocery => PriceStores.grocery,
      };

  /// The tile's colour, from the accent.
  Color tint(Color accent) {
    final h = HSLColor.fromColor(accent);
    return h.withHue((h.hue + hue) % 360).withSaturation(0.8).withLightness(0.58).toColor();
  }

  /// The tile's photo (assets/pricecompare/, credited in [photoCredits]).
  String get photo => 'assets/pricecompare/$name.jpg';

  /// The tile's first line, BuyHatke-style: "Flight" over "Compare".
  String get tileTitle => switch (this) {
        shopping => 'Product',
        flights => 'Flight',
        hotels => 'Hotel',
        cabs => 'Ride',
        grocery => 'Grocery',
      };

  String get tileSubtitle => 'Compare';

  /// The ribbon over the tile, or '' for none. Cabs say BETA because their
  /// fares are estimates.
  String get tag => switch (this) {
        flights => 'HOT',
        hotels => 'NEW',
        cabs => 'BETA',
        _ => '',
      };

  static PriceCategory byName(String? name) =>
      PriceCategory.values.firstWhere((c) => c.name == name, orElse: () => shopping);
}

/// Who took the photos (Wikimedia Commons; the licences ask for credit).
const photoCredits = <(String, String, String)>[
  ('Flights', 'Julian Herzog', 'CC BY 4.0'),
  ('Hotels', 'Martin Falbisoner', 'CC BY-SA 4.0'),
  ('Rides', 'MB-one', 'CC BY-SA 4.0'),
  ('Shopping', 'Basile Morin', 'CC BY-SA 4.0'),
  ('Grocery', 'Wilfredor', 'CC BY-SA 4.0'),
];

abstract final class PriceStores {
  static const amazon = PriceStore('Amazon', Color(0xFFFF9900), 'https://www.amazon.in/s?k={q}',
      pkg: 'in.amazon.mShop.android.shopping', domains: ['amazon.in', 'amzn.in']);
  static const flipkart = PriceStore('Flipkart', Color(0xFF2874F0), 'https://www.flipkart.com/search?q={q}',
      pkg: 'com.flipkart.android', domains: ['flipkart.com', 'fkrt.it']);
  static const croma = PriceStore('Croma', Color(0xFF12DAA8), 'https://www.croma.com/searchB?q={q}',
      pkg: 'com.croma.store', domains: ['croma.com']);
  static const reliance = PriceStore(
      'Reliance Digital', Color(0xFFE42529), 'https://www.reliancedigital.in/search?q={q}',
      domains: ['reliancedigital.in']);

  static const blinkit = PriceStore('Blinkit', Color(0xFFF8CB46), 'https://blinkit.com/s/?q={q}',
      pkg: 'com.grofers.customerapp', domains: ['blinkit.com']);
  static const zepto = PriceStore('Zepto', Color(0xFF5E1EA0), 'https://www.zeptonow.com/search?query={q}',
      pkg: 'com.zeptoconsumerapp', domains: ['zeptonow.com', 'zepto.com']);
  static const instamart = PriceStore(
      'Instamart', Color(0xFFFC8019), 'https://www.swiggy.com/instamart/search?query={q}',
      pkg: 'in.swiggy.android', domains: ['swiggy.com']);
  static const bigbasket = PriceStore('BigBasket', Color(0xFF84C225), 'https://www.bigbasket.com/ps/?q={q}',
      pkg: 'com.bigbasket.mobileapp', domains: ['bigbasket.com']);

  static const makemytrip = PriceStore('MakeMyTrip', Color(0xFFE73C33), 'https://www.makemytrip.com/',
      pkg: 'com.makemytrip', domains: ['makemytrip.com']);
  static const goibibo = PriceStore('Goibibo', Color(0xFF2276E3), 'https://www.goibibo.com/',
      pkg: 'com.goibibo', domains: ['goibibo.com']);
  static const cleartrip = PriceStore('Cleartrip', Color(0xFFF77728), 'https://www.cleartrip.com/',
      pkg: 'com.cleartrip.android', domains: ['cleartrip.com']);
  static const ixigo =
      PriceStore('ixigo', Color(0xFFEC5B24), 'https://www.ixigo.com/', pkg: 'com.ixigo', domains: ['ixigo.com']);
  static const indigo = PriceStore('IndiGo', Color(0xFF1B1D6D), 'https://www.goindigo.in/',
      pkg: 'in.goindigo.android', domains: ['goindigo.in']);
  static const airIndia = PriceStore('Air India', Color(0xFFD7182A), 'https://www.airindia.com/',
      pkg: 'com.airindia.mobile', domains: ['airindia.com']);

  static const booking = PriceStore(
      'Booking.com', Color(0xFF003B95), 'https://www.booking.com/searchresults.html?ss={q}',
      pkg: 'com.booking', domains: ['booking.com']);
  static const agoda = PriceStore('Agoda', Color(0xFF5542F6), 'https://www.agoda.com/search?q={q}',
      pkg: 'com.agoda.mobile.consumer', domains: ['agoda.com']);
  static const oyo = PriceStore('OYO', Color(0xFFEE2A24), 'https://www.oyorooms.com/search?location={q}',
      pkg: 'com.oyo.consumer', domains: ['oyorooms.com']);

  static const uber =
      PriceStore('Uber', Color(0xFF000000), 'https://m.uber.com/', pkg: 'com.ubercab', domains: ['uber.com']);
  static const ola = PriceStore('Ola', Color(0xFF9ACD32), 'https://book.olacabs.com/',
      pkg: 'com.olacabs.customer', domains: ['olacabs.com']);
  static const rapido = PriceStore('Rapido', Color(0xFFF9C935), 'https://www.rapido.bike/',
      pkg: 'com.rapido.passenger', domains: ['rapido.bike']);

  static const shopping = [amazon, flipkart, croma, reliance];
  static const grocery = [blinkit, zepto, instamart, bigbasket];
  static const flights = [makemytrip, goibibo, cleartrip, ixigo, indigo, airIndia];
  static const hotels = [makemytrip, goibibo, booking, agoda, oyo];
  static const cabs = [uber, ola, rapido];

  /// The store in [among] called [name] ("amazon.in" and "Amazon India"
  /// are Amazon), else null.
  static PriceStore? named(String name, List<PriceStore> among) {
    final n = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (n.isEmpty) return null;
    for (final s in among) {
      final k = s.name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      if (n == k || n.startsWith(k) || k.startsWith(n)) return s;
    }
    return null;
  }
}

/// One store's price for the thing, as found on the web.
class PriceOffer {
  const PriceOffer({
    required this.store,
    required this.price,
    this.mrp,
    this.title = '',
    this.rating,
    this.note = '',
    this.url = '',
    this.inStock = true,
    this.info = const {},
  });

  final String store;
  final double price;
  final double? mrp;

  /// What exactly is priced (the variant, the flight, the room, the ride).
  final String title;
  final double? rating;
  final String note;

  /// The page the price was on, when it is really the store's.
  final String url;
  final bool inStock;

  /// What only this kind of comparison has (2026-11-07): a product's
  /// delivery date, seller, EMI and exchange; a hotel's stars, guest
  /// rating, area, room, amenities and cancellation; a ride's type, pickup
  /// time and surge; a grocery pack's size, price per kg/l and delivery.
  /// Read with [PriceInfo].
  final Map<String, Object?> info;

  int? get offPercent {
    final m = mrp;
    if (m == null || m <= price || m <= 0) return null;
    final p = ((m - price) / m * 100).round();
    return p > 0 && p < 100 ? p : null;
  }

  static PriceOffer? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final store = (raw['store'] ?? '').toString().trim();
    final price = _money(raw['price']);
    if (store.isEmpty || price == null || price <= 0) return null;
    final mrp = _money(raw['mrp']);
    final rating = _num(raw['rating']);
    return PriceOffer(
      store: store,
      price: price,
      mrp: mrp != null && mrp > price ? mrp : null,
      title: (raw['title'] ?? '').toString().trim(),
      rating: rating != null && rating > 0 && rating <= 5 ? rating : null,
      note: (raw['note'] ?? '').toString().trim(),
      url: (raw['url'] ?? '').toString().trim(),
      inStock: raw['inStock'] != false,
      info: raw['info'] is Map ? Map<String, Object?>.from(raw['info'] as Map) : const {},
    );
  }

  Map<String, Object?> toJson() => {
        'store': store,
        'price': price,
        if (mrp != null) 'mrp': mrp,
        if (title.isNotEmpty) 'title': title,
        if (rating != null) 'rating': rating,
        if (note.isNotEmpty) 'note': note,
        if (url.isNotEmpty) 'url': url,
        if (!inStock) 'inStock': false,
        if (info.isNotEmpty) 'info': info,
      };
}

/// Reading [PriceOffer.info] and [PriceResult.facts] safely: the model's
/// answer may leave anything out or give the wrong type.
extension PriceInfo on Map<String, Object?> {
  String str(String k) {
    final v = this[k];
    if (v == null || v is Map || v is List) return '';
    final t = '$v'.trim();
    return t == 'null' || t == '0' ? '' : t;
  }

  double? num(String k) {
    final v = _money(this[k]);
    return v != null && v > 0 ? v : null;
  }

  bool? flag(String k) {
    final v = this[k];
    if (v is bool) return v;
    if (v is String) {
      final t = v.toLowerCase();
      if (t == 'true' || t == 'yes') return true;
      if (t == 'false' || t == 'no') return false;
    }
    return null;
  }

  List<String> strs(String k, {int max = 8}) {
    final v = this[k];
    if (v is! List) return const [];
    return [
      for (final x in v)
        if (x is! Map && '$x'.trim().isNotEmpty) '$x'.trim()
    ].take(max).toList();
  }

  /// [{"name": .., "value": ..}] pairs (a product's specs).
  List<(String, String)> pairs(String k, {int max = 10}) {
    final v = this[k];
    if (v is! List) return const [];
    return [
      for (final x in v)
        if (x is Map && '${x['name'] ?? ''}'.trim().isNotEmpty && '${x['value'] ?? ''}'.trim().isNotEmpty)
          ('${x['name']}'.trim(), '${x['value']}'.trim()),
    ].take(max).toList();
  }
}

/// An offer, coupon or bank deal someone can actually use.
class PriceDeal {
  const PriceDeal({required this.store, required this.text, this.code = ''});
  final String store;
  final String text;
  final String code;

  static PriceDeal? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final text = (raw['text'] ?? '').toString().trim();
    if (text.isEmpty) return null;
    return PriceDeal(
      store: (raw['store'] ?? '').toString().trim(),
      text: text,
      code: (raw['code'] ?? '').toString().trim(),
    );
  }

  Map<String, Object?> toJson() => {'store': store, 'text': text, if (code.isNotEmpty) 'code': code};
}

/// "Buy now or wait", and why — the AI recommendation.
enum PriceVerdict {
  buy('Good time to buy'),
  wait('Better to wait'),
  okay('Fair price');

  const PriceVerdict(this.label);
  final String label;

  static PriceVerdict of(Object? v) => switch ('$v'.toLowerCase()) {
        'buy' || 'buy_now' || 'good' => buy,
        'wait' => wait,
        _ => okay,
      };
}

/// The price over time as the web reported it (a price tracker's page).
class PriceRange {
  const PriceRange({this.lowest, this.highest, this.average, this.note = ''});
  final double? lowest;
  final double? highest;
  final double? average;
  final String note;

  bool get isEmpty => lowest == null && highest == null && average == null;

  static PriceRange fromJson(Object? raw) {
    if (raw is! Map) return const PriceRange();
    return PriceRange(
      lowest: _positive(_money(raw['lowest'])),
      highest: _positive(_money(raw['highest'])),
      average: _positive(_money(raw['average'])),
      note: (raw['note'] ?? '').toString().trim(),
    );
  }

  Map<String, Object?> toJson() => {
        if (lowest != null) 'lowest': lowest,
        if (highest != null) 'highest': highest,
        if (average != null) 'average': average,
        if (note.isNotEmpty) 'note': note,
      };
}

/// One comparison: what was asked, every store's price, the verdict.
class PriceResult {
  const PriceResult({
    required this.category,
    required this.query,
    required this.product,
    required this.offers,
    this.verdict = PriceVerdict.okay,
    this.advice = '',
    this.bestPick = '',
    this.history = const PriceRange(),
    this.deals = const [],
    this.at,
    this.facts = const {},
  });

  final PriceCategory category;
  final String query;

  /// The thing's proper name, as the stores list it.
  final String product;

  /// Cheapest first.
  final List<PriceOffer> offers;
  final PriceVerdict verdict;
  final String advice;

  /// The store the recommendation picks (price, rating, budget together)
  /// — not always the cheapest.
  final String bestPick;
  final PriceRange history;
  final List<PriceDeal> deals;
  final DateTime? at;

  /// About the thing itself, by kind (read with [PriceInfo]): a product's
  /// brand, specs, highlights and rating; a hotel search's city, nights
  /// and guests; a ride's distance, time and traffic; a grocery item.
  final Map<String, Object?> facts;

  PriceOffer? get lowest => offers.isEmpty ? null : offers.first;
  PriceOffer? get highest => offers.isEmpty ? null : offers.last;

  /// How much the cheapest saves on the dearest.
  double get saving => offers.length < 2 ? 0 : offers.last.price - offers.first.price;

  /// The model's answer, read: the first JSON object in [text] (it may be
  /// fenced or have words around it). Null when there is no usable price.
  static PriceResult? parse(String text, {required PriceCategory category, required String query, DateTime? at}) {
    final j = _firstJson(text);
    if (j == null) return null;
    return fromJson(j, category: category, query: query, at: at);
  }

  static PriceResult? fromJson(Map j, {required PriceCategory category, required String query, DateTime? at}) {
    final offers = [
      for (final o in (j['offers'] as List?) ?? const [])
        if (PriceOffer.fromJson(o) case final offer?) offer,
    ]..sort((a, b) => a.price.compareTo(b.price));
    if (offers.isEmpty) return null;
    final product = (j['product'] ?? '').toString().trim();
    return PriceResult(
      category: category,
      query: query,
      product: product.isEmpty ? query : product,
      offers: offers,
      verdict: PriceVerdict.of(j['verdict']),
      advice: (j['advice'] ?? '').toString().trim(),
      bestPick: (j['bestPick'] ?? '').toString().trim(),
      history: PriceRange.fromJson(j['history']),
      deals: [
        for (final d in (j['deals'] as List?) ?? const [])
          if (PriceDeal.fromJson(d) case final deal?) deal,
      ].take(8).toList(),
      at: at ?? DateTime.tryParse('${j['at']}'),
      facts: j['facts'] is Map ? Map<String, Object?>.from(j['facts'] as Map) : const {},
    );
  }

  Map<String, Object?> toJson() => {
        'category': category.name,
        'query': query,
        'product': product,
        'offers': [for (final o in offers) o.toJson()],
        'verdict': verdict.name,
        'advice': advice,
        'bestPick': bestPick,
        'history': history.toJson(),
        'deals': [for (final d in deals) d.toJson()],
        if (at != null) 'at': at!.toIso8601String(),
        if (facts.isNotEmpty) 'facts': facts,
      };

  static PriceResult? restore(Map j) =>
      fromJson(j, category: PriceCategory.byName('${j['category']}'), query: '${j['query'] ?? ''}');
}

/// A price this phone saw on one of its own checks.
class PricePoint {
  const PricePoint(this.at, this.price);
  final DateTime at;
  final double price;

  Map<String, Object?> toJson() => {'at': at.toIso8601String(), 'price': price};
  static PricePoint? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final at = DateTime.tryParse('${raw['at']}');
    final p = _num(raw['price']);
    return at == null || p == null ? null : PricePoint(at, p);
  }
}

/// A price alert: tell me when [query] drops to [target] or below.
class PriceWatch {
  const PriceWatch({
    required this.id,
    required this.category,
    required this.query,
    required this.product,
    required this.target,
    this.points = const [],
    this.store = '',
    this.notified,
  });

  final String id;
  final PriceCategory category;
  final String query;
  final String product;
  final double target;

  /// Every lowest price seen, oldest first (the chart).
  final List<PricePoint> points;

  /// Where the last lowest price was.
  final String store;

  /// When the last drop alert went out (one per drop).
  final DateTime? notified;

  double? get last => points.isEmpty ? null : points.last.price;
  bool get reached => last != null && last! <= target;

  static String keyFor(PriceCategory c, String query) =>
      '${c.name}:${query.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ')}';

  PriceWatch copyWith({List<PricePoint>? points, String? store, DateTime? notified, double? target}) => PriceWatch(
        id: id,
        category: category,
        query: query,
        product: product,
        target: target ?? this.target,
        points: points ?? this.points,
        store: store ?? this.store,
        notified: notified ?? this.notified,
      );

  /// [p] added; a second check on the same day replaces that day's point,
  /// and only the last 90 are kept.
  PriceWatch withPoint(PricePoint p, {String store = ''}) {
    final pts = [...points];
    if (pts.isNotEmpty && _sameDay(pts.last.at, p.at)) pts.removeLast();
    pts.add(p);
    return copyWith(points: pts.length > 90 ? pts.sublist(pts.length - 90) : pts, store: store);
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'category': category.name,
        'query': query,
        'product': product,
        'target': target,
        'points': [for (final p in points) p.toJson()],
        'store': store,
        if (notified != null) 'notified': notified!.toIso8601String(),
      };

  static PriceWatch? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final query = '${raw['query'] ?? ''}'.trim();
    final target = _num(raw['target']);
    if (query.isEmpty || target == null) return null;
    final c = PriceCategory.byName('${raw['category']}');
    return PriceWatch(
      id: '${raw['id'] ?? keyFor(c, query)}',
      category: c,
      query: query,
      product: '${raw['product'] ?? query}',
      target: target,
      points: [
        for (final p in (raw['points'] as List?) ?? const [])
          if (PricePoint.fromJson(p) case final point?) point,
      ],
      store: '${raw['store'] ?? ''}',
      notified: DateTime.tryParse('${raw['notified']}'),
    );
  }
}

bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

double? _num(Object? v) {
  if (v is num) return v.isFinite ? v.toDouble() : null;
  if (v is String) return double.tryParse(v.trim());
  return null;
}

/// "₹1,29,999", "Rs. 499.00", 1299 → the number.
double? _money(Object? v) {
  if (v is num) return v.isFinite ? v.toDouble() : null;
  if (v is! String) return null;
  final m = RegExp(r'\d[\d,]*(?:\.\d+)?').firstMatch(v);
  return m == null ? null : double.tryParse(m.group(0)!.replaceAll(',', ''));
}

/// A price only when above zero (the answer's 0 means "unknown").
double? _positive(double? v) => v != null && v > 0 ? v : null;

Map? _firstJson(String text) {
  final start = text.indexOf('{');
  if (start < 0) return null;
  var depth = 0;
  var inString = false;
  var escaped = false;
  for (var i = start; i < text.length; i++) {
    final ch = text[i];
    if (inString) {
      if (escaped) {
        escaped = false;
      } else if (ch == r'\') {
        escaped = true;
      } else if (ch == '"') {
        inString = false;
      }
      continue;
    }
    if (ch == '"') {
      inString = true;
    } else if (ch == '{') {
      depth++;
    } else if (ch == '}') {
      depth--;
      if (depth == 0) {
        try {
          final v = jsonDecode(text.substring(start, i + 1));
          return v is Map ? v : null;
        } catch (_) {
          return null;
        }
      }
    }
  }
  return null;
}

/// "₹1,29,999" — Indian grouping, no paise unless there are some.
String rupees(double v) {
  final whole = v.truncate();
  final paise = ((v - whole) * 100).round();
  final s = whole.abs().toString();
  String grouped;
  if (s.length <= 3) {
    grouped = s;
  } else {
    final last3 = s.substring(s.length - 3);
    var rest = s.substring(0, s.length - 3);
    final parts = <String>[];
    while (rest.length > 2) {
      parts.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) parts.insert(0, rest);
    grouped = '${parts.join(',')},$last3';
  }
  final sign = v < 0 ? '-' : '';
  return paise > 0 && paise < 100 ? '$sign₹$grouped.${paise.toString().padLeft(2, '0')}' : '$sign₹$grouped';
}

/// The first JSON object in a model's answer (fenced or with words
/// around it), for parsers outside this file.
Map? firstJsonObject(String text) => _firstJson(text);

/// A price from an answer: a number, or "₹5,021"-style text.
double? moneyOf(Object? v) => _money(v);

/// One product in a search's results grid (2026-11-07): what the web
/// lists for the words searched, before one is opened and compared.
class ProductHit {
  const ProductHit({
    required this.name,
    required this.price,
    required this.store,
    this.mrp,
    this.image = '',
    this.rating,
    this.reviews,
    this.url = '',
  });

  final String name;
  final double price;
  final double? mrp;
  final String store;
  final String image;
  final double? rating;
  final double? reviews;
  final String url;

  int? get offPercent {
    final m = mrp;
    if (m == null || m <= price) return null;
    final p = ((m - price) / m * 100).round();
    return p > 0 && p < 100 ? p : null;
  }

  static ProductHit? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final name = '${raw['name'] ?? ''}'.trim();
    final price = _money(raw['price']);
    final store = '${raw['store'] ?? ''}'.trim();
    if (name.isEmpty || price == null || price <= 0 || store.isEmpty) return null;
    final mrp = _money(raw['mrp']);
    final rating = _num(raw['rating']);
    final image = '${raw['image'] ?? ''}'.trim();
    final url = '${raw['url'] ?? ''}'.trim();
    return ProductHit(
      name: name,
      price: price,
      store: store,
      mrp: mrp != null && mrp > price ? mrp : null,
      image: image.startsWith('https://') ? image : '',
      rating: rating != null && rating > 0 && rating <= 5 ? rating : null,
      reviews: _positive(_money(raw['reviews'])),
      url: url.startsWith('https://') ? url : '',
    );
  }

  /// The answer's "products" list, in its order; empty when unreadable.
  static List<ProductHit> listFrom(String text) {
    final j = _firstJson(text);
    if (j == null) return const [];
    return [
      for (final p in (j['products'] as List?) ?? const [])
        if (ProductHit.fromJson(p) case final h?) h,
    ].take(20).toList();
  }
}
