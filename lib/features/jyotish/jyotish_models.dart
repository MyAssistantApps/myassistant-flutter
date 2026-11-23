// JYOTISH MODELS (2026-11-22) — what /jyotish returns, parsed defensively:
// a missing or oddly typed field gives an empty value, never a crash, so an
// older or newer backend still shows what it can.

String _s(Object? v) => v is String ? v : (v == null ? '' : '$v');
String? _sn(Object? v) => v is String && v.isNotEmpty ? v : null;
int _i(Object? v, [int d = 0]) => v is num ? v.toInt() : d;
double _d(Object? v, [double d = 0]) => v is num ? v.toDouble() : d;
bool _b(Object? v) => v == true;
List<Map<String, dynamic>> _maps(Object? v) => v is List
    ? [for (final e in v) if (e is Map) e.cast<String, dynamic>()]
    : const [];
Map<String, dynamic> _map(Object? v) =>
    v is Map ? v.cast<String, dynamic>() : const {};
DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v) : null;

const kSigns = [
  'Aries', 'Taurus', 'Gemini', 'Cancer', 'Leo', 'Virgo', 'Libra', 'Scorpio',
  'Sagittarius', 'Capricorn', 'Aquarius', 'Pisces',
];

/// Two-letter planet marks used in the kundli drawings.
const kPlanetAbbr = {
  'Sun': 'Su', 'Moon': 'Mo', 'Mars': 'Ma', 'Mercury': 'Me', 'Jupiter': 'Ju',
  'Venus': 'Ve', 'Saturn': 'Sa', 'Rahu': 'Ra', 'Ketu': 'Ke',
};

/// Birth details as the user confirmed them. [time] null = not known.
class Birth {
  const Birth({
    this.name,
    required this.date,
    this.time,
    this.place,
    required this.lat,
    required this.lng,
    this.tz,
    this.gender,
    this.utc,
    this.offsetMinutes,
  });

  final String? name;
  final String date; // YYYY-MM-DD
  final String? time; // HH:MM, 24-hour
  final String? place;
  final double lat;
  final double lng;
  final String? tz;
  final String? gender;
  final String? utc;
  final int? offsetMinutes;

  bool get timeKnown => time != null;

  static Birth? fromJson(Object? v) {
    final j = _map(v);
    final date = _sn(j['date']);
    if (date == null || j['lat'] is! num || j['lng'] is! num) return null;
    return Birth(
      name: _sn(j['name']),
      date: date,
      time: _sn(j['time']),
      place: _sn(j['place']),
      lat: _d(j['lat']),
      lng: _d(j['lng']),
      tz: _sn(j['tz']),
      gender: _sn(j['gender']),
      utc: _sn(j['utc']),
      offsetMinutes: j['offsetMinutes'] is num ? _i(j['offsetMinutes']) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        if (name != null) 'name': name,
        'date': date,
        'time': time,
        if (place != null) 'place': place,
        'lat': lat,
        'lng': lng,
        if (tz != null) 'tz': tz,
        if (gender != null) 'gender': gender,
      };
}

class PlaceOption {
  const PlaceOption(
      {required this.name, required this.lat, required this.lng, this.tz});
  final String name;
  final double lat;
  final double lng;
  final String? tz;

  static List<PlaceOption> listFrom(Object? v) => [
        for (final m in _maps(v))
          if (m['lat'] is num && m['lng'] is num)
            PlaceOption(
                name: _s(m['name']),
                lat: _d(m['lat']),
                lng: _d(m['lng']),
                tz: _sn(m['tz'])),
      ];
}

/// What the AI read from the chat.
class Extracted {
  const Extracted({
    this.name,
    this.date,
    this.time,
    this.timeStatus = 'not_given',
    this.place,
    this.gender,
    this.followUp,
    this.complete = false,
    this.places = const [],
  });

  final String? name, date, time, place, gender, followUp;
  final String timeStatus; // exact | approximate | unknown | not_given
  final bool complete;
  final List<PlaceOption> places;

  bool get timeUnknown => timeStatus == 'unknown';

  static Extracted fromJson(Map<String, dynamic> j) {
    final f = _map(j['fields']);
    return Extracted(
      name: _sn(f['name']),
      date: _sn(f['date']),
      time: _sn(f['time']),
      timeStatus: _sn(f['timeStatus']) ?? 'not_given',
      place: _sn(f['place']),
      gender: _sn(f['gender']),
      followUp: _sn(j['followUp']),
      complete: _b(j['complete']),
      places: PlaceOption.listFrom(j['places']),
    );
  }
}

class Graha {
  const Graha({
    required this.name,
    required this.lon,
    required this.sign,
    required this.signName,
    required this.degree,
    required this.nakshatra,
    required this.pada,
    required this.retrograde,
    this.house,
    this.houseFromMoon,
    this.houseFromLagna,
  });

  final String name;
  final double lon;
  final int sign; // 0 = Aries
  final String signName;
  final double degree;
  final String nakshatra;
  final int pada;
  final bool retrograde;
  final int? house;
  final int? houseFromMoon;
  final int? houseFromLagna;

  String get abbr => kPlanetAbbr[name] ?? name.substring(0, 2);

  /// Rahu and Ketu always move backwards; only the others are worth flagging.
  bool get showRetro => retrograde && name != 'Rahu' && name != 'Ketu';

  /// "14°03′"
  String get dms {
    final d = degree.floor();
    final m = ((degree - d) * 60).floor();
    return '$d°${m.toString().padLeft(2, '0')}′';
  }

  static Graha fromJson(Map<String, dynamic> j) => Graha(
        name: _s(j['name']),
        lon: _d(j['lon']),
        sign: _i(j['sign']).clamp(0, 11),
        signName: _s(j['signName']),
        degree: _d(j['degree']),
        nakshatra: _s(j['nakshatra']),
        pada: _i(j['pada'], 1),
        retrograde: _b(j['retrograde']),
        house: j['house'] is num ? _i(j['house']) : null,
        houseFromMoon: j['houseFromMoon'] is num ? _i(j['houseFromMoon']) : null,
        houseFromLagna:
            j['houseFromLagna'] is num ? _i(j['houseFromLagna']) : null,
      );
}

class DashaPeriod {
  const DashaPeriod(
      {required this.lord, this.start, this.end, this.sub = const []});
  final String lord;
  final DateTime? start;
  final DateTime? end;
  final List<DashaPeriod> sub;

  bool covers(DateTime t) =>
      start != null && end != null && !t.isBefore(start!) && t.isBefore(end!);

  static DashaPeriod fromJson(Map<String, dynamic> j) => DashaPeriod(
        lord: _s(j['lord']),
        start: _date(j['start']),
        end: _date(j['end']),
        sub: [for (final a in _maps(j['antardashas'])) DashaPeriod.fromJson(a)],
      );
}

class Yoga {
  const Yoga({required this.name, this.present, this.reason});
  final String name;

  /// null = cannot be judged without the birth time.
  final bool? present;
  final String? reason;
}

class SaturnStatus {
  const SaturnStatus({
    this.houseFromMoon,
    this.sadeSati = false,
    this.phase,
    this.sadeStart,
    this.sadeEnd,
    this.sadeNext,
    this.ashtama = false,
    this.ashtamaStart,
    this.ashtamaEnd,
  });
  final int? houseFromMoon;
  final bool sadeSati;
  final String? phase; // rising | peak | setting
  final String? sadeStart, sadeEnd, sadeNext;
  final bool ashtama;
  final String? ashtamaStart, ashtamaEnd;

  static SaturnStatus fromJson(Object? v) {
    final j = _map(v);
    final s = _map(j['sadeSati']);
    final a = _map(j['ashtamaShani']);
    return SaturnStatus(
      houseFromMoon: j['saturnHouseFromMoon'] is num
          ? _i(j['saturnHouseFromMoon'])
          : null,
      sadeSati: _b(s['active']),
      phase: _sn(s['phase']),
      sadeStart: _sn(s['start']),
      sadeEnd: _sn(s['end']),
      sadeNext: _sn(s['next']),
      ashtama: _b(a['active']),
      ashtamaStart: _sn(a['start']),
      ashtamaEnd: _sn(a['end']),
    );
  }
}

class Manglik {
  const Manglik({
    this.present = false,
    this.partial = false,
    this.mitigated = false,
    this.mitigations = const [],
    this.fromMoonHouse,
    this.fromLagnaHouse,
  });
  final bool present, partial, mitigated;
  final List<String> mitigations;
  final int? fromMoonHouse, fromLagnaHouse;

  static Manglik fromJson(Object? v) {
    final j = _map(v);
    final fl = j['fromLagna'];
    return Manglik(
      present: _b(j['present']),
      partial: _b(j['partial']),
      mitigated: _b(j['mitigated']),
      mitigations: [
        for (final m in (j['mitigations'] is List ? j['mitigations'] as List : const []))
          if (m is String) m
      ],
      fromMoonHouse: _i(_map(j['fromMoon'])['house']),
      fromLagnaHouse: fl is Map ? _i(fl['house']) : null,
    );
  }
}

class Chart {
  const Chart({
    required this.timeKnown,
    required this.planets,
    this.lagna,
    required this.rashi,
    required this.nakshatra,
    required this.pada,
    this.moonUncertain = false,
    this.dashas = const [],
    this.balanceLord,
    this.balanceYears,
    this.yogas = const [],
    this.manglik = const Manglik(),
    this.saturn = const SaturnStatus(),
  });

  final bool timeKnown;
  final List<Graha> planets;
  final Graha? lagna;
  final String rashi;
  final String nakshatra;
  final int pada;
  final bool moonUncertain;
  final List<DashaPeriod> dashas;
  final String? balanceLord;
  final double? balanceYears;
  final List<Yoga> yogas;
  final Manglik manglik;
  final SaturnStatus saturn;

  Graha? planet(String name) {
    for (final p in planets) {
      if (p.name == name) return p;
    }
    return null;
  }

  /// The sign the drawings start from: the lagna, or the Moon without a time.
  int get firstSign => lagna?.sign ?? planet('Moon')?.sign ?? 0;

  /// (mahadasha, antardasha) running at [t].
  (DashaPeriod?, DashaPeriod?) dashaAt(DateTime t) {
    for (final m in dashas) {
      if (m.covers(t)) {
        for (final a in m.sub) {
          if (a.covers(t)) return (m, a);
        }
        return (m, null);
      }
    }
    return (null, null);
  }

  static Chart fromJson(Map<String, dynamic> j) {
    final lagna = _map(j['lagna']);
    final nak = _map(j['nakshatra']);
    final dasha = _map(j['dasha']);
    final bal = _map(dasha['balance']);
    return Chart(
      timeKnown: _b(j['timeKnown']),
      planets: [for (final p in _maps(j['planets'])) Graha.fromJson(p)],
      lagna: lagna.isEmpty ? null : Graha.fromJson({...lagna, 'name': 'Lagna'}),
      rashi: _s(_map(j['rashi'])['signName']),
      nakshatra: _s(nak['name']),
      pada: _i(nak['pada'], 1),
      moonUncertain: _b(j['moonUncertain']),
      dashas: [for (final m in _maps(dasha['mahadashas'])) DashaPeriod.fromJson(m)],
      balanceLord: _sn(bal['lord']),
      balanceYears: bal['years'] is num ? _d(bal['years']) : null,
      yogas: [
        for (final y in _maps(j['yogas']))
          Yoga(
            name: _s(y['name']),
            present: y['present'] is bool ? y['present'] as bool : null,
            reason: _sn(y['reason']),
          )
      ],
      manglik: Manglik.fromJson(j['manglik']),
      saturn: SaturnStatus.fromJson(j['saturn']),
    );
  }
}

class Transits {
  const Transits({this.date, this.planets = const [], this.saturn = const SaturnStatus()});
  final DateTime? date;
  final List<Graha> planets;
  final SaturnStatus saturn;

  static Transits fromJson(Object? v) {
    final j = _map(v);
    return Transits(
      date: _date(j['date']),
      planets: [for (final p in _maps(j['planets'])) Graha.fromJson(p)],
      saturn: SaturnStatus.fromJson(j['saturn']),
    );
  }
}

class ChartResult {
  const ChartResult({required this.birth, required this.chart, required this.transits, this.disclaimer});
  final Birth birth;
  final Chart chart;
  final Transits transits;
  final String? disclaimer;

  static ChartResult? fromJson(Map<String, dynamic>? j) {
    if (j == null) return null;
    final birth = Birth.fromJson(j['birth']);
    final chart = _map(j['chart']);
    if (birth == null || chart.isEmpty) return null;
    return ChartResult(
      birth: birth,
      chart: Chart.fromJson(chart),
      transits: Transits.fromJson(j['transits']),
      disclaimer: _sn(j['disclaimer']),
    );
  }
}

class SavedProfile {
  const SavedProfile({required this.id, required this.name, required this.birth});
  final int id;
  final String name;
  final Birth birth;

  static List<SavedProfile> listFrom(Object? v) => [
        for (final m in _maps(v))
          if (Birth.fromJson(m['birth']) case final b?)
            SavedProfile(id: _i(m['id']), name: _s(m['name']), birth: b),
      ];
}

/// One server-sent event of a reading.
sealed class ReadingEvent {
  const ReadingEvent();
}

class ReadingMeta extends ReadingEvent {
  const ReadingMeta({this.cached = false, this.disclaimer, this.start, this.end});
  final bool cached;
  final String? disclaimer;
  final String? start, end;
}

class ReadingText extends ReadingEvent {
  const ReadingText(this.text);
  final String text;
}

class ReadingFallback extends ReadingEvent {
  const ReadingFallback();
}

class ReadingError extends ReadingEvent {
  const ReadingError(this.message);
  final String message;
}

/// Parses one `data:` payload (already JSON-decoded); null for anything unknown.
ReadingEvent? readingEventFrom(Object? j) {
  if (j is! Map) return null;
  if (j['error'] != null) {
    final e = j['error'];
    return ReadingError(e is Map ? _s(e['message']) : _s(e));
  }
  if (j['meta'] is Map) {
    final m = (j['meta'] as Map).cast<String, dynamic>();
    final p = _map(m['period']);
    return ReadingMeta(
      cached: _b(m['cached']),
      disclaimer: _sn(m['disclaimer']),
      start: _sn(p['start']),
      end: _sn(p['end']),
    );
  }
  if (j['fallback'] == true) return const ReadingFallback();
  final t = j['t'];
  if (t is String && t.isNotEmpty) return ReadingText(t);
  return null;
}
