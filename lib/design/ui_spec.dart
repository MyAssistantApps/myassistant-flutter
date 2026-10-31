import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/log.dart';
import '../services/api_service.dart';
import 'neon_fonts.dart';
import 'neon_palette.dart';
import 'neon_tokens.dart';
import 'theme_controller.dart';

/// One block of a custom Home card, filled in by the server.
class UiBlock {
  const UiBlock({required this.type, this.value, this.label, this.ask, this.items = const []});
  final String type; // text | list | stat | button
  final String? value, label, ask;
  final List<String> items;

  static UiBlock? fromJson(Object? j) {
    if (j is! Map || j['type'] is! String) return null;
    return UiBlock(
      type: j['type'] as String,
      value: j['value']?.toString(),
      label: j['label']?.toString(),
      ask: j['ask']?.toString(),
      items: [if (j['items'] is List) for (final x in j['items'] as List) x.toString()],
    );
  }
}

/// A card the Design agent built for the person's Home.
class UiCard {
  const UiCard({required this.id, required this.title, this.accent, this.blocks = const []});
  final String id, title;
  final Color? accent;
  final List<UiBlock> blocks;

  static UiCard? fromJson(Object? j) {
    if (j is! Map || j['id'] is! String || j['title'] is! String) return null;
    return UiCard(
      id: j['id'] as String,
      title: j['title'] as String,
      accent: _color(j['accent']),
      blocks: [
        if (j['blocks'] is List)
          for (final b in j['blocks'] as List)
            if (UiBlock.fromJson(b) case final x?) x,
      ],
    );
  }
}

Color? _color(Object? v) {
  final m = RegExp(r'^#([0-9a-fA-F]{6})$').firstMatch(v?.toString() ?? '');
  return m == null ? null : Color(0xFF000000 | int.parse(m[1]!, radix: 16));
}

/// THE PERSON'S LOOK (the Design agent, 2026-10-31) — the server's UI spec
/// (backend src/design/spec.js) as the app draws it. Null fields are the
/// app's own look, so the default spec changes nothing.
@immutable
class UiSpec {
  const UiSpec({
    this.mode,
    this.palette,
    this.cardText,
    this.cardMuted,
    this.cardBorder,
    this.headerTitle,
    this.gradientFrom,
    this.gradientTo,
    this.radius,
    this.cardStyle,
    this.font,
    this.scale = 1,
    this.background,
    this.title = 'MyAssistant',
    this.showDate = true,
    this.showQuote = true,
    this.sections = const [],
    this.cards = const {},
    this.raw = const {},
  });

  final String? mode;
  final NeonPalette? palette;

  /// Colours the design sets beyond the palette (null = the app's own).
  final Color? cardText, cardMuted, cardBorder, headerTitle, gradientFrom, gradientTo;
  final double? radius;
  final String? cardStyle, font, background;
  final double scale;
  final String title;
  final bool showDate, showQuote;

  /// Home's sections in order: built-in ids and `card:<id>`.
  final List<({String id, bool visible})> sections;

  /// Custom cards by id, filled in.
  final Map<String, UiCard> cards;

  /// The spec as the server sent it (cached, and restored after a preview).
  final Map<String, Object?> raw;

  static const plain = UiSpec();

  /// Whether [id] shows on Home ([sections] empty: everything shows).
  bool shows(String id) {
    for (final s in sections) {
      if (s.id == id) return s.visible;
    }
    return true;
  }

  /// The app's own colours by the design document's names (backend
  /// src/design/spec.js APP_COLORS), dark and light.
  static const _app = {
    true: {
      'page': Color(0xFF070B2B), 'pageText': Color(0xFFF3F6FF), 'pageMuted': Color(0xFFBAC4E3),
      'pageFaint': Color(0xFF8E9AC2), 'card': Color(0xFF0C1440), 'cardRaised': Color(0xFF121B4E),
      'primary': Color(0xFF3D8BFF), 'partner': Color(0xFFE04BF5), 'secondary': Color(0xFF22E4FF),
      'tertiary': Color(0xFFBDF64B),
    },
    false: {
      'page': Color(0xFFF7F7FB), 'pageText': Color(0xFF1B1D28), 'pageMuted': Color(0xFF585E70),
      'pageFaint': Color(0xFF6B7185), 'card': Color(0xFFFFFFFF), 'cardRaised': Color(0xFFEEEFF6),
      'primary': Color(0xFF2563EB), 'partner': Color(0xFFC026D3), 'secondary': Color(0xFF0891B2),
      'tertiary': Color(0xFF65A30D),
    },
  };

  /// The v1 look (palette/shape/type) as a v2 document, for one cached
  /// before the Designer changed format.
  static Map<String, Object?> _v2(Map<String, Object?> s) {
    if (s['version'] == 2 || s['palette'] is! Map && s['shape'] is! Map) return s;
    final p = (s['palette'] as Map?) ?? const {};
    const map = {
      'bg': 'page', 'surface': 'card', 'surfaceHigh': 'cardRaised', 'textHi': 'pageText',
      'textLo': 'pageMuted', 'textDim': 'pageFaint', 'primary': 'primary', 'partner': 'partner',
      'secondary': 'secondary', 'tertiary': 'tertiary',
    };
    final shape = (s['shape'] as Map?) ?? const {};
    final type = (s['type'] as Map?) ?? const {};
    return {
      ...s,
      'version': 2,
      'colors': {for (final e in map.entries) if (p[e.key] != null) e.value: p[e.key]},
      'background': {'style': s['background'] is String ? s['background'] : null},
      'cards': {'style': shape['cardStyle'], 'radius': shape['radius']},
      'typography': {'font': type['font'], 'scale': type['scale']},
    };
  }

  /// From GET /ui/spec: the design document [spec] (v2), and [cards] (the
  /// custom cards filled in).
  static UiSpec fromJson(Map<String, Object?> input, [List<Object?>? cards]) {
    final spec = _v2(input);
    final colors = spec['colors'] is Map ? spec['colors'] as Map : const {};
    final c = <String, Color>{
      for (final e in colors.entries)
        if (_color(e.value) case final v?) e.key.toString(): v,
    };
    // Dark by the page colour when set, else by the mode.
    final dark = spec['dark'] is bool
        ? spec['dark'] as bool
        : c['page'] != null
            ? c['page']!.computeLuminance() < 0.2
            : spec['mode'] != 'light';
    final palette = c.isEmpty
        ? null
        : () {
            final base = _app[dark]!;
            Color k(String key) => c[key] ?? base[key]!;
            return NeonPalette(
              name: spec['name']?.toString() ?? 'Mine',
              dark: dark,
              bg: k('page'),
              surface: k('card'),
              surfaceHigh: k('cardRaised'),
              primary: k('primary'),
              partner: k('partner'),
              secondary: k('secondary'),
              tertiary: k('tertiary'),
              textHi: k('pageText'),
              textLo: k('pageMuted'),
              textDim: k('pageFaint'),
              success: c['success'],
              warning: c['warning'],
              error: c['error'],
            );
          }();
    final bg = spec['background'] is Map ? spec['background'] as Map : const {};
    final cardsIn = spec['cards'] is Map ? spec['cards'] as Map : const {};
    final type = spec['typography'] is Map ? spec['typography'] as Map : const {};
    final header = spec['header'] is Map ? spec['header'] as Map : const {};
    final home = spec['home'] is Map ? spec['home'] as Map : const {};
    final filled = <String, UiCard>{
      for (final x in cards ?? (spec['customCards'] is List ? spec['customCards'] as List : const []))
        if (UiCard.fromJson(x) case final card?) card.id: card,
    };
    return UiSpec(
      mode: spec['mode']?.toString(),
      palette: palette,
      cardText: c['cardText'] ?? c['pageText'],
      cardMuted: c['cardMuted'] ?? c['pageMuted'],
      cardBorder: c['cardBorder'],
      headerTitle: c['headerTitle'],
      gradientFrom: _color(bg['from']),
      gradientTo: _color(bg['to']),
      radius: (cardsIn['radius'] as num?)?.toDouble(),
      cardStyle: cardsIn['style']?.toString(),
      font: type['font']?.toString(),
      scale: ((type['scale'] as num?) ?? 1).toDouble().clamp(0.9, 1.3),
      background: bg['style']?.toString(),
      title: (header['title']?.toString().trim().isNotEmpty ?? false) ? header['title'].toString() : 'MyAssistant',
      showDate: header['showDate'] != false,
      showQuote: header['showQuote'] != false,
      sections: [
        if (home['sections'] is List)
          for (final x in home['sections'] as List)
            if (x is Map && x['id'] is String) (id: x['id'] as String, visible: x['visible'] != false),
      ],
      cards: filled,
      raw: spec,
    );
  }
}

/// Holds the person's look, applies it to the tokens the whole app reads,
/// keeps it cached for an instant start, and asks the server for it after
/// sign-in — so a reinstall, or a new phone, gets the same look back.
abstract final class UiSpecStore {
  static const _key = 'ui_spec_v1';

  /// The look in force. The app's root rebuilds when it changes.
  static final ValueNotifier<UiSpec> current = ValueNotifier(UiSpec.plain);

  /// Bumped on every apply: part of the key that rebuilds the whole tree.
  static int stamp = 0;

  /// The cached look, before anything is drawn (main.dart).
  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final s = prefs.getString(_key);
      if (s == null) return;
      final j = jsonDecode(s);
      if (j is Map) {
        _apply(UiSpec.fromJson(Map<String, Object?>.from(j['spec'] as Map), j['cards'] as List?), save: false);
      }
    } catch (e) {
      AppLog.add('design', 'cached look unreadable: $e');
    }
  }

  /// The server's copy, once per signed-in person: called from places the
  /// look itself rebuilds (the auth gate), so it must not fetch every time.
  static int? _fetchedFor;
  static Future<void> ensureFor(int userId) async {
    if (_fetchedFor == userId) return;
    _fetchedFor = userId;
    await refresh();
  }

  /// The server's copy (after sign-in, and when the app comes back).
  static Future<void> refresh() async {
    final tz = DateTime.now().timeZoneOffset.inMinutes;
    final j = await ApiService.getJson('/ui/spec?tz=$tz');
    if (j == null || j['spec'] is! Map) return;
    _apply(UiSpec.fromJson(Map<String, Object?>.from(j['spec'] as Map), j['cards'] as List?));
  }

  /// A spec the Design agent just made (deviceAction apply_ui_spec). Its
  /// custom cards are filled on the next [refresh].
  static void applyFromServer(Map<String, Object?> spec) {
    _previewTimer?.cancel();
    _apply(UiSpec.fromJson(spec));
    unawaited(refresh());
  }

  static Future<bool> undo() => _post('/ui/undo');
  static Future<bool> reset() => _post('/ui/reset');

  static Future<bool> _post(String path) async {
    final tz = DateTime.now().timeZoneOffset.inMinutes;
    final j = await ApiService.postJson('$path?tz=$tz', const {});
    if (j == null || j['spec'] is! Map) return false;
    _apply(UiSpec.fromJson(Map<String, Object?>.from(j['spec'] as Map), j['cards'] as List?));
    return true;
  }

  /// SHOWING OPTIONS (preview_ui_specs): each for [seconds], then the look
  /// they had. Nothing is saved; they choose by saying which.
  static Timer? _previewTimer;
  static final ValueNotifier<String?> previewing = ValueNotifier(null);
  static void preview(List<({String label, Map<String, Object?> spec})> options, int seconds) {
    _previewTimer?.cancel();
    final back = current.value;
    var i = 0;
    void next() {
      if (i >= options.length) {
        previewing.value = null;
        _apply(back, save: false);
        return;
      }
      previewing.value = 'Option ${i + 1} of ${options.length}: ${options[i].label}';
      _apply(UiSpec.fromJson(options[i].spec), save: false);
      i++;
      _previewTimer = Timer(Duration(seconds: seconds.clamp(2, 10)), next);
    }

    next();
  }

  static void _apply(UiSpec s, {bool save = true}) {
    Neon.usePalette(s.palette);
    Neon.useLook(
      radius: s.radius,
      cardStyle: s.cardStyle,
      background: s.background,
      cardText: s.cardText,
      cardMuted: s.cardMuted,
      cardBorder: s.cardBorder,
      headerTitle: s.headerTitle,
      gradientFrom: s.gradientFrom,
      gradientTo: s.gradientTo,
    );
    NeonFonts.use(s.font);
    // A palette is dark or light by its page; otherwise the mode they asked for.
    final mode = s.palette != null
        ? (s.palette!.dark ? ThemeMode3.dark : ThemeMode3.light)
        : switch (s.mode) {
            'dark' => ThemeMode3.dark,
            'light' => ThemeMode3.light,
            'adaptive' => ThemeMode3.adaptive,
            _ => null,
          };
    if (mode != null && mode != ThemeController.mode.value) unawaited(ThemeController.setMode(mode));
    if (s.palette != null) Neon.setDark(s.palette!.dark);
    stamp++;
    current.value = s;
    if (save) unawaited(_save(s));
  }

  static Future<void> _save(UiSpec s) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode({
        'spec': s.raw,
        'cards': [
          for (final c in s.cards.values)
            {
              'id': c.id,
              'title': c.title,
              if (c.accent != null)
                'accent': '#${(c.accent!.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}',
              'blocks': [
                for (final b in c.blocks)
                  {'type': b.type, 'value': b.value, 'label': b.label, 'ask': b.ask, 'items': b.items},
              ],
            },
        ],
      }));
    } catch (_) {}
  }
}
