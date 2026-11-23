import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// YOUR OWN QUICK APPS (2026-11-22): on Home's Payments and Quick Apps,
/// the user adds any app on their phone and removes the ones they do not
/// use. Kept on this phone, like the Home order. The assistant opens an
/// added app by its name ([pkgFor]), by its exact package.

/// An app the user added: its name as the phone shows it, and its package.
@immutable
class AddedApp {
  const AddedApp(this.name, this.pkg);
  final String name;
  final String pkg;

  Map<String, String> toJson() => {'name': name, 'pkg': pkg};

  /// Null for anything that is not a usable entry.
  static AddedApp? fromJson(Object? j) {
    if (j is! Map) return null;
    final name = j['name'], pkg = j['pkg'];
    if (name is! String || pkg is! String) return null;
    final n = name.trim(), p = pkg.trim();
    if (n.isEmpty || !_pkgShape.hasMatch(p)) return null;
    return AddedApp(n.length > 40 ? n.substring(0, 40) : n, p);
  }

  @override
  bool operator ==(Object other) => other is AddedApp && other.pkg == pkg;

  @override
  int get hashCode => pkg.hashCode;
}

final _pkgShape = RegExp(r'^[A-Za-z][\w]*(\.[A-Za-z_][\w]*)+$');

/// What the user changed on one section: built-in apps removed (by name)
/// and apps added (in the order added).
@immutable
class SectionEdits {
  const SectionEdits({this.removed = const {}, this.added = const []});
  final Set<String> removed;
  final List<AddedApp> added;

  static const empty = SectionEdits();

  Map<String, Object> toJson() => {
        'removed': removed.toList(),
        'added': [for (final a in added) a.toJson()],
      };

  static SectionEdits fromJson(Object? j) {
    if (j is! Map) return empty;
    final removed = <String>{
      for (final r in (j['removed'] is List ? j['removed'] as List : const []))
        if (r is String && r.isNotEmpty) r,
    };
    final added = <AddedApp>[];
    for (final a in (j['added'] is List ? j['added'] as List : const [])) {
      final app = AddedApp.fromJson(a);
      if (app != null && !added.contains(app)) added.add(app);
    }
    return SectionEdits(removed: removed, added: added);
  }

  SectionEdits withAdded(AddedApp a) => added.contains(a)
      ? this
      : SectionEdits(removed: removed, added: [...added, a]);

  SectionEdits withoutAdded(String pkg) => SectionEdits(
      removed: removed, added: [for (final a in added) if (a.pkg != pkg) a]);

  SectionEdits withRemoved(String builtInName) =>
      SectionEdits(removed: {...removed, builtInName}, added: added);
}

String _norm(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

/// The package of the added app the user means by [spoken] ("open my bank
/// app" → the one named "My Bank"), or null. An exact name first; then a
/// name that contains what was said, or the other way round (3+ letters).
String? matchAddedApp(String spoken, Iterable<AddedApp> apps) {
  final want = _norm(spoken);
  if (want.isEmpty) return null;
  for (final a in apps) {
    if (_norm(a.name) == want) return a.pkg;
  }
  if (want.length < 3) return null;
  for (final a in apps) {
    final n = _norm(a.name);
    if (n.length >= 3 && (n.contains(want) || want.contains(n))) return a.pkg;
  }
  return null;
}

class QuickAppStore {
  QuickAppStore._();
  static final QuickAppStore instance = QuickAppStore._();

  static const _key = 'quick_apps_edits_v1';

  /// Section id ('payment_apps', 'quick_apps') → its edits.
  final ValueNotifier<Map<String, SectionEdits>> edits = ValueNotifier(const {});

  Future<void>? _loading;

  Future<void> load() => _loading ??= () async {
        try {
          final prefs = await SharedPreferences.getInstance();
          edits.value = decode(prefs.getString(_key));
        } catch (_) {}
      }();

  static Map<String, SectionEdits> decode(String? raw) {
    if (raw == null || raw.isEmpty) return const {};
    try {
      final j = jsonDecode(raw);
      if (j is! Map) return const {};
      return {
        for (final e in j.entries)
          if (e.key is String) e.key as String: SectionEdits.fromJson(e.value),
      };
    } catch (_) {
      return const {};
    }
  }

  SectionEdits of(String section) => edits.value[section] ?? SectionEdits.empty;

  Future<void> _set(String section, SectionEdits e) async {
    edits.value = {...edits.value, section: e};
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key,
          jsonEncode({for (final x in edits.value.entries) x.key: x.value.toJson()}));
    } catch (_) {}
  }

  Future<void> add(String section, AddedApp app) => _set(section, of(section).withAdded(app));

  Future<void> removeAdded(String section, String pkg) =>
      _set(section, of(section).withoutAdded(pkg));

  Future<void> removeBuiltIn(String section, String name) =>
      _set(section, of(section).withRemoved(name));

  /// Back to the apps the section came with.
  Future<void> reset(String section) => _set(section, SectionEdits.empty);

  /// Every app the user added, on any section.
  Iterable<AddedApp> get allAdded => edits.value.values.expand((e) => e.added);

  /// For the assistant: the package of an added app the user named.
  Future<String?> pkgFor(String spoken) async {
    await load();
    return matchAddedApp(spoken, allAdded);
  }
}
