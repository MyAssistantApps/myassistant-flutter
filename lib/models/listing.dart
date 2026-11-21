/// ─────────────────────────────────────────────────────────────────────────
///  LISTINGS — a doctor's / advocate's / business's public page, and what
///  other users see when they look for professionals nearby (backend
///  src/listings). Every parser tolerates missing fields: an older server
///  simply has none of this, and the screens say so instead of crashing.
/// ─────────────────────────────────────────────────────────────────────────
library;

double? _d(Object? v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}');
String _s(Object? v) => v == null ? '' : '$v';

class MyListing {
  MyListing({
    required this.slug,
    required this.persona,
    required this.displayName,
    required this.headline,
    required this.placeName,
    required this.address,
    required this.area,
    required this.city,
    required this.pincode,
    required this.lat,
    required this.lng,
    required this.phone,
    required this.whatsapp,
    required this.about,
    required this.services,
    required this.languages,
    required this.acceptsRequests,
    required this.published,
    required this.hasPhoto,
    required this.views,
    required this.draft,
    this.updatedAt,
  });

  final String? slug;
  final String persona;
  final String displayName;
  final String headline;
  final String placeName;
  final String address;
  final String area;
  final String city;
  final String pincode;
  final double? lat;
  final double? lng;
  final String phone;
  final String whatsapp;
  final String about;
  final List<String> services;
  final String languages;
  final bool acceptsRequests;
  final bool published;
  final bool hasPhoto;
  final int views;
  final bool draft;
  final int? updatedAt;

  bool get hasPin => lat != null && lng != null;

  factory MyListing.fromJson(Map<String, dynamic> j) => MyListing(
        slug: j['slug'] as String?,
        persona: _s(j['persona']),
        displayName: _s(j['displayName']),
        headline: _s(j['headline']),
        placeName: _s(j['placeName']),
        address: _s(j['address']),
        area: _s(j['area']),
        city: _s(j['city']),
        pincode: _s(j['pincode']),
        lat: _d(j['lat']),
        lng: _d(j['lng']),
        phone: _s(j['phone']),
        whatsapp: _s(j['whatsapp']),
        about: _s(j['about']),
        services: [for (final s in (j['services'] as List? ?? const [])) '$s'],
        languages: _s(j['languages']),
        acceptsRequests: j['acceptsRequests'] != false,
        published: j['published'] == true,
        hasPhoto: j['hasPhoto'] == true,
        views: (j['views'] as num?)?.toInt() ?? 0,
        draft: j['draft'] == true,
        updatedAt: (j['updatedAt'] as num?)?.toInt(),
      );
}

/// GET /listing: the listing plus everything the screen shows around it.
class ListingState {
  ListingState({
    required this.listing,
    required this.url,
    required this.missing,
    required this.postKinds,
    required this.newRequests,
    required this.regNo,
    required this.hours,
  });

  final MyListing listing;
  final String? url;
  final List<String> missing;
  final List<String> postKinds;
  final int newRequests;
  final String regNo;
  final String hours;

  bool get canPost => postKinds.isNotEmpty;
  bool get ready => missing.isEmpty;

  factory ListingState.fromJson(Map<String, dynamic> j) {
    final clinic = (j['clinic'] as Map?)?.cast<String, dynamic>() ?? const {};
    return ListingState(
      listing: MyListing.fromJson((j['listing'] as Map).cast<String, dynamic>()),
      url: j['url'] as String?,
      missing: [for (final m in (j['missing'] as List? ?? const [])) '$m'],
      postKinds: [for (final m in (j['postKinds'] as List? ?? const [])) '$m'],
      newRequests: (j['newRequests'] as num?)?.toInt() ?? 0,
      regNo: _s(clinic['regNo']),
      hours: _s(clinic['hours']),
    );
  }
}

/// What a missing code means, in the professional's words.
String missingLabel(String code) => switch (code) {
      'name' => 'Your name',
      'address' => 'Full address',
      'location' => 'Map pin',
      'phone' => 'Phone number',
      'reg_no' => 'Medical registration number',
      'enrolment_no' => 'Bar Council enrolment number',
      _ => code,
    };

class ListingPost {
  ListingPost({required this.id, required this.kind, required this.title, required this.body, required this.createdAt, required this.expiresAt});
  final int id;
  final String kind;
  final String title;
  final String body;
  final DateTime createdAt;
  final DateTime expiresAt;

  bool get isOffer => kind == 'offer';

  factory ListingPost.fromJson(Map<String, dynamic> j) => ListingPost(
        id: (j['id'] as num).toInt(),
        kind: _s(j['kind']),
        title: _s(j['title']),
        body: _s(j['body']),
        createdAt: DateTime.fromMillisecondsSinceEpoch((j['createdAt'] as num?)?.toInt() ?? 0),
        expiresAt: DateTime.fromMillisecondsSinceEpoch((j['expiresAt'] as num?)?.toInt() ?? 0),
      );

  static List<ListingPost> list(Object? v) => [
        for (final x in (v as List? ?? const []))
          if (x is Map) ListingPost.fromJson(x.cast<String, dynamic>())
      ];
}

class BookingRequest {
  BookingRequest({
    required this.id,
    required this.name,
    required this.phone,
    required this.preferred,
    required this.message,
    required this.source,
    required this.status,
    required this.createdAt,
  });
  final int id;
  final String name;
  final String phone;
  final String preferred;
  final String message;
  final String source;
  final String status;
  final DateTime createdAt;

  bool get isNew => status == 'new';

  factory BookingRequest.fromJson(Map<String, dynamic> j) => BookingRequest(
        id: (j['id'] as num).toInt(),
        name: _s(j['name']),
        phone: _s(j['phone']),
        preferred: _s(j['preferred']),
        message: _s(j['message']),
        source: _s(j['source']),
        status: _s(j['status']),
        createdAt: DateTime.fromMillisecondsSinceEpoch((j['createdAt'] as num?)?.toInt() ?? 0),
      );

  static List<BookingRequest> list(Object? v) => [
        for (final x in (v as List? ?? const []))
          if (x is Map) BookingRequest.fromJson(x.cast<String, dynamic>())
      ];
}

/// One professional in "near me" results, or opened in full.
class ProCard {
  ProCard({
    required this.slug,
    required this.persona,
    required this.displayName,
    required this.headline,
    required this.placeName,
    required this.address,
    required this.area,
    required this.city,
    required this.lat,
    required this.lng,
    required this.phone,
    required this.whatsapp,
    required this.acceptsRequests,
    required this.photoUrl,
    required this.url,
    required this.distanceKm,
    required this.posts,
    this.about = '',
    this.services = const [],
    this.languages = '',
    this.hours = '',
    this.regNo = '',
    this.qualification = '',
    this.fee = 0,
  });

  final String slug;
  final String persona;
  final String displayName;
  final String headline;
  final String placeName;
  final String address;
  final String area;
  final String city;
  final double? lat;
  final double? lng;
  final String phone;
  final String whatsapp;
  final bool acceptsRequests;
  final String? photoUrl;
  final String url;
  final double? distanceKm;
  final List<ListingPost> posts;
  final String about;
  final List<String> services;
  final String languages;
  final String hours;
  final String regNo;
  final String qualification;
  final double fee;

  /// Businesses lead with the shop's name; doctors and advocates with theirs.
  String get title => persona == 'business' && placeName.isNotEmpty ? placeName : displayName;
  String get subtitle => persona == 'business'
      ? [displayName, headline].where((s) => s.isNotEmpty).join(' · ')
      : [headline, placeName].where((s) => s.isNotEmpty).join(' · ');
  String get where => [area, city].where((s) => s.isNotEmpty).join(', ');

  factory ProCard.fromJson(Map<String, dynamic> j) => ProCard(
        slug: _s(j['slug']),
        persona: _s(j['persona']),
        displayName: _s(j['displayName']),
        headline: _s(j['headline']),
        placeName: _s(j['placeName']),
        address: _s(j['address']),
        area: _s(j['area']),
        city: _s(j['city']),
        lat: _d(j['lat']),
        lng: _d(j['lng']),
        phone: _s(j['phone']),
        whatsapp: _s(j['whatsapp']),
        acceptsRequests: j['acceptsRequests'] != false,
        photoUrl: j['photoUrl'] as String?,
        url: _s(j['url']),
        distanceKm: _d(j['distanceKm']),
        posts: ListingPost.list(j['posts']),
        about: _s(j['about']),
        services: [for (final s in (j['services'] as List? ?? const [])) '$s'],
        languages: _s(j['languages']),
        hours: _s(j['hours']),
        regNo: _s(j['regNo']),
        qualification: _s(j['qualification']),
        fee: _d(j['fee']) ?? 0,
      );

  static List<ProCard> list(Object? v) => [
        for (final x in (v as List? ?? const []))
          if (x is Map) ProCard.fromJson(x.cast<String, dynamic>())
      ];
}

/// "1.2 km" / "350 m".
String distanceLabel(double? km) {
  if (km == null) return '';
  if (km < 1) return '${(km * 1000 / 10).round() * 10} m';
  return '${km < 10 ? km.toStringAsFixed(1) : km.round()} km';
}

/// A lat/lng from whatever a person pastes: a Google Maps link
/// ("…/@12.87,74.84,17z", "?q=12.87,74.84", "!3d12.87!4d74.84") or a bare
/// "12.87, 74.84". Null when there is no believable pair in it.
({double lat, double lng})? parseLatLng(String text) {
  final t = text.trim();
  final patterns = [
    RegExp(r'!3d(-?\d{1,2}\.\d+)!4d(-?\d{1,3}\.\d+)'),
    RegExp(r'@(-?\d{1,2}\.\d+),\s*(-?\d{1,3}\.\d+)'),
    RegExp(r'[?&](?:q|query|ll|destination)=(-?\d{1,2}\.\d+),\s*(-?\d{1,3}\.\d+)'),
    RegExp(r'^(-?\d{1,2}\.\d+)\s*,\s*(-?\d{1,3}\.\d+)$'),
  ];
  for (final p in patterns) {
    final m = p.firstMatch(t);
    if (m == null) continue;
    final lat = double.parse(m.group(1)!);
    final lng = double.parse(m.group(2)!);
    if (lat.abs() <= 90 && lng.abs() <= 180 && !(lat == 0 && lng == 0)) {
      return (lat: lat, lng: lng);
    }
  }
  return null;
}
