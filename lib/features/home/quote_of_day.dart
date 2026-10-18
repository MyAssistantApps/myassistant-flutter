import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/daily_quotes.dart';
import '../../services/api_service.dart';

/// One picture for the day's line, made once on the server for everyone
/// (backend src/quotecards). The words are set on the phone over it.
class QuoteCard {
  const QuoteCard({
    required this.style,
    required this.label,
    required this.url,
    required this.ink,
    required this.serif,
    required this.lightScrim,
    required this.lower,
  });

  final String style;
  final String label;

  /// Absolute URL; the pictures are public, so Image.network needs no header.
  final String url;
  final Color ink;
  final bool serif;

  /// A light picture (watercolour) gets a pale wash under the words, not a
  /// dark one.
  final bool lightScrim;

  /// The picture's subject fills the top (the divine style), so the words
  /// sit in the lower half instead of the middle.
  final bool lower;

  static QuoteCard? fromJson(Map<String, dynamic> j) {
    final url = j['url'] as String?;
    if (url == null || url.isEmpty) return null;
    return QuoteCard(
      style: j['style'] as String? ?? '',
      label: j['label'] as String? ?? '',
      url: url.startsWith('http') ? url : '${ApiService.baseUrl}$url',
      ink: _hex(j['ink'] as String?) ?? const Color(0xFFFFFFFF),
      serif: j['font'] == 'serif',
      lightScrim: j['scrim'] == 'light',
      lower: j['place'] == 'lower',
    );
  }

  static Color? _hex(String? s) {
    if (s == null || !RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(s)) return null;
    return Color(0xFF000000 | int.parse(s.substring(1), radix: 16));
  }
}

class QuoteDay {
  const QuoteDay({
    required this.date,
    required this.text,
    required this.generating,
    required this.total,
    required this.cards,
  });

  final String date;
  final String text;
  final bool generating;
  final int total;
  final List<QuoteCard> cards;

  static QuoteDay? fromJson(Map<String, dynamic>? j) {
    final text = (j?['text'] as String?)?.trim() ?? '';
    final date = j?['date'] as String? ?? '';
    if (j == null || text.isEmpty || date.isEmpty) return null;
    final cards = <QuoteCard>[];
    for (final c in (j['cards'] as List? ?? const [])) {
      if (c is Map<String, dynamic>) {
        final q = QuoteCard.fromJson(c);
        if (q != null) cards.add(q);
      }
    }
    return QuoteDay(
      date: date,
      text: text,
      generating: j['status'] == 'generating',
      total: (j['total'] as num?)?.toInt() ?? cards.length,
      cards: cards,
    );
  }
}

/// THE DAY'S LINE (2026-10-18). The server writes a new one each India
/// day and the same line reaches everyone; the phone keeps the last one it
/// saw, and falls back to the built-in rotation ([DailyQuotes]) when it
/// has nothing for today — the home page never shows an empty line.
class QuoteOfDay {
  QuoteOfDay._();

  static const _prefsKey = 'quote_of_day_v1';

  /// The last answer from the server (today's, once fetched).
  static final ValueNotifier<QuoteDay?> current = ValueNotifier(null);
  static String? _raw;
  static DateTime? _lastTry;
  static bool _loaded = false;

  /// YYYY-MM-DD in India — the server's day.
  static String indiaToday([DateTime? now]) {
    final t = (now ?? DateTime.now()).toUtc().add(const Duration(hours: 5, minutes: 30));
    return '${t.year.toString().padLeft(4, '0')}-'
        '${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
  }

  /// The line to show right now.
  static String line() {
    final d = current.value;
    if (d != null && d.date == indiaToday()) return d.text;
    return DailyQuotes.today();
  }

  /// Read the saved answer, then ask the server when the saved one is not
  /// today's. Cheap to call on every build: it throttles itself.
  static Future<void> ensureFresh() async {
    if (!_loaded) {
      _loaded = true;
      try {
        final p = await SharedPreferences.getInstance();
        final s = p.getString(_prefsKey);
        if (s != null) {
          final j = jsonDecode(s);
          if (j is Map<String, dynamic>) {
            _raw = s;
            current.value = QuoteDay.fromJson(j);
          }
        }
      } catch (_) {}
    }
    final d = current.value;
    if (d != null && d.date == indiaToday() && !d.generating) return;
    final last = _lastTry;
    if (last != null && DateTime.now().difference(last) < const Duration(minutes: 2)) return;
    await refresh();
  }

  /// Ask the server now. Returns the day, or null when it could not be read.
  static Future<QuoteDay?> refresh() async {
    _lastTry = DateTime.now();
    final j = await ApiService.getJson('/quote-cards/today',
        timeout: const Duration(seconds: 15));
    final d = QuoteDay.fromJson(j);
    if (d == null) return current.value;
    current.value = d;
    final s = jsonEncode(j);
    if (s != _raw) {
      _raw = s;
      try {
        final p = await SharedPreferences.getInstance();
        await p.setString(_prefsKey, s);
      } catch (_) {}
    }
    return d;
  }
}
