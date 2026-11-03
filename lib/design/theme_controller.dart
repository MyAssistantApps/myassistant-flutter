import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'neon_tokens.dart';

/// The two choices a user has. Dark is the default.
enum ThemeMode3 {
  light,
  dark,
}

/// ─────────────────────────────────────────────────────────────────────────
///  THEME CONTROLLER — one switch, the whole app follows.
///
///  The design system (Neon) resolves every token off [Neon.isDark]; this
///  controller owns that flag, persists the choice, keeps the status-bar
///  icons in step, and notifies the root so the entire tree rebuilds.
///
///  Two themes only, Light and Dark, switched by the user (You → Appearance
///  → Dark mode, or by voice). Dark is the default (2026-11-03). Adaptive
///  (follow the clock) was removed; a phone that had it saved starts dark.
/// ─────────────────────────────────────────────────────────────────────────
class ThemeController {
  ThemeController._();

  static const _prefsKey = 'theme_dark_v1'; // legacy boolean, still honoured
  static const _modeKey = 'theme_mode_v1';

  /// Bumps on every switch; the app root listens and rebuilds.
  static final ValueNotifier<bool> dark = ValueNotifier(true);

  /// The chosen mode, for settings to render. Dark unless chosen.
  static final ValueNotifier<ThemeMode3> mode =
      ValueNotifier(ThemeMode3.dark);

  /// Called in main() BEFORE runApp, so the first frame is already right.
  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_modeKey);
      if (saved != null) {
        // An unknown value (including the removed 'adaptive') means Dark.
        mode.value = ThemeMode3.values.firstWhere(
          (m) => m.name == saved,
          orElse: () => ThemeMode3.dark,
        );
      } else if (prefs.containsKey(_prefsKey)) {
        mode.value =
            (prefs.getBool(_prefsKey) ?? true) ? ThemeMode3.dark : ThemeMode3.light;
      }
      await prefs.setString(_modeKey, mode.value.name);
    } catch (_) {}
    _apply(mode.value == ThemeMode3.dark);
  }

  /// Pick a theme. It is applied at once and remembered.
  static Future<void> setMode(ThemeMode3 m) async {
    mode.value = m;
    _apply(m == ThemeMode3.dark);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_modeKey, m.name);
      // Keep the legacy key in step for anything still reading it.
      await prefs.setBool(_prefsKey, dark.value);
    } catch (_) {}
  }

  /// Flip between Light and Dark.
  static Future<void> toggle() =>
      setMode(dark.value ? ThemeMode3.light : ThemeMode3.dark);

  static void _apply(bool v) {
    Neon.setDark(v);
    dark.value = v;
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: const Color(0x00000000),
      statusBarIconBrightness: v ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: Neon.bg,
      systemNavigationBarIconBrightness:
          v ? Brightness.light : Brightness.dark,
    ));
  }
}
