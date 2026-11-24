import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/log.dart';

/// One colour the dock mic can wear: its ring (and glow) and the mic glyph.
class MicColorOption {
  const MicColorOption(this.id, this.label, this.ring, this.glyph);
  final String id;
  final String label;
  final Color ring;
  final Color glyph;
}

/// THE DOCK MIC'S COLOUR (2026-11-24): chosen on the mic customisation page
/// (hold the mic for 3 seconds). Only the colour changes — the ringed
/// design stays the same. Kept on the phone.
class MicColorStore extends ValueNotifier<MicColorOption> {
  MicColorStore._() : super(options.first);
  static final MicColorStore instance = MicColorStore._();

  static const _key = 'dock_mic.color.v1';

  /// The first is the original violet, exactly as the mic always looked.
  static const options = <MicColorOption>[
    MicColorOption('violet', 'Violet', Color(0xFF8B5CF6), Color(0xFFC4B5FD)),
    MicColorOption('blue', 'Blue', Color(0xFF3B82F6), Color(0xFFBFDBFE)),
    MicColorOption('cyan', 'Cyan', Color(0xFF06B6D4), Color(0xFFA5F3FC)),
    MicColorOption('green', 'Green', Color(0xFF22C55E), Color(0xFFBBF7D0)),
    MicColorOption('yellow', 'Yellow', Color(0xFFEAB308), Color(0xFFFEF08A)),
    MicColorOption('orange', 'Orange', Color(0xFFF97316), Color(0xFFFED7AA)),
    MicColorOption('red', 'Red', Color(0xFFEF4444), Color(0xFFFECACA)),
    MicColorOption('pink', 'Pink', Color(0xFFEC4899), Color(0xFFFBCFE8)),
    MicColorOption('white', 'White', Color(0xFFE5E7EB), Color(0xFFFFFFFF)),
  ];

  static MicColorOption byId(String? id) =>
      options.firstWhere((o) => o.id == id, orElse: () => options.first);

  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      value = byId(prefs.getString(_key));
    } catch (e) {
      AppLog.add('mic', 'colour load failed: $e');
    }
  }

  Future<void> choose(MicColorOption o) async {
    value = o;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, o.id);
    } catch (e) {
      AppLog.add('mic', 'colour save failed: $e');
    }
  }
}
