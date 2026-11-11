import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/log.dart';
import '../models/brief.dart';

/// THE HOME-SCREEN WIDGETS from the app's side (2026-11-08). The widgets
/// themselves are Android's (HomeWidgets.kt); this places them, keeps My
/// day's numbers current, and hands over which shortcut opened the app.
class HomeWidgetsService {
  HomeWidgetsService._();
  static final instance = HomeWidgetsService._();

  static const _ch = MethodChannel('hari/widgets');
  static const _askedKey = 'home_widgets_prompt_v1';

  /// The designs, in the order the picker shows them.
  static const kinds = ['talk', 'day', 'shortcuts', 'orb'];

  /// Can the launcher be asked to place a widget? (Most Android 8+ can.)
  Future<bool> supported() async {
    try {
      return await _ch.invokeMethod<bool>('supported') == true;
    } catch (_) {
      return false;
    }
  }

  /// Shows Android's "Add to home screen" dialog for [kind].
  Future<bool> pin(String kind) async {
    try {
      return await _ch.invokeMethod<bool>('pin', {'kind': kind}) == true;
    } catch (e) {
      AppLog.add('widgets', 'pin $kind failed: $e');
      return false;
    }
  }

  /// How many of each design are on the home screen.
  Future<Map<String, int>> placed() async {
    try {
      final m = await _ch.invokeMapMethod<String, int>('placed');
      return m ?? const {};
    } catch (_) {
      return const {};
    }
  }

  /// The shortcut that opened the app ("price", "flights"), once.
  Future<String?> takeRoute() async {
    try {
      return await _ch.invokeMethod<String>('takeRoute');
    } catch (_) {
      return null;
    }
  }

  String _lastDay = '';

  /// My day's numbers, counted as Home counts them; sent only on change.
  Future<void> syncDay(TodayBrief b) async {
    final meetings = b.agenda.where((a) => a.kind == 'meeting').length;
    final reminders = b.agenda.where((a) => a.kind == 'reminder').length;
    final bills = b.dates.where((d) => d.kind == 'payment' && d.when == 'today').length;
    final now = DateTime.now().millisecondsSinceEpoch;
    final next = b.agenda.where((a) => a.atMs == null || a.atMs! >= now).firstOrNull;
    var line = '';
    if (next != null) {
      final at = next.atMs == null ? null : DateTime.fromMillisecondsSinceEpoch(next.atMs!);
      line = at == null ? next.title : '${next.title} · ${_time(at)}';
    }
    final key = '$meetings|$reminders|$bills|$line|${DateTime.now().day}';
    if (key == _lastDay) return;
    _lastDay = key;
    try {
      await _ch.invokeMethod('saveDay',
          {'meetings': meetings, 'reminders': reminders, 'bills': bills, 'next': line});
    } catch (_) {
      // No widget support on this platform: nothing to keep current.
    }
  }

  static String _time(DateTime t) {
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m ${t.hour < 12 ? 'AM' : 'PM'}';
  }

  /// Whether to offer the widgets now: once, ever, and only where they
  /// can be placed. Asking marks it asked, whatever the answer.
  Future<bool> shouldAsk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_askedKey) == true) return false;
      if (!await supported()) return false;
      await prefs.setBool(_askedKey, true);
      return true;
    } catch (_) {
      return false;
    }
  }
}
