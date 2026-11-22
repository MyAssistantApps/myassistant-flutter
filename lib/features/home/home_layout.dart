import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';


/// YOUR HOME, YOUR ORDER (owner, 2026-11-21): press and hold any card on
/// Home, feel a tap, and arrange the sections the way you want them. Each
/// card is its own section — your assistant, Talk to a Contact's
/// Assistant, Upload Your Documents, Quick Tools and the rest — and the
/// order is kept on this phone.
class HomeSection {
  const HomeSection(this.id, this.title, this.subtitle, this.icon);
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
}

class HomeLayout {
  HomeLayout._();
  static final HomeLayout instance = HomeLayout._();

  static const _key = 'home_section_order_v1';

  /// The default order, top to bottom.
  static const defaults = <String>[
    'assistant',
    'connect',
    'documents',
    'quick_tools',
    'popular_apps',
    'price_compare',
    'payment_apps',
    'quick_apps',
    'horoscope',
  ];

  static const sections = <String, HomeSection>{
    'assistant': HomeSection('assistant', 'Your Assistant',
        'Your workspace or professional assistant', Icons.workspace_premium_rounded),
    'connect': HomeSection('connect', "Talk to a Contact's Assistant",
        'Messages, urgent alerts and bookings', Icons.forum_rounded),
    'documents': HomeSection('documents', 'Upload Your Documents',
        'IDs, bills and certificates', Icons.cloud_upload_rounded),
    'quick_tools': HomeSection('quick_tools', 'Quick Tools',
        'Flights, buses, hotels and more', Icons.bolt_rounded),
    'popular_apps': HomeSection('popular_apps', 'Popular Apps',
        'Food, rides and shopping apps', Icons.apps_rounded),
    'price_compare': HomeSection('price_compare', 'Price Compare',
        'The best price across stores', Icons.price_check_rounded),
    'payment_apps': HomeSection('payment_apps', 'Payments',
        'GPay, PhonePe, Paytm and PayPal', Icons.account_balance_wallet_rounded),
    'quick_apps': HomeSection('quick_apps', 'Quick Apps',
        'WhatsApp, YouTube, Gmail and more', Icons.grid_view_rounded),
    'horoscope': HomeSection('horoscope', "Today's Horoscope",
        'Your sign for the day', Icons.auto_awesome_rounded),
  };

  final ValueNotifier<List<String>> order = ValueNotifier(List.of(defaults));
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      order.value = normalise(prefs.getStringList(_key));
    } catch (_) {}
  }

  /// A saved order, cleaned: unknown ids dropped, sections added in a later
  /// release appended in their default place, nothing listed twice.
  static List<String> normalise(List<String>? saved) {
    if (saved == null || saved.isEmpty) return List.of(defaults);
    final out = <String>[];
    for (final id in saved) {
      if (sections.containsKey(id) && !out.contains(id)) out.add(id);
    }
    for (final id in defaults) {
      if (!out.contains(id)) {
        final at = defaults.indexOf(id);
        out.insert(at.clamp(0, out.length), id);
      }
    }
    return out;
  }

  Future<void> set(List<String> ids) async {
    order.value = normalise(ids);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_key, order.value);
    } catch (_) {}
  }

  Future<void> reset() => set(List.of(defaults));
}
