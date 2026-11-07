import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../ai/cloud.dart';
import '../../ai/config.dart';
import '../../ai/model_port.dart';
import '../../ai/search_suggestions.dart';
import '../../ai/types.dart';
import '../../core/log.dart';
import '../../services/notification_service.dart';
import 'flight_fares.dart';
import 'flight_trip.dart';
import 'price_models.dart';

/// A comparison with what the grounding terms require beside it: the
/// pages the prices came from and Google's search suggestions.
class PriceAnswer {
  const PriceAnswer(this.result, {this.sources = const [], this.suggestions = const []});
  final PriceResult result;
  final List<SourceLink> sources;
  final List<SearchSuggestion> suggestions;
}

/// A flight search: the flights with every site's fare, the same as a
/// plain comparison ([result], for alerts), and the grounding beside it.
class FlightAnswer {
  const FlightAnswer(this.fares, this.result, {this.sources = const [], this.suggestions = const []});
  final FlightFares fares;
  final PriceResult result;
  final List<SourceLink> sources;
  final List<SearchSuggestion> suggestions;
}

class PriceCompareException implements Exception {
  const PriceCompareException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// ─────────────────────────────────────────────────────────────────────────
///  THE PRICE LOOK-UP: one Google-Search-grounded Gemini answer (the same
///  engine as the assistant's web answers, lib/ai/cloud.dart), asked for
///  JSON only. Recent comparisons and price alerts are kept on the phone.
///
///  ALERTS are checked when Price Compare opens (at most a few, once a day
///  each): a lowest price at or under the target sends one notification
///  per drop. There is no server watching prices, and the screen says so.
/// ─────────────────────────────────────────────────────────────────────────
class PriceService extends ChangeNotifier {
  PriceService._();
  static final PriceService instance = PriceService._();

  static const _recentKey = 'price_compare.recent.v1';
  static const _watchKey = 'price_compare.watches.v1';
  static const _maxRecent = 8;

  /// The look-up itself; replaced in tests.
  @visibleForTesting
  Future<({String text, List<SourceLink> sources, String? suggestionsHtml})> Function(String prompt)? ask;

  final List<PriceResult> _recent = [];
  final Map<String, PriceWatch> _watches = {};
  bool _loaded = false;

  List<PriceResult> get recent => List.unmodifiable(_recent);
  List<PriceWatch> get watches => _watches.values.toList()..sort((a, b) => a.product.compareTo(b.product));
  PriceWatch? watchFor(PriceCategory c, String query) => _watches[PriceWatch.keyFor(c, query)];

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final r = jsonDecode(prefs.getString(_recentKey) ?? '[]');
      if (r is List) {
        _recent
          ..clear()
          ..addAll([
            for (final e in r)
              if (e is Map)
                if (PriceResult.restore(e) case final x?) x,
          ]);
      }
      final w = jsonDecode(prefs.getString(_watchKey) ?? '[]');
      if (w is List) {
        _watches.clear();
        for (final e in w) {
          if (PriceWatch.fromJson(e) case final x?) _watches[x.id] = x;
        }
      }
    } catch (e) {
      AppLog.add('price', 'load failed: $e');
    }
    notifyListeners();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_recentKey, jsonEncode([for (final r in _recent) r.toJson()]));
      await prefs.setString(_watchKey, jsonEncode([for (final w in _watches.values) w.toJson()]));
    } catch (e) {
      AppLog.add('price', 'save failed: $e');
    }
  }

  /// Compares [query] in [category]; [budget] steers the recommendation.
  Future<PriceAnswer> compare(PriceCategory category, String query, {double? budget}) async {
    await load();
    final q = query.trim();
    if (q.isEmpty) throw const PriceCompareException('Type what to compare first.');
    final prompt = promptFor(category, q, budget: budget, now: DateTime.now());
    final ({String text, List<SourceLink> sources, String? suggestionsHtml}) out;
    try {
      out = await (ask ?? _askGemini)(prompt);
    } on TimeoutException {
      throw const PriceCompareException('That took too long. Check your connection and try again.');
    } catch (e) {
      AppLog.add('price', 'look-up failed: $e');
      throw const PriceCompareException("Couldn't reach the price search. Check your connection and try again.");
    }
    final result = PriceResult.parse(out.text, category: category, query: q, at: DateTime.now());
    if (result == null) {
      throw const PriceCompareException("Couldn't find current prices for that. Try a more exact name.");
    }
    _remember(result);
    unawaited(_save());
    notifyListeners();
    return PriceAnswer(result, sources: out.sources, suggestions: parseSearchSuggestions(out.suggestionsHtml));
  }

  /// THE RESULTS GRID for a product search: up to 12 matching products
  /// on the stores we cover, with photo, price, rating and store.
  Future<List<ProductHit>> searchProducts(String query) async {
    final q = query.trim();
    if (q.isEmpty) throw const PriceCompareException('Type what to search for first.');
    final stores = PriceStores.shopping.map((s) => s.name).join(', ');
    final now = DateTime.now();
    final prompt =
        """Today is ${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}.
A shopper in India searches for "$q". Use Google Search to find up to 12 matching products on $stores (and other big Indian stores) with their current prices — different models and variants, most popular first. Each one as listed on one store.

Answer with ONLY this JSON (no markdown):
{"products": [{"name": "full product name with variant", "price": 0, "mrp": 0, "store": "store name", "rating": 4.5, "reviews": 2850, "image": "an https product photo URL from the store or brand, or empty", "url": "the store's https product page, or empty"}]}
Prices are numbers in rupees. Leave out mrp, rating, reviews, image or url you could not find — never guess them.""";
    final ({String text, List<SourceLink> sources, String? suggestionsHtml}) out;
    try {
      out = await (ask ?? _askGemini)(prompt);
    } on TimeoutException {
      throw const PriceCompareException('That took too long. Check your connection and try again.');
    } catch (e) {
      AppLog.add('price', 'product search failed: $e');
      throw const PriceCompareException("Couldn't reach the price search. Check your connection and try again.");
    }
    var hits = ProductHit.listFrom(out.text);
    if (hits.isEmpty) {
      final raw = out.text.replaceAll(RegExp(r'\s+'), ' ');
      AppLog.add(
          'price',
          'product search had no products (${raw.length} chars): '
              '${raw.substring(0, raw.length < 400 ? raw.length : 400)}');
      // The plain comparison finds prices far more often: each store's
      // listing becomes a card.
      try {
        final a = await compare(PriceCategory.shopping, q);
        final r = a.result;
        final photo = r.facts.str('image');
        hits = [
          for (final o in r.offers)
            ProductHit(
              name: o.title.isNotEmpty ? o.title : r.product,
              price: o.price,
              mrp: o.mrp,
              store: o.store,
              image: o.info.str('image').isNotEmpty ? o.info.str('image') : photo,
              rating: o.rating ?? r.facts.num('rating'),
              reviews: r.facts.num('reviews'),
              url: o.url,
            ),
        ];
      } catch (e) {
        AppLog.add('price', 'product search fallback failed: $e');
      }
    }
    if (hits.isEmpty) throw const PriceCompareException("Couldn't find products for that. Try other words.");
    return hits;
  }

  /// A one-way trip's flights, one row per flight with every site's fare
  /// (the travel-app results list). Remembered as a plain comparison too,
  /// so alerts and Recently compared see it.
  Future<FlightAnswer> compareFlights(FlightTrip trip) async {
    await load();
    final query = trip.describe();
    final prompt = flightPromptFor(trip, now: DateTime.now());
    final ({String text, List<SourceLink> sources, String? suggestionsHtml}) out;
    try {
      out = await (ask ?? _askGemini)(prompt);
    } on TimeoutException {
      throw const PriceCompareException('That took too long. Check your connection and try again.');
    } catch (e) {
      AppLog.add('price', 'flight look-up failed: $e');
      throw const PriceCompareException("Couldn't reach the fare search. Check your connection and try again.");
    }
    var fares = FlightFares.parse(out.text);
    var sources = out.sources;
    var suggestionsHtml = out.suggestionsHtml;
    if (fares == null) {
      final raw = out.text.replaceAll(RegExp(r'\s+'), ' ');
      AppLog.add('price',
          'flight answer had no usable flights (${raw.length} chars): ${raw.substring(0, raw.length < 400 ? raw.length : 400)}');
      // The plain comparison (one price per site) finds fares far more
      // often; its offers become one card per flight.
      try {
        final plain = await (ask ?? _askGemini)(promptFor(PriceCategory.flights, query, now: DateTime.now()));
        final r = PriceResult.parse(plain.text, category: PriceCategory.flights, query: query);
        if (r != null) {
          fares = FlightFares.fromOffers(r);
          sources = plain.sources;
          suggestionsHtml = plain.suggestionsHtml;
        } else {
          AppLog.add('price', 'plain flight compare had no prices either');
        }
      } catch (e) {
        AppLog.add('price', 'plain flight compare failed: $e');
      }
    }
    if (fares == null) {
      throw const PriceCompareException(
          "No fares found for this flight right now. Try another date, or pull down to search again.");
    }
    final l = trip.legs.first;
    final result = fares.toResult(
        query: query, product: '${l.from!.city} → ${l.to!.city}, ${fullDate(l.date!)}', at: DateTime.now());
    _remember(result);
    unawaited(_save());
    notifyListeners();
    return FlightAnswer(fares, result, sources: sources, suggestions: parseSearchSuggestions(suggestionsHtml));
  }

  @visibleForTesting
  static String flightPromptFor(FlightTrip trip, {required DateTime now}) {
    String iso(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final l = trip.legs.first;
    final stores = PriceStores.flights.map((s) => s.name).join(', ');
    return '''Today is ${iso(now)}.
List the flights for this trip with their current fares: ${trip.describe()}
Use Google Search now (e.g. "${l.from!.city} to ${l.to!.city} flights ${fullDate(l.date!)}") and read Google Flights, the airline sites and the booking sites ($stores). List the flights from ${l.from!.code} to ${l.to!.code} on ${iso(l.date!)} that you find — up to 10; even one or two is useful. A flight needs only its airline and one fare you saw; give the flight number, times, duration and more sites' fares (up to 4, cheapest first) when the page shows them, otherwise leave those empty. Keep it compact: no extra fields, no comments. "price" is the TOTAL for all travellers, for the class asked, in rupees. Respect non-stop only and the special fare when asked.
Also give "nearbyDates": the lowest fare for this route on each of the 3 days before and the 3 days after ${iso(l.date!)} — only days whose fare you actually found (a fare calendar is fine); leave the others out.

Answer with ONLY this JSON (no markdown):
{
  "flights": [{"airline": "IndiGo", "flightNo": "6E 2134", "from": "${l.from!.code}", "to": "${l.to!.code}", "depart": "HH:MM", "arrive": "HH:MM", "arriveDayOffset": 0, "durationMin": 0, "stops": 0, "via": [], "fares": [{"store": "booking site or airline", "price": 0, "url": "that site's own https page for it, or empty"}]}],
  "nearbyDates": [{"date": "YYYY-MM-DD", "lowest": 0}],
  "advice": "one or two plain sentences: the best pick and whether to book now or wait",
  "deals": [{"store": "", "text": "a bank offer or coupon you actually found", "code": "coupon code if any"}]
}
Times are local 24-hour times; always give both depart and arrive and the duration when the listing shows them. Never invent a flight, a time or a fare; leave out what you could not find.''';
  }

  /// THE AI'S PICK among products the user has open in the shop browser
  /// (one or more: name, price seen, store), with what is good and bad
  /// about each and better buys worth a look, checked on the web.
  Future<ProductAdvice> recommend(List<({String name, double? price, String store})> products) async {
    if (products.isEmpty) throw const PriceCompareException('Open a product first.');
    final list = [
      for (final (i, p) in products.indexed)
        '${i + 1}. ${p.name}${p.price == null ? '' : ' — ${rupees(p.price!)}'} on ${p.store}',
    ].join('\n');
    final now = DateTime.now();
    final prompt =
        '''Today is ${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}.
A shopper in India has these products open:
$list

Use Google Search for current reviews, specs and prices in India. ${products.length > 1 ? 'Recommend which ONE of them to buy.' : 'Say whether this is a good buy at this price.'} Then name up to 3 alternatives worth considering (other models or a better price elsewhere), only ones you actually found.

Answer with ONLY this JSON (no markdown):
{
  "verdict": "one short headline, e.g. Buy the Galaxy S24 — better camera for ₹4,000 less",
  "pick": 1,
  "why": "two or three plain sentences",
  "items": [{"name": "short name", "good": ["up to 3 short points"], "bad": ["up to 2 short points"], "score": 8}],
  "alternatives": [{"name": "", "price": 0, "why": "one short line"}]
}
"pick" is the number of the product to buy (1 if only one). "items" follows the order above; "score" is out of 10. Never invent a price or a spec.''';
    final ({String text, List<SourceLink> sources, String? suggestionsHtml}) out;
    try {
      out = await (ask ?? _askGemini)(prompt);
    } on TimeoutException {
      throw const PriceCompareException('That took too long. Try again.');
    } catch (e) {
      AppLog.add('price', 'recommend failed: $e');
      throw const PriceCompareException("Couldn't reach the AI. Check your connection and try again.");
    }
    final a = ProductAdvice.parse(out.text, count: products.length);
    if (a == null) throw const PriceCompareException("The AI couldn't decide on these. Try again.");
    return a.withSources(out.sources, parseSearchSuggestions(out.suggestionsHtml));
  }

  void _remember(PriceResult r) {
    _recent.removeWhere((x) => x.category == r.category && x.query.toLowerCase() == r.query.toLowerCase());
    _recent.insert(0, r);
    if (_recent.length > _maxRecent) _recent.removeRange(_maxRecent, _recent.length);
    final key = PriceWatch.keyFor(r.category, r.query);
    final w = _watches[key];
    final low = r.lowest;
    if (w != null && low != null) {
      _watches[key] = w.withPoint(PricePoint(r.at ?? DateTime.now(), low.price), store: low.store);
    }
  }

  void clearRecent() {
    _recent.clear();
    unawaited(_save());
    notifyListeners();
  }

  /// Starts (or changes) an alert for [r] at [target].
  void watch(PriceResult r, double target) {
    final key = PriceWatch.keyFor(r.category, r.query);
    final low = r.lowest;
    final old = _watches[key];
    _watches[key] =
        (old ?? PriceWatch(id: key, category: r.category, query: r.query, product: r.product, target: target))
            .copyWith(target: target);
    if (old == null && low != null) {
      _watches[key] = _watches[key]!.withPoint(PricePoint(r.at ?? DateTime.now(), low.price), store: low.store);
    }
    unawaited(_save());
    notifyListeners();
  }

  void unwatch(String id) {
    _watches.remove(id);
    unawaited(_save());
    notifyListeners();
  }

  bool _checking = false;

  /// Re-checks up to [max] alerts not checked today; a price at or under
  /// its target notifies once per drop.
  Future<void> checkWatches({int max = 3}) async {
    await load();
    if (_checking) return;
    _checking = true;
    try {
      final now = DateTime.now();
      final due = [
        for (final w in _watches.values)
          if (w.points.isEmpty || now.difference(w.points.last.at) > const Duration(hours: 20)) w,
      ].take(max);
      for (final w in due) {
        try {
          final before = w.last;
          final a = await compare(w.category, w.query);
          final low = a.result.lowest;
          final fresh = _watches[w.id];
          if (low == null || fresh == null) continue;
          final dropped =
              low.price <= fresh.target && (before == null || before > fresh.target || fresh.notified == null);
          if (dropped) {
            _watches[w.id] = fresh.copyWith(notified: now);
            await ReminderNotifications.instance.showNow(
              'Price drop: ${fresh.product}',
              '${rupees(low.price)} on ${low.store} — at or under your ${rupees(fresh.target)} alert.',
            );
          }
        } catch (e) {
          AppLog.add('price', 'alert check failed: $e');
        }
      }
      unawaited(_save());
      notifyListeners();
    } finally {
      _checking = false;
    }
  }

  Future<({String text, List<SourceLink> sources, String? suggestionsHtml})> _askGemini(String prompt) async {
    final config = await AiConfigStore.instance.get();
    final engine = CloudEngine(ModelPorts.cloud());
    Future<CloudFinished> run(String model) async {
      CloudFinished? done;
      await for (final e in engine.search(CloudRequest(
        model: model,
        text: prompt,
        system: _system,
        roundTimeout: const Duration(seconds: 60),
        firstTimeout: const Duration(seconds: 30),
      ))) {
        if (e is CloudFinished) done = e;
      }
      return done ?? const CloudFinished(text: '');
    }

    CloudFinished f;
    try {
      f = await run(config.models.cloud);
    } catch (e) {
      AppLog.add('price', '${config.models.cloud} failed ($e); trying ${config.models.cloudFallback}');
      f = await run(config.models.cloudFallback);
    }
    return (text: f.text, sources: f.sources, suggestionsHtml: f.searchSuggestionsHtml);
  }

  static const _system = 'You are a careful price-comparison researcher for shoppers in India. '
      'Use Google Search to find CURRENT prices in Indian rupees. Report only prices you actually '
      'found on the web today; never invent a price, a coupon or a discount. If a store has no '
      'listing you can find, leave it out. Answer with ONE JSON object and nothing else.';

  /// The question for [category]: what to find and the JSON to answer in.
  @visibleForTesting
  static String promptFor(PriceCategory category, String query, {double? budget, required DateTime now}) {
    final stores = category.stores.map((s) => s.name).join(', ');
    final today = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final what = switch (category) {
      PriceCategory.shopping =>
        'Compare the current selling price of "$query" on $stores (and any other big Indian store you find). '
            'If it is a product link, identify the product first. Use the same variant everywhere.',
      PriceCategory.grocery =>
        'Compare the current price of "$query" on the quick-commerce apps $stores. Same pack size everywhere.',
      PriceCategory.flights =>
        'Find the cheapest fares for this trip: $query Compare airlines (IndiGo, Air India, Akasa, SpiceJet…) '
            'and booking sites ($stores). "price" is the TOTAL for all travellers and every flight of the trip, '
            'for the class asked. Put the airline, flight times and stops in each offer\'s title (for a return '
            'or multi-city trip, every flight). "store" is where to book it. Respect non-stop only and the '
            'special fare when asked.',
      PriceCategory.hotels =>
        'Compare hotel room prices for: $query, on $stores. Find 4–8 good hotels; each offer is one hotel on one '
            'site ("price" is per night). Put the hotel name in the title and its guest rating out of 5 in "rating". '
            'If no dates are given, use the coming weekend for 1 night, 2 adults, and say so in facts.',
      PriceCategory.cabs =>
        'Estimate the current fare for a ride: $query, on $stores (bike, auto, mini, sedan and SUV where offered). '
            'One offer per app and ride type; put the ride type in the title. These are estimates — say so in the '
            'advice.',
    };
    // What only this kind has, per offer ("info") and about the thing ("facts").
    final (info, facts) = switch (category) {
      PriceCategory.shopping => (
          '{"delivery": "e.g. Tomorrow / by 12 Nov", "seller": "", "emi": "e.g. No-cost EMI from ₹3,333/mo", '
              '"exchange": "e.g. Up to ₹8,000 off on exchange", "warranty": "e.g. 1 year brand warranty", '
              '"image": "that store\'s https photo of it, or empty"}',
          '{"brand": "", "rating": 4.5, "reviews": 12000, "highlights": ["up to 4 short selling points"], '
              '"specs": [{"name": "Display", "value": "6.1-inch OLED"}], "image": "an https product photo URL or empty", '
              '"images": ["up to 4 more https photos of it"], '
              '"similar": [{"name": "", "price": 0, "mrp": 0, "store": "", "rating": 4.4, "reviews": 0, "image": "", "url": ""}]}'
              ' — up to 8 key specs that matter for this kind of product; "similar" is up to 6 good deals on '
              'similar products in the same category and budget'
        ),
      PriceCategory.grocery => (
          '{"pack": "e.g. 500 g", "unitPrice": 0, "unit": "kg | l | piece", "deliveryMin": 10, "deliveryFee": 0}'
              ' — unitPrice is the price per kg / litre / piece',
          '{"item": "the item and pack compared", "brand": "", "tip": "one short saving tip, e.g. the bigger pack is cheaper per kg"}'
        ),
      PriceCategory.hotels => (
          '{"hotel": "", "stars": 4, "reviews": 1200, "area": "the locality", "distance": "e.g. 400 m from the beach", '
              '"room": "room type", "freeCancellation": true, "breakfast": false, "amenities": ["Pool", "Free Wi-Fi"], '
              '"total": 0}  — total is for the whole stay',
          '{"city": "", "checkIn": "e.g. Sat 15 Nov", "checkOut": "", "nights": 1, "guests": 2, "averagePerNight": 0}'
        ),
      PriceCategory.cabs => (
          '{"ride": "Bike | Auto | Mini | Sedan | SUV | Premium", "pickupMin": 4, "seats": 4, "surge": false}',
          '{"from": "", "to": "", "distanceKm": 0, "durationMin": 0, "traffic": "light | moderate | heavy"}'
        ),
      PriceCategory.flights => ('{}', '{}'),
    };
    final budgetLine =
        budget == null ? '' : '\nThe user\'s budget is ${rupees(budget)}: weigh it in bestPick and advice.';
    return '''Today is $today.
$what$budgetLine

Answer with ONLY this JSON (no markdown):
{
  "product": "the exact name of what was priced",
  "offers": [{"store": "store or app name", "price": 0, "mrp": 0, "title": "variant / flight / room / ride", "rating": 0, "note": "short", "url": "the store's own https page for it, or empty", "inStock": true, "info": $info}],
  "facts": $facts,
  "bestPick": "the store you recommend — weighing price, rating and the budget",
  "verdict": "buy | wait | okay",
  "advice": "one or two plain sentences: why that pick, and whether to buy now or wait",
  "history": {"lowest": 0, "highest": 0, "average": 0, "note": "where that history comes from, e.g. a price tracker; leave the numbers out if unknown"},
  "deals": [{"store": "", "text": "a bank offer, coupon or sale you actually found", "code": "coupon code if any"}]
}
Leave out mrp, rating, history numbers, deals, info or facts you could not find — never guess them. Prices are numbers in rupees.''';
  }
}

/// What the AI recommends among the products open in the shop browser.
class ProductAdvice {
  const ProductAdvice({
    required this.verdict,
    required this.pick,
    this.why = '',
    this.items = const [],
    this.alternatives = const [],
    this.sources = const [],
    this.suggestions = const [],
  });

  final String verdict;

  /// Index (from 0) of the product to buy.
  final int pick;
  final String why;
  final List<({String name, List<String> good, List<String> bad, int? score})> items;
  final List<({String name, double? price, String why})> alternatives;
  final List<SourceLink> sources;
  final List<SearchSuggestion> suggestions;

  ProductAdvice withSources(List<SourceLink> s, List<SearchSuggestion> g) => ProductAdvice(
      verdict: verdict, pick: pick, why: why, items: items, alternatives: alternatives, sources: s, suggestions: g);

  static ProductAdvice? parse(String text, {required int count}) {
    final j = firstJsonObject(text);
    if (j == null) return null;
    final verdict = '${j['verdict'] ?? ''}'.trim();
    if (verdict.isEmpty) return null;
    List<String> strs(Object? v) =>
        [for (final x in (v is List ? v : const [])) '$x'.trim()].where((s) => s.isNotEmpty).take(3).toList();
    final pick = (j['pick'] is num ? (j['pick'] as num).round() : 1) - 1;
    return ProductAdvice(
      verdict: verdict,
      pick: pick.clamp(0, count - 1),
      why: '${j['why'] ?? ''}'.trim(),
      items: [
        for (final i in (j['items'] as List?) ?? const [])
          if (i is Map)
            (
              name: '${i['name'] ?? ''}'.trim(),
              good: strs(i['good']),
              bad: strs(i['bad']),
              score: i['score'] is num ? (i['score'] as num).round().clamp(0, 10) : null,
            ),
      ].take(count).toList(),
      alternatives: [
        for (final a in (j['alternatives'] as List?) ?? const [])
          if (a is Map && '${a['name'] ?? ''}'.trim().isNotEmpty)
            (name: '${a['name']}'.trim(), price: moneyOf(a['price']), why: '${a['why'] ?? ''}'.trim()),
      ].take(3).toList(),
    );
  }
}
