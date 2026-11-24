import '../../services/api_service.dart';

/// ─────────────────────────────────────────────────────────────────────────
///  HOTEL PRICES (2026-11-24): real Google Hotels results through our server
///  (GET /hotels/search). Never invented: a hotel with no price is dropped;
///  a server without hotel search says so and the screen keeps opening the
///  booking sites.
/// ─────────────────────────────────────────────────────────────────────────
class HotelSite {
  const HotelSite(this.source, this.pricePerNight);
  final String source;
  final double pricePerNight;
}

class HotelHit {
  const HotelHit({
    required this.name,
    required this.pricePerNight,
    this.type = '',
    this.stars,
    this.rating,
    this.reviews,
    this.total,
    this.image = '',
    this.link = '',
    this.amenities = const [],
    this.sites = const [],
  });

  final String name;
  final String type;
  final int? stars;
  final double? rating;
  final int? reviews;
  final double pricePerNight;

  /// For the whole stay, when Google gave it.
  final double? total;
  final String image;

  /// The hotel's own page or Google's; '' when there is none.
  final String link;
  final List<String> amenities;

  /// Booking sites' prices per night, cheapest first.
  final List<HotelSite> sites;

  /// The cheapest site's name, or ''.
  String get cheapestSite => sites.isEmpty ? '' : sites.first.source;

  static double? _num(Object? v) => v is num && v > 0 ? v.toDouble() : null;

  static HotelHit? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final name = '${raw['name'] ?? ''}'.trim();
    final night = _num(raw['pricePerNight']);
    if (name.isEmpty || night == null) return null;
    String https(Object? v) => '${v ?? ''}'.startsWith('https://') ? '$v' : '';
    return HotelHit(
      name: name,
      type: '${raw['type'] ?? ''}'.trim(),
      stars: _num(raw['stars'])?.round().clamp(1, 5),
      rating: _num(raw['rating']),
      reviews: _num(raw['reviews'])?.round(),
      pricePerNight: night,
      total: _num(raw['total']),
      image: https(raw['image']),
      link: https(raw['link']),
      amenities: [for (final a in (raw['amenities'] as List?) ?? const []) '$a'],
      sites: [
        for (final s in (raw['sites'] as List?) ?? const [])
          if (s is Map && '${s['source'] ?? ''}'.trim().isNotEmpty && _num(s['pricePerNight']) != null)
            HotelSite('${s['source']}'.trim(), _num(s['pricePerNight'])!),
      ]..sort((a, b) => a.pricePerNight.compareTo(b.pricePerNight)),
    );
  }

  /// The server's answer: hotels cheapest first, or null when it has no
  /// hotel search (then [HotelPrices.unavailable] says why).
  static List<HotelHit>? listFrom(Map<String, dynamic>? j) {
    if (j == null || j['ok'] != true) return null;
    return [
      for (final h in (j['hotels'] as List?) ?? const [])
        if (fromJson(h) case final hit?) hit,
    ]..sort((a, b) => a.pricePerNight.compareTo(b.pricePerNight));
  }
}

/// The server's hotel search.
abstract final class HotelPrices {
  /// Test seam.
  static Future<Map<String, dynamic>?> Function(String path)? fetch;

  /// Hotels for the stay, or null with [error] set.
  static Future<({List<HotelHit>? hotels, String error})> search(
      {required String place, required String checkIn, required String checkOut, required int adults}) async {
    final path = Uri(path: '/hotels/search', queryParameters: {
      'q': place,
      'checkIn': checkIn,
      'checkOut': checkOut,
      'adults': '$adults',
    }).toString();
    final j = await (fetch ?? (p) => ApiService.getJson(p, timeout: const Duration(seconds: 30)))(path);
    final hotels = HotelHit.listFrom(j);
    if (hotels != null) return (hotels: hotels, error: '');
    if (j?['configured'] == false) {
      return (hotels: null, error: 'Live hotel prices are not available yet. Search on a site below.');
    }
    final e = '${j?['error'] ?? ''}'.trim();
    return (hotels: null, error: e.isNotEmpty ? e : 'Unable to load hotel prices. Check your internet connection and try again.');
  }
}
