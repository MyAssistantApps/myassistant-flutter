import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../design/neon_tokens.dart';

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
    'quick_apps': HomeSection('quick_apps', 'Quick Apps',
        'GPay, WhatsApp, YouTube and more', Icons.grid_view_rounded),
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

/// Arrange mode: every section as a compact tile, dragged into place.
class ArrangeHomePanel extends StatefulWidget {
  const ArrangeHomePanel({super.key, required this.onDone, this.highlight});
  final VoidCallback onDone;

  /// The section that was pressed to start arranging.
  final String? highlight;

  @override
  State<ArrangeHomePanel> createState() => _ArrangeHomePanelState();
}

class _ArrangeHomePanelState extends State<ArrangeHomePanel> {
  late List<String> _ids = List.of(HomeLayout.instance.order.value);

  // onReorderItem: [to] is already the index after removal.
  void _move(int from, int to) {
    if (from == to) return;
    setState(() {
      final id = _ids.removeAt(from);
      _ids.insert(to, id);
    });
    HapticFeedback.mediumImpact();
    HomeLayout.instance.set(_ids);
  }

  Future<void> _reset() async {
    HapticFeedback.selectionClick();
    await HomeLayout.instance.reset();
    if (mounted) setState(() => _ids = List.of(HomeLayout.instance.order.value));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      decoration: BoxDecoration(
        color: Neon.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Neon.violet.withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(color: Neon.violet.withValues(alpha: 0.22), blurRadius: 30, spreadRadius: -6),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(colors: [Neon.violet, Neon.accentC]),
              ),
              child: const Icon(Icons.dashboard_customize_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Arrange Your Home',
                    style: NeonType.manrope(17, FontWeight.w800).copyWith(color: Neon.textHi)),
                Text('Press and hold a card, then drag it into place.',
                    style: NeonType.manrope(12.5, FontWeight.w500).copyWith(color: Neon.textLo)),
              ]),
            ),
          ]),
          const SizedBox(height: 12),
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: _ids.length,
            onReorderStart: (_) => HapticFeedback.heavyImpact(),
            onReorderItem: _move,
            proxyDecorator: (child, _, anim) => Material(
              color: Colors.transparent,
              elevation: 10,
              shadowColor: Neon.violet.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
              child: child,
            ),
            itemBuilder: (context, i) {
              final s = HomeLayout.sections[_ids[i]]!;
              final lit = s.id == widget.highlight;
              return ReorderableDelayedDragStartListener(
                key: ValueKey(s.id),
                index: i,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    height: 62,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: (lit ? Neon.violet : Neon.textHi).withValues(alpha: lit ? 0.16 : 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: lit ? Neon.violet.withValues(alpha: 0.6) : Neon.hairline),
                    ),
                    child: Row(children: [
                      Icon(s.icon, color: Neon.violet, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: NeonType.manrope(14.5, FontWeight.w700)
                                    .copyWith(color: Neon.textHi)),
                            Text(s.subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: NeonType.manrope(12, FontWeight.w500)
                                    .copyWith(color: Neon.textLo)),
                          ],
                        ),
                      ),
                      // An immediate handle as well: drag here without waiting.
                      ReorderableDragStartListener(
                        index: i,
                        child: Semantics(
                          label: 'Move ${s.title}',
                          child: SizedBox(
                            width: 48,
                            height: 48,
                            child: Icon(Icons.drag_indicator_rounded, color: Neon.textLo),
                          ),
                        ),
                      ),
                    ]),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 4),
          Row(children: [
            TextButton(onPressed: _reset, child: const Text('Reset to Default')),
            const Spacer(),
            FilledButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                widget.onDone();
              },
              child: const Text('Done'),
            ),
          ]),
        ],
      ),
    );
  }
}
