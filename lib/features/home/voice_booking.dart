import 'dart:async';
import 'dart:convert';

import 'package:firebase_ai/firebase_ai.dart' show Content, TextPart;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../ai/assistant_role.dart';
import '../../ai/config.dart';
import '../../ai/listen.dart';
import '../../ai/local_tools.dart';
import '../../ai/model_port.dart';
import '../../ai/speech.dart';
import '../../ai/types.dart' show AiToolSpec;
import '../assistant/state/assistant_engine.dart';
import '../../core/log.dart';
import '../../design/neon_tokens.dart';
import '../../services/audio/pcm_player.dart';
import '../../widgets/neuron_orb.dart';
import '../../widgets/role_mic_orb.dart';
import '../../widgets/voice_orb.dart' show OrbMood;

/// ─────────────────────────────────────────────────────────────────────────
///  SPEAK TO FILL (2026-11-21, Manish: "add a mic so you can speak and book
///  anything — from, to, number of people, everything updates by voice").
///
///  The booking screens (hotels, flights, buses) get a mic bar on top. What
///  is said is read on the phone, here, into the form's fields — instant,
///  offline and testable — and only what was said changes: "make it three
///  people" changes the count and nothing else.
/// ─────────────────────────────────────────────────────────────────────────

/// What a trip request said (flights, buses). Null = not mentioned.
class VoiceTrip {
  const VoiceTrip({this.from, this.to, this.date, this.people, this.cabin});
  final String? from;
  final String? to;
  final DateTime? date;
  final int? people;

  /// 'economy' | 'premium' | 'business' | 'first'.
  final String? cabin;

  bool get isEmpty => from == null && to == null && date == null && people == null && cabin == null;
}

/// What a stay request said (hotels). Null = not mentioned.
class VoiceStay {
  const VoiceStay({this.city, this.checkIn, this.checkOut, this.nights, this.adults, this.rooms});
  final String? city;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final int? nights;
  final int? adults;
  final int? rooms;

  bool get isEmpty =>
      city == null && checkIn == null && checkOut == null && nights == null && adults == null && rooms == null;
}

/// Reads spoken booking requests. Pure: give it the words, today and the
/// places the screen knows; it gives back the fields it heard.
abstract final class VoiceBooking {
  /// How people say a city vs what the lists call it.
  static const aliases = {
    'bangalore': 'Bengaluru',
    'bengaluru': 'Bengaluru',
    'bombay': 'Mumbai',
    'delhi': 'New Delhi',
    'new delhi': 'New Delhi',
    'calcutta': 'Kolkata',
    'madras': 'Chennai',
    'mangalore': 'Mangaluru',
    'mysore': 'Mysuru',
    'cochin': 'Kochi',
    'ernakulam': 'Kochi',
    'trivandrum': 'Thiruvananthapuram',
    'calicut': 'Kozhikode',
    'vizag': 'Visakhapatnam',
    'pondicherry': 'Puducherry',
    'trichy': 'Tiruchirappalli',
    'hubli': 'Hubballi',
    'belgaum': 'Belagavi',
    'shimoga': 'Shivamogga',
    'baroda': 'Vadodara',
    'poona': 'Pune',
    'gurgaon': 'New Delhi',
    'noida': 'New Delhi',
    'banaras': 'Varanasi',
    'benares': 'Varanasi',
    'nyc': 'New York',
  };

  static const _numbers = {
    'one': 1, 'a': 1, 'an': 1, 'single': 1, 'two': 2, 'couple of': 2, 'three': 3, 'four': 4, 'five': 5,
    'six': 6, 'seven': 7, 'eight': 8, 'nine': 9, 'ten': 10, 'eleven': 11, 'twelve': 12,
  };

  static const _months = {
    'jan': 1, 'january': 1, 'feb': 2, 'february': 2, 'mar': 3, 'march': 3, 'apr': 4, 'april': 4,
    'may': 5, 'jun': 6, 'june': 6, 'jul': 7, 'july': 7, 'aug': 8, 'august': 8, 'sep': 9, 'sept': 9,
    'september': 9, 'oct': 10, 'october': 10, 'nov': 11, 'november': 11, 'dec': 12, 'december': 12,
  };

  static const _weekdays = {
    'monday': 1, 'tuesday': 2, 'wednesday': 3, 'thursday': 4, 'friday': 5, 'saturday': 6, 'sunday': 7,
  };

  static final _monthRe = _months.keys.toList()..sort((a, b) => b.length - a.length);
  static String get _mon => '(${_monthRe.join('|')})';
  static const _ord = r'(?:st|nd|rd|th)?';

  /// Lower case, number words as digits, punctuation as spaces.
  static String normalise(String said) {
    var s = ' ${said.toLowerCase().replaceAll(RegExp(r"[,.!?;:]"), ' ').replaceAll('-', ' to ')} ';
    final words = _numbers.keys.toList()..sort((a, b) => b.length - a.length);
    for (final w in words) {
      // "a"/"an" only count before a counted thing ("a room", "an adult").
      final guard = (w == 'a' || w == 'an') ? r'(?=\s+(?:room|adult|night|person|passenger|ticket|seat))' : '';
      s = s.replaceAll(RegExp('(?<=\\s)$w(?=\\s)$guard'), '${_numbers[w]}');
    }
    return s.replaceAll(RegExp(r'\s+'), ' ');
  }

  // ── Places ───────────────────────────────────────────────────────────

  /// Every place mentioned, in order, as the list names it.
  static List<({String name, int at})> places(String s, Iterable<String> known) {
    final names = <String, String>{}; // spoken form → list name
    for (final k in known) {
      names[k.toLowerCase()] = k;
    }
    for (final e in aliases.entries) {
      final target = known.firstWhere((k) => k == e.value, orElse: () => '');
      if (target.isNotEmpty) names[e.key] = target;
    }
    final keys = names.keys.toList()..sort((a, b) => b.length - a.length);
    final found = <({String name, int at})>[];
    final taken = List<bool>.filled(s.length, false);
    for (final k in keys) {
      for (final m in RegExp('(?<=\\s)${RegExp.escape(k)}(?=\\s)').allMatches(s)) {
        if (taken.sublist(m.start, m.end).any((t) => t)) continue;
        for (var i = m.start; i < m.end; i++) {
          taken[i] = true;
        }
        found.add((name: names[k]!, at: m.start));
      }
    }
    found.sort((a, b) => a.at.compareTo(b.at));
    return found;
  }

  // ── Counts ───────────────────────────────────────────────────────────

  static int? _count(String s, String things) {
    final m = RegExp('(\\d{1,2}) (?:more )?(?:$things)\\b').firstMatch(s);
    return m == null ? null : int.parse(m.group(1)!);
  }

  static int? people(String s) {
    final n = _count(s, r'adults?|people|persons?|passengers?|travell?ers?|pax|guests?|members?|of us|tickets?|seats?');
    if (n != null) return n;
    if (RegExp(r'\bjust me\b|\bonly me\b|\bmyself\b|\balone\b|\bsolo\b').hasMatch(s)) return 1;
    if (RegExp(r'\bme and my (?:wife|husband|partner|friend|mother|father|mom|dad)\b|\bcouple\b').hasMatch(s)) return 2;
    // "for two" (not "for 2 nights"), or a number said on its own at the
    // end ("…25 november, two") — but not a date ("november 2").
    final forN = RegExp(r'\bfor (\d{1,2})\b(?! (?:nights?|days?|rooms?|weeks?))').firstMatch(s);
    if (forN != null) return int.parse(forN.group(1)!);
    final last = RegExp(r'(\S+) (\S+) (\d{1,2})\s*$').firstMatch(s);
    const dateWords = {'the', 'on', 'by', 'at', 'to', 'till', 'until', 'from', 'before', 'after', 'in', 'and'};
    if (last != null && !dateWords.contains(last.group(2))) {
      final month = _months.containsKey(last.group(2));
      // "november 2" is a date; "25 november 2" is a date and then a count.
      final dayFirst = RegExp(r'^\d{1,2}(?:st|nd|rd|th)?$').hasMatch(last.group(1)!);
      if (!month || dayFirst) return int.parse(last.group(3)!);
    }
    return null;
  }

  // ── Dates ────────────────────────────────────────────────────────────

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  /// A day and month, the next one from today (this year, else next).
  static DateTime? _dm(int day, int month, DateTime today) {
    if (day < 1 || day > 31) return null;
    var d = DateTime(today.year, month, day);
    if (d.month != month) return null; // 31 Feb
    if (d.isBefore(today)) d = DateTime(today.year + 1, month, day);
    return d;
  }

  /// A day of this month (next month once it has passed).
  static DateTime? _dOnly(int day, DateTime today) {
    if (day < 1 || day > 31) return null;
    var d = DateTime(today.year, today.month, day);
    if (d.isBefore(today)) d = DateTime(today.year, today.month + 1, day);
    return d.day == day ? d : null;
  }

  /// Every date mentioned, in the order said.
  static List<DateTime> dates(String s, DateTime now) {
    final today = _day(now);
    final out = <({DateTime d, int at})>[];
    final taken = List<bool>.filled(s.length, false);
    void add(RegExpMatch m, DateTime? d) {
      if (d == null || taken.sublist(m.start, m.end).any((t) => t)) return;
      for (var i = m.start; i < m.end; i++) {
        taken[i] = true;
      }
      out.add((d: d, at: m.start));
    }

    // "22 to 25 november" / "22nd and 25th of nov": both in that month.
    for (final m in RegExp('\\b(\\d{1,2})$_ord (?:to|till|until|and) (\\d{1,2})$_ord (?:of )?$_mon\\b').allMatches(s)) {
      final mo = _months[m.group(3)]!;
      final a = _dm(int.parse(m.group(1)!), mo, today);
      final b = a == null ? null : DateTime(a.year, mo, int.parse(m.group(2)!));
      if (a != null && b != null) {
        for (var i = m.start; i < m.end; i++) {
          taken[i] = true;
        }
        out.add((d: a, at: m.start));
        out.add((d: b.isBefore(a) ? DateTime(b.year + 1, b.month, b.day) : b, at: m.start + 1));
      }
    }
    // "25th december" / "25 of dec"
    for (final m in RegExp('\\b(\\d{1,2})$_ord (?:of )?$_mon\\b').allMatches(s)) {
      add(m, _dm(int.parse(m.group(1)!), _months[m.group(2)]!, today));
    }
    // "december 25th"
    for (final m in RegExp('\\b$_mon (\\d{1,2})$_ord\\b(?! (?:adults?|people|persons?|passengers?|rooms?|nights?))').allMatches(s)) {
      add(m, _dm(int.parse(m.group(2)!), _months[m.group(1)]!, today));
    }
    for (final m in RegExp(r'\bday after tomorrow\b').allMatches(s)) {
      add(m, today.add(const Duration(days: 2)));
    }
    for (final m in RegExp(r'\b(?:tomorrow|tmrw)\b').allMatches(s)) {
      add(m, today.add(const Duration(days: 1)));
    }
    for (final m in RegExp(r'\b(?:today|tonight)\b').allMatches(s)) {
      add(m, today);
    }
    for (final m in RegExp(r'\b(?:this )?weekend\b').allMatches(s)) {
      final ahead = (DateTime.saturday - today.weekday) % 7;
      add(m, today.add(Duration(days: ahead)));
    }
    for (final m in RegExp(r'\bnext week\b').allMatches(s)) {
      add(m, today.add(const Duration(days: 7)));
    }
    for (final m in RegExp(r'\bin (\d{1,2}) days?\b').allMatches(s)) {
      add(m, today.add(Duration(days: int.parse(m.group(1)!))));
    }
    // "next friday" (the one after this week's), "this friday", "on friday"
    for (final m in RegExp('\\b(next |this |coming |on )?(${_weekdays.keys.join('|')})\\b').allMatches(s)) {
      final wd = _weekdays[m.group(2)]!;
      var ahead = (wd - today.weekday) % 7;
      if (ahead == 0) ahead = 7; // "next friday" = the coming one
      add(m, today.add(Duration(days: ahead)));
    }
    // "on the 25th", "the 25th" — a day of this month.
    for (final m in RegExp(r'\b(?:on )?the (\d{1,2})(?:st|nd|rd|th)\b').allMatches(s)) {
      add(m, _dOnly(int.parse(m.group(1)!), today));
    }
    out.sort((a, b) => a.at.compareTo(b.at));
    return [for (final e in out) e.d];
  }

  // ── Requests ─────────────────────────────────────────────────────────

  /// A trip: "from Bangalore to Delhi on 5th December, 2 passengers, business".
  static VoiceTrip trip(String said, {required DateTime now, required Iterable<String> places}) {
    final s = normalise(said);
    final found = VoiceBooking.places(s, places);
    String? from, to;
    for (final p in found) {
      final before = s.substring(0, p.at).trimRight();
      if (RegExp(r'\b(?:from|leaving|departing|starting)$').hasMatch(before)) {
        from = p.name;
      } else if (RegExp(r'\b(?:to|towards|for|till|until|reach|reaching|going)$').hasMatch(before)) {
        to = p.name;
      }
    }
    final loose = found.where((p) => p.name != from && p.name != to).map((p) => p.name).toList();
    if (from == null && to == null && loose.length >= 2) {
      from = loose[0];
      to = loose[1];
    } else if (from == null && to != null && loose.isNotEmpty) {
      from = loose.first;
    } else if (to == null && from != null && loose.isNotEmpty) {
      to = loose.first;
    }
    final d = dates(s, now);
    final cabin = RegExp(r'\bpremium\b').hasMatch(s)
        ? 'premium'
        : RegExp(r'\bbusiness\b').hasMatch(s)
            ? 'business'
            : RegExp(r'\bfirst class\b').hasMatch(s)
                ? 'first'
                : RegExp(r'\beconomy\b').hasMatch(s)
                    ? 'economy'
                    : null;
    return VoiceTrip(from: from, to: to, date: d.isEmpty ? null : d.first, people: people(s), cabin: cabin);
  }

  /// A stay: "Goa from 22 to 25 November, 2 adults, 1 room" or
  /// "hotel in Mysore tomorrow for 3 nights".
  static VoiceStay stay(String said, {required DateTime now, Iterable<String> places = const []}) {
    final s = normalise(said);
    String? city;
    final found = VoiceBooking.places(s, places);
    if (found.isNotEmpty) {
      city = found.first.name;
    } else {
      // An unknown place: what follows "in / at / near / to".
      final m = RegExp(r'\b(?:in|at|near|to|stay|hotel|hotels|resort|resorts)\s+([a-z][a-z ]{1,40}?)(?=\s+(?:from|for|on|with|check|checking|tomorrow|today|tonight|next|this|coming|day|the|and|\d)|\s*$)')
          .firstMatch(s);
      final words = m?.group(1)?.trim().replaceFirst(RegExp(r'^(?:in|at|near|to) '), '');
      const notPlaces = {'a', 'the', 'room', 'rooms', 'hotel', 'hotels', 'stay', 'me', 'us', 'book', 'find', 'search'};
      if (words != null && words.isNotEmpty && !notPlaces.contains(words)) {
        city = words.split(' ').map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');
      }
    }
    final d = dates(s, now);
    final nights = _count(s, r'nights?');
    return VoiceStay(
      city: city,
      checkIn: d.isEmpty ? null : d.first,
      checkOut: d.length >= 2 && d[1].isAfter(d.first) ? d[1] : null,
      nights: nights,
      adults: people(s),
      rooms: _count(s, r'rooms?'),
    );
  }
}

/// The listener the booking mic uses: the phone's own recogniser (live
/// words while speaking), whatever the served "record" mode says.
VoiceListener bookingListener() {
  AiConfig deviceFirst() {
    final c = AiConfigStore.instance.current;
    return AiConfig(
      models: c.models,
      routing: c.routing,
      limits: c.limits,
      live: c.live,
      listen: const AiListen(cloudStt: 'device'),
      fromServer: c.fromServer,
    );
  }

  // No recorder / cloud transcriber: when the phone's recogniser fails the
  // mic starts again at once (the cloud fallback recorded for 20 s and
  // needs the server's model, which may be down).
  return VoiceListener(config: deviceFirst);
}

/// Speak to book thinks and speaks with the same AI as the main assistant
/// (2026-11-22, Manish: "don't use Gemini, use OpenAI for the booking
/// too"): the app's model port, which follows /ai/config — the backend
/// serves OpenAI (backend.envisionsit.in, src/ai/config.js), so the words
/// go to our server's OpenAI and the replies come back in the assistant's
/// OpenAI voice. (An earlier build called Gemini directly while the old
/// server's OpenAI key was failing.)
ModelPort bookingPort() => ModelPorts.cloud();

/// The served config, but always the phone's own recogniser for the mic.
AiConfig bookingConfig() {
  final c = AiConfigStore.instance.current;
  return AiConfig(
    models: c.models,
    routing: c.routing,
    limits: c.limits,
    live: c.live,
    listen: const AiListen(cloudStt: 'device'),
    fromServer: c.fromServer,
  );
}

/// The bright colours of the booking mic (the same in both themes, so it
/// always stands out).
const _hot = [Color(0xFFFF3D8B), Color(0xFF8B5CF6)];

// ── The booking agent: the main assistant's AI, for one form ───────────

/// What a booking screen tells the agent: its fields, their values now,
/// how to set them and what it can do.
class BookingForm {
  const BookingForm({
    required this.screen,
    required this.example,
    required this.fields,
    required this.state,
    required this.apply,
    required this.parseLocal,
    this.places,
    this.actions = const {},
  });

  /// 'Hotels', 'Domestic Flights', 'Buses'…
  final String screen;

  /// What to say, e.g. "Goa, 22 to 25 Nov, 2 adults, 1 room".
  final String example;

  /// Each field and what it holds, for the model.
  final Map<String, String> fields;

  /// The form now, as field → value.
  final Map<String, Object?> Function() state;

  /// Sets what the model asked for; returns what changed ('' = nothing).
  final String Function(Map<String, Object?> set) apply;

  /// The on-phone reading, when the AI cannot be reached.
  final String Function(String said) parseLocal;

  /// The places a from/to must be one of (null = any place).
  final Iterable<String>? places;

  /// What it can do: id → (what it does, do it).
  final Map<String, (String, Future<void> Function())> actions;
}

/// One answer from the agent.
class AgentReply {
  const AgentReply({this.set = const {}, this.reply = '', this.action, this.listen = false});
  final Map<String, Object?> set;
  final String reply;
  final String? action;

  /// It asked something and waits for the answer.
  final bool listen;

  /// The model's JSON (inside any fences or chatter); null if there is none.
  static AgentReply? parse(String text) {
    final a = text.indexOf('{'), b = text.lastIndexOf('}');
    if (a < 0 || b <= a) return null;
    try {
      final j = jsonDecode(text.substring(a, b + 1));
      if (j is! Map) return null;
      final set = j['set'];
      final act = j['action'];
      return AgentReply(
        set: set is Map ? {for (final e in set.entries) '${e.key}': e.value} : const {},
        reply: '${j['reply'] ?? ''}'.trim(),
        action: act is String && act.isNotEmpty && act != 'null' && act != 'none' ? act : null,
        listen: j['listen'] == true,
      );
    } catch (_) {
      return null;
    }
  }
}

/// THE BOOKING AGENT (2026-11-22, Manish: "add the AI the main assistant
/// uses, so it talks with you and can book too"). The assistant's own AI
/// ([bookingPort]: our server's OpenAI), given the screen's form, today and the
/// conversation so far; it answers with the fields to set, a short spoken
/// reply and, when the user wants to go ahead, an action.
class BookingAgent {
  BookingAgent(this.form, {ModelPort? port, DateTime Function()? now, AiConfig Function()? config})
      : _port = port ?? bookingPort(),
        _now = now ?? DateTime.now,
        _config = config ?? bookingConfig;

  final BookingForm form;
  final ModelPort _port;
  final DateTime Function() _now;
  final AiConfig Function() _config;
  final List<Content> _history = [];

  static const _days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

  static String iso(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String system() {
    final t = _now();
    final places = form.places;
    final fields = form.fields.entries.map((e) => '- ${e.key}: ${e.value}').join('\n');
    final actions = form.actions.isEmpty
        ? '- nothing'
        : form.actions.entries.map((e) => '- "${e.key}": ${e.value.$1}').join('\n');
    final cities = places == null
        ? ''
        : '\nCities must be one of these exact names (map nicknames: Bangalore = Bengaluru, '
            'Bombay = Mumbai, Delhi = New Delhi, Mangalore = Mangaluru, Mysore = Mysuru, '
            'Cochin = Kochi, Trivandrum = Thiruvananthapuram, Vizag = Visakhapatnam): '
            '${places.toSet().join(', ')}. If the user names a city that is not there, '
            'do not set it; say it is not available here.\n';
    return '''
You are the voice booking helper inside the MyAssistant app, on the ${form.screen} screen.
Today is ${_days[t.weekday - 1]}, ${iso(t)}. The user talks to you; you fill in the booking form for them and answer out loud like a warm, quick travel agent.

The form's fields:
$fields

The form now: ${jsonEncode(form.state())}
$cities
What you can do when the user wants to go ahead (search, book, go, yes, show me):
$actions

Rules:
- Set only what the user said or clearly meant. Keep everything else as it is.
- Dates are YYYY-MM-DD and never before today. Work out "tomorrow", "next Friday", "this weekend", "22 to 25 November" from today.
- Your reply is spoken: one or two short sentences, plain English, no lists, no emojis, no markdown. Confirm what you set in a natural way ("Done, Goa from the 22nd to the 25th for two."). If something needed to book is still missing or unclear, ask for it in the same reply.
- When the form is complete, offer to search (or name a site to book on).
- Set "action" only when the user asked to go ahead; then say you are opening it.
- "listen" is true when you asked a question and wait for the answer, otherwise false.

Answer with ONLY this JSON, nothing else:
{"set": {"<field>": <value>}, "reply": "<what you say>", "action": null, "listen": false}''';
  }

  /// The user said [words]: the agent's answer (null when the model could
  /// not be reached or did not answer in JSON).
  Future<AgentReply?> respond(String words) async {
    final user = Content.text(words);
    try {
      final r = await _port
          .generate(ModelRequest(
            model: _config().models.cloudFast,
            system: system(),
            contents: [..._history, user],
          ))
          .timeout(const Duration(seconds: 15));
      final text = r.text ?? '';
      AppLog.add('voicefill', 'agent: ${text.replaceAll('\n', ' ')}');
      final reply = AgentReply.parse(text);
      if (reply == null) return null;
      _history
        ..add(user)
        ..add(Content.model([TextPart(text)]));
      // The last few turns are enough context.
      while (_history.length > 12) {
        _history.removeAt(0);
      }
      return reply;
    } catch (e) {
      AppLog.add('voicefill', 'agent failed: $e');
      return null;
    }
  }
}

/// A date the model sent (YYYY-MM-DD), never before today; null if none.
DateTime? voiceDate(Object? v, {DateTime? now}) {
  if (v is! String) return null;
  final d = DateTime.tryParse(v.trim());
  if (d == null) return null;
  final t = now ?? DateTime.now();
  final today = DateTime(t.year, t.month, t.day);
  final day = DateTime(d.year, d.month, d.day);
  return day.isBefore(today) ? null : day;
}

/// A whole number the model sent (2, "2", 2.0); null if none.
int? voiceInt(Object? v) => v is num ? v.round() : (v is String ? int.tryParse(v.trim()) : null);

/// A non-empty string the model sent; null if none.
String? voiceText(Object? v) => v is String && v.trim().isNotEmpty ? v.trim() : null;

/// THE BOOKING MIC (2026-11-21, Manish: "make the mic more visible —
/// floating, bright"; 2026-11-22: "talk along with you and book"): a big
/// floating "Speak to book" button. Tap and talk: the assistant's AI fills
/// the form, answers in the assistant's voice and, when it asked something,
/// listens again by itself — a conversation, until the booking is opened
/// or the user taps stop. Without the AI (offline) the words are read on
/// the phone instead. Put it in the screen's floatingActionButton
/// (centerFloat) and leave ~120 px under the content.
class VoiceFillButton extends StatefulWidget {
  const VoiceFillButton({super.key, required this.form, this.listener, this.agent, this.speech, this.talk = true});

  final BookingForm form;

  /// For tests; [bookingListener] by default.
  final VoiceListener? listener;

  /// For tests; a [BookingAgent] on the assistant's model by default.
  final BookingAgent? agent;

  /// For tests; the assistant's voice by default.
  final SpeechEngine? speech;

  /// Speak the replies (off in tests).
  final bool talk;

  @override
  State<VoiceFillButton> createState() => _VoiceFillButtonState();
}

enum _Phase { idle, listening, thinking, speaking, done }

class _VoiceFillButtonState extends State<VoiceFillButton> with TickerProviderStateMixin {
  VoiceListener? _listener;
  VoiceListener get _voice => _listener ??= widget.listener ?? bookingListener();
  BookingAgent? _agentMade;
  BookingAgent get _agent => _agentMade ??= widget.agent ?? BookingAgent(widget.form);
  SpeechEngine? _speechMade;
  SpeechEngine get _speech => _speechMade ??= widget.speech ?? SpeechEngine(port: bookingPort(), config: bookingConfig);
  late final _breath = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))
    ..repeat(reverse: true);
  _Phase _phase = _Phase.idle;
  String _words = ''; // what the user said (live while listening)
  String _reply = ''; // what the assistant answered
  String _filled = ''; // what changed on the form
  bool _ok = true;
  double _level = 0;
  Timer? _hide;
  StreamSubscription<HearEvent>? _sub;
  bool _stopped = false;
  bool _busy = false;

  /// The microphone level for the orb.
  final _levelNote = ValueNotifier<double>(0);

  /// The orb's size.
  static const double _orb = 72;

  /// How long it waits for the first words.
  static const _wait = Duration(seconds: 12);

  /// At most this many back-and-forths per tap.
  static const _maxTurns = 8;

  @override
  void dispose() {
    _stopped = true;
    _hide?.cancel();
    _breath.dispose();
    _levelNote.dispose();
    unawaited(_sub?.cancel());
    unawaited(_listener?.cancel().catchError((_) {}));
    if (widget.talk) unawaited(_speechMade?.cancel(sink: PcmPlayer.instance).catchError((_) {}));
    super.dispose();
  }

  void _set(VoidCallback f) {
    if (mounted) setState(f);
  }

  Future<void> _tap() async {
    if (_busy) {
      AppLog.add('voicefill', 'stop tapped');
      _stopped = true;
      await _voice.stop();
      if (widget.talk) await _speechMade?.cancel(sink: PcmPlayer.instance).catchError((_) {});
      return;
    }
    _hide?.cancel();
    HapticFeedback.mediumImpact();
    _set(() {
      _busy = true;
      _reply = '';
      _filled = '';
    });
    _stopped = false;
    try {
      await _converse();
    } finally {
      _busy = false;
    }
    if (!mounted) return;
    _set(() {
      _phase = _Phase.done;
      _level = 0;
    });
    _hide = Timer(const Duration(seconds: 8), () => _set(() => _phase = _Phase.idle));
  }

  /// Listen → think → answer → (listen again) … until done or stopped.
  Future<void> _converse() async {
    for (var turn = 0; turn < _maxTurns && mounted && !_stopped; turn++) {
      _set(() {
        _phase = _Phase.listening;
        _words = '';
        _level = 0;
      });
      String? error;
      final said = await _hear((e) => error = e, wait: turn == 0 ? _wait : const Duration(seconds: 8));
      if (!mounted || _stopped) return;
      if (said.isEmpty) {
        if (turn == 0) {
          _set(() {
            _ok = false;
            _reply = '';
            _filled = switch (error) {
              'permission' => 'Allow the microphone for this app in Settings, then try again.',
              'unavailable' || 'recorder' => 'Voice input is not available on this phone right now.',
              'network' => 'No internet for voice. Check the connection and try again.',
              'language' => 'English voice input is not installed on this phone.',
              _ => 'Did not catch that. Tap the mic and speak clearly.',
            };
          });
        }
        return; // nothing more said: the conversation is over
      }
      _set(() {
        _phase = _Phase.thinking;
        _words = said;
      });
      final r = await _agent.respond(said);
      if (!mounted || _stopped) return;
      if (r == null) {
        // No AI (offline, blocked): read it on the phone.
        final local = widget.form.parseLocal(said);
        AppLog.add('voicefill', 'local: ${local.isEmpty ? '(nothing matched)' : local}');
        _set(() {
          _ok = local.isNotEmpty;
          _reply = '';
          _filled = local.isNotEmpty ? local : 'Could not match that. Try: ${widget.form.example}';
        });
        if (local.isNotEmpty) HapticFeedback.heavyImpact();
        return;
      }
      final changed = r.set.isEmpty ? '' : widget.form.apply(r.set);
      AppLog.add('voicefill',
          'set ${jsonEncode(r.set)} -> ${changed.isEmpty ? '(no change)' : changed}; action=${r.action}; listen=${r.listen}');
      if (changed.isNotEmpty) HapticFeedback.heavyImpact();
      _set(() {
        _ok = true;
        _reply = r.reply;
        _filled = changed;
        _phase = _Phase.speaking;
      });
      await _say(r.reply);
      if (!mounted || _stopped) return;
      final act = r.action == null ? null : widget.form.actions[r.action];
      if (act != null) {
        AppLog.add('voicefill', 'action ${r.action}');
        await act.$2();
        return;
      }
      if (!r.listen) return;
    }
  }

  /// Speaks [line] in the assistant's voice and waits until it has played,
  /// so the microphone does not hear it.
  Future<void> _say(String line) async {
    if (!widget.talk || line.trim().isEmpty) return;
    try {
      final n = await _speech.speak(line, PcmPlayer.instance).timeout(const Duration(seconds: 20));
      if (n > 0) await PcmPlayer.instance.drained().timeout(const Duration(seconds: 30));
    } catch (e) {
      AppLog.add('voicefill', 'speak failed: $e');
    }
  }

  /// Listens until words are heard (starting again while nothing is, up to
  /// [wait]); the words, '' for none.
  Future<String> _hear(void Function(String code) onError, {required Duration wait}) async {
    final began = DateTime.now();
    var tries = 0;
    while (mounted && !_stopped) {
      tries++;
      String? err;
      final said = await _listenOnce((e) => err = e);
      if (err != null) onError(err!);
      final waited = DateTime.now().difference(began);
      if (said.isNotEmpty || _stopped || err == 'permission' || waited >= wait) return said;
      AppLog.add('voicefill', 'nothing yet (try $tries, ${waited.inMilliseconds} ms, error=$err), listening again');
    }
    return '';
  }

  /// One go of the recogniser: the words heard ('' = none); [onError] gets
  /// its error code, if any.
  Future<String> _listenOnce(void Function(String code) onError) async {
    var said = '';
    final done = Completer<void>();
    AppLog.add('voicefill', 'listening');
    _sub = _voice
        .listen(
          language: 'en-IN',
          listenFor: const Duration(seconds: 20),
          pauseFor: const Duration(milliseconds: 2200),
          // Up to 8 s of silence before the first words, in one go.
          startPause: const Duration(seconds: 8),
          // Google's online recogniser first: better with Indian place names
          // and needs no language pack (the on-device en-IN pack is often
          // not downloaded); on-device is the fallback.
          preferOnDevice: false,
        )
        .listen(
      (e) {
        if (!mounted) return;
        switch (e) {
          case HearPartial(:final text):
            setState(() => _words = text);
          case HearLevel(:final level):
            _levelNote.value = level;
            if ((level - _level).abs() > 0.04) setState(() => _level = level);
          case HearFinal(:final text, :final fromCloud):
            said = text.trim();
            AppLog.add('voicefill', 'heard${fromCloud ? ' (cloud)' : ''}: "$said"');
          case HearError(:final code, :final permanent):
            onError(code);
            AppLog.add('voicefill', 'error $code (permanent=$permanent)');
          case HearEndOfSpeech():
            break;
        }
      },
      onError: (Object e) {
        AppLog.add('voicefill', 'stream failed: $e');
        onError('failed');
        if (!done.isCompleted) done.complete();
      },
      onDone: () {
        if (!done.isCompleted) done.complete();
      },
      cancelOnError: true,
    );
    await done.future;
    _sub = null;
    return said;
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width - 32;
    final listening = _phase == _Phase.listening;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedSwitcher(
          duration: Neon.med,
          switchInCurve: Curves.easeOutBack,
          transitionBuilder: (c, a) => FadeTransition(
            opacity: a,
            child: SlideTransition(
                position: Tween(begin: const Offset(0, 0.25), end: Offset.zero).animate(a), child: c),
          ),
          child: _phase == _Phase.idle ? const SizedBox(key: ValueKey('none')) : _panel(width),
        ),
        const SizedBox(height: 10),
        // THE ORB (2026-11-22, Manish: "that kind of mic design" — the
        // assistant pages' Tap to talk): a dark disc with a glowing rim and
        // the neuron orb inside, which follows the voice while it listens
        // and shows thinking and speaking; a word under it.
        Semantics(
          button: true,
          label: _busy ? 'Stop' : 'Speak to book',
          excludeSemantics: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _tap,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _breath,
                  builder: (_, child) {
                    final t = _breath.value;
                    return Container(
                      width: _orb,
                      height: _orb,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withValues(alpha: 0.55),
                        border: Border.all(color: _hot.last.withValues(alpha: 0.85), width: 1.8),
                        boxShadow: [
                          BoxShadow(
                            color: _hot.last.withValues(alpha: _busy ? 0.55 + 0.35 * _level : 0.3 + 0.2 * t),
                            blurRadius: _busy ? 22 + 18 * _level : 14 + 8 * t,
                            spreadRadius: _busy ? 1 + 4 * _level : 0.5 + t,
                          ),
                        ],
                      ),
                      child: child,
                    );
                  },
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        left: -_orb * 0.25,
                        right: -_orb * 0.25,
                        top: -_orb * 0.25,
                        bottom: -_orb * 0.25,
                        child: IgnorePointer(
                          child: NeuronOrb(
                            radius: _orb * 0.28,
                            mood: switch (_phase) {
                              _Phase.listening => OrbMood.listening,
                              _Phase.thinking => OrbMood.thinking,
                              _Phase.speaking => OrbMood.speaking,
                              _ => OrbMood.idle,
                            },
                            levelListenable: listening ? _levelNote : null,
                            active: true,
                          ),
                        ),
                      ),
                      if (!_busy) const Icon(Icons.mic_rounded, color: Colors.white, size: _orb * 0.38),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(Neon.rPill),
                  ),
                  child: Text(
                      switch (_phase) {
                        _Phase.listening => 'Listening…',
                        _Phase.thinking => 'Thinking…',
                        _Phase.speaking => 'Speaking…',
                        _ => 'Speak to book',
                      },
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _panel(double width) {
    final (title, icon, color) = switch (_phase) {
      _Phase.listening => ('LISTENING — SPEAK NOW', Icons.graphic_eq_rounded, _hot.first),
      _Phase.thinking => ('THINKING', Icons.auto_awesome_rounded, _hot.last),
      _Phase.speaking => ('ASSISTANT', Icons.record_voice_over_rounded, _hot.last),
      _ => _ok
          ? (_reply.isNotEmpty ? 'ASSISTANT' : 'FILLED IN', Icons.check_circle_rounded, Neon.success)
          : ('TRY AGAIN', Icons.error_outline_rounded, Neon.warning),
    };
    final listening = _phase == _Phase.listening;
    final you = listening
        ? (_words.isEmpty ? 'Say it like: ${widget.form.example}' : _words)
        : (_words.isEmpty ? '' : '“$_words”');
    return Container(
      key: const ValueKey('panel'),
      width: width,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Neon.surfaceHigh,
        borderRadius: BorderRadius.circular(Neon.rCard),
        border: Border.all(color: color.withValues(alpha: 0.55), width: 1.4),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Expanded(child: Text(title, style: NeonType.eyebrow.copyWith(color: color))),
              if (listening) _Meter(level: _level, color: _hot.first),
              if (_phase == _Phase.thinking)
                SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: _hot.last)),
            ],
          ),
          if (you.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(you,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: _words.isEmpty || !listening ? Neon.textLo : Neon.textHi,
                    fontSize: listening && _words.isNotEmpty ? 16 : 13.5,
                    height: 1.3,
                    fontWeight: listening && _words.isNotEmpty ? FontWeight.w700 : FontWeight.w500)),
          ],
          if (!listening && _reply.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(_reply,
                style: TextStyle(color: Neon.textHi, fontSize: 15.5, height: 1.35, fontWeight: FontWeight.w700)),
          ],
          if (!listening && _filled.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_ok) ...[
                  Icon(Icons.edit_note_rounded, size: 16, color: Neon.success),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(_filled,
                      style: TextStyle(
                          color: _ok ? Neon.success : Neon.textLo,
                          fontSize: 13,
                          height: 1.3,
                          fontWeight: _ok ? FontWeight.w700 : FontWeight.w500)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Five bars that follow the microphone level.
class _Meter extends StatelessWidget {
  const _Meter({required this.level, required this.color});
  final double level;
  final Color color;

  @override
  Widget build(BuildContext context) {
    const shape = [0.5, 0.8, 1.0, 0.8, 0.5];
    return Row(
      children: [
        for (final k in shape)
          AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 4,
            height: 4 + 16 * (0.15 + 0.85 * level) * k,
            margin: const EdgeInsets.symmetric(horizontal: 1.5),
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
          ),
      ],
    );
  }
}

// ── Speak to book through the main assistant ───────────────────────────

/// SPEAK TO BOOK, THE MAIN ASSISTANT'S WAY (2026-11-22, Manish: "it should
/// work as it works in the main" and "that kind of mic design"). The orb
/// is the assistant pages' own [RoleMicOrb]: a tap starts the main
/// assistant's voice conversation — the same listening, the same OpenAI
/// brain and the same voice as the dock mic — as "the booking assistant"
/// of this screen. While the screen is open it lends the brain two local
/// tools: [fillTool] sets the fields the owner mentioned, [bookTool]
/// searches or opens a booking site. What changed shows under the orb.
class BookingVoiceOrb extends StatefulWidget {
  const BookingVoiceOrb({super.key, required this.form, this.tools, this.now, this.orb});

  final BookingForm form;

  /// For tests: what stands in for the [RoleMicOrb].
  final Widget Function(AssistantRole role)? orb;

  /// Where the tools are lent (the main brain's by default; tests pass
  /// their own).
  final LocalToolRegistry? tools;

  /// For tests.
  final DateTime Function()? now;

  static const fillTool = 'fill_booking_form';
  static const bookTool = 'start_booking';

  /// The role the main assistant takes on this screen. Stable for the day
  /// (the orb compares roles), so the form's values come from the tools.
  static AssistantRole roleFor(BookingForm form, DateTime now) {
    final places = form.places;
    final cities = places == null
        ? ''
        : ' Cities must be one of these exact names (Bangalore = Bengaluru, Bombay = Mumbai, Delhi = New Delhi, '
            'Mangalore = Mangaluru, Mysore = Mysuru, Cochin = Kochi): ${places.toSet().join(', ')}.';
    return AssistantRole(
      'the booking assistant on the ${form.screen} screen',
      'Today is ${BookingAgent.iso(now)}. You help the owner fill in this booking form by voice: '
      '${form.fields.entries.map((e) => '${e.key} (${e.value})').join('; ')}.$cities '
      'Whenever the owner says any of these, call $fillTool with ONLY the fields they mentioned '
      '(dates as YYYY-MM-DD, never in the past); it answers with the whole form. Then confirm '
      'briefly in one short sentence and ask for anything still missing. When they want to go ahead '
      '(search, book, yes, show me), call $bookTool with the action. Keep every reply short.',
    );
  }

  @override
  State<BookingVoiceOrb> createState() => _BookingVoiceOrbState();
}

class _BookingVoiceOrbState extends State<BookingVoiceOrb> {
  final _removers = <void Function()>[];
  String _changed = '';
  Timer? _hide;

  LocalToolRegistry get _tools => widget.tools ?? AssistantEngine.instance.brain.localTools;

  @override
  void initState() {
    super.initState();
    final f = widget.form;
    _removers
      ..add(_tools.register(LocalTool(
        spec: AiToolSpec(
          name: BookingVoiceOrb.fillTool,
          description: 'Fill in the ${f.screen} booking form on screen. Pass only the fields the owner '
              'mentioned. Returns what changed and the whole form.',
          parameters: {
            'type': 'object',
            'properties': {
              for (final e in f.fields.entries) e.key: {'type': 'string', 'description': e.value},
            },
          },
        ),
        available: () => mounted,
        handler: (call) async {
          final set = {
            for (final e in call.args.entries)
              if (f.fields.containsKey(e.key) && e.value != null && '${e.value}'.trim().isNotEmpty) e.key: e.value,
          };
          final changed = set.isEmpty || !mounted ? '' : f.apply(set);
          AppLog.add('voicefill', 'main fill ${jsonEncode(set)} -> ${changed.isEmpty ? '(no change)' : changed}');
          if (changed.isNotEmpty) _show(changed);
          return LocalToolResult(result: {'changed': changed, 'form': f.state()});
        },
      )))
      ..add(_tools.register(LocalTool(
        spec: AiToolSpec(
          name: BookingVoiceOrb.bookTool,
          description: 'Go ahead with the ${f.screen} booking form as it is now.',
          parameters: {
            'type': 'object',
            'properties': {
              'action': {
                'type': 'string',
                'enum': f.actions.keys.toList(),
                'description': f.actions.entries.map((e) => '${e.key}: ${e.value.$1}').join('; '),
              },
            },
            'required': ['action'],
          },
        ),
        available: () => mounted && f.actions.isNotEmpty,
        handler: (call) async {
          final id = '${call.args['action'] ?? ''}';
          final act = f.actions[id] ?? (f.actions.length == 1 ? f.actions.values.first : null);
          if (act == null) return LocalToolResult.failed('Unknown action "$id".');
          AppLog.add('voicefill', 'main action $id');
          // After the reply is spoken, so the voice is not cut off.
          unawaited(Future<void>.delayed(const Duration(milliseconds: 1200), () {
            if (mounted) act.$2();
          }));
          return LocalToolResult(result: {'opening': id, 'form': f.state()});
        },
      )));
  }

  void _show(String changed) {
    _hide?.cancel();
    HapticFeedback.heavyImpact();
    setState(() => _changed = changed);
    _hide = Timer(const Duration(seconds: 6), () {
      if (mounted) setState(() => _changed = '');
    });
  }

  @override
  void dispose() {
    _hide?.cancel();
    for (final r in _removers) {
      r();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final role = BookingVoiceOrb.roleFor(widget.form, (widget.now ?? DateTime.now)());
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedSwitcher(
          duration: Neon.med,
          child: _changed.isEmpty
              ? const SizedBox(key: ValueKey('none'))
              : Container(
                  key: ValueKey(_changed),
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Neon.surfaceHigh,
                    borderRadius: BorderRadius.circular(Neon.rPill),
                    border: Border.all(color: Neon.success.withValues(alpha: 0.6)),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 14)],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit_note_rounded, size: 16, color: Neon.success),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(_changed,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Neon.textHi, fontSize: 13, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ),
        ),
        widget.orb?.call(role) ?? RoleMicOrb(role: role, tint: _hot.last, size: 72),
      ],
    );
  }
}
