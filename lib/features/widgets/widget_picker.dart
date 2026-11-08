import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design/neon_tokens.dart';
import '../../services/home_widgets.dart';

/// "ADD WIDGETS TO YOUR HOME SCREEN?" (2026-11-08, Manish: "after opening
/// the app it should ask if we need to add the widgets or not, and display
/// different designs of the widgets").
///
/// Each design is drawn here as it looks on the home screen (the Android
/// layouts in res/layout/widget_*.xml), with its own Add. Add shows
/// Android's own "Add to home screen" dialog; nothing is placed without it.
Future<void> showWidgetPicker(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Neon.bg,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => const _WidgetPicker(),
    );

class _WidgetPicker extends StatefulWidget {
  const _WidgetPicker();

  @override
  State<_WidgetPicker> createState() => _WidgetPickerState();
}

class _WidgetPickerState extends State<_WidgetPicker> with WidgetsBindingObserver {
  final svc = HomeWidgetsService.instance;
  Map<String, int> _placed = const {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Back from the launcher's dialog: show which ones are now placed.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final p = await svc.placed();
    if (mounted) setState(() => _placed = p);
    // The dialog can return before the launcher has placed it.
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    final again = await svc.placed();
    if (mounted) setState(() => _placed = again);
  }

  Future<void> _add(String kind) async {
    HapticFeedback.selectionClick();
    final ok = await svc.pin(kind);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Your launcher can\'t add it from here — long-press your home screen, tap Widgets, '
              'and find MyAssistant.')));
    }
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final designs = [
      ('talk', 'Ask bar', 'One tap and your assistant is listening.', const _TalkPreview()),
      ('day', 'My day', 'Meetings, reminders, bills and what\'s next.', const _DayPreview()),
      ('shortcuts', 'Shortcuts', 'Talk, compare prices, flights, reminders.', const _ShortcutsPreview()),
      ('orb', 'Orb', 'A small orb: tap it and your assistant is listening.', const _OrbPreview()),
    ];
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.86,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.paddingOf(context).bottom),
        children: [
          Text('Add MyAssistant to your home screen',
              style: NeonType.manrope(22, FontWeight.w800).copyWith(color: Neon.textHi, letterSpacing: -0.5)),
          const SizedBox(height: 6),
          Text('Pick the widgets you like — your assistant, one tap away, without opening the app.',
              style: TextStyle(color: Neon.textLo, fontSize: 14, height: 1.35)),
          const SizedBox(height: 18),
          for (final (kind, title, line, preview) in designs) ...[
            _Design(
              title: title,
              line: line,
              preview: preview,
              added: (_placed[kind] ?? 0) > 0,
              onAdd: () => _add(kind),
            ),
            const SizedBox(height: 14),
          ],
          const SizedBox(height: 4),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Not now', style: TextStyle(color: Neon.textLo, fontSize: 15, fontWeight: FontWeight.w600)),
          ),
          Text('You can add them any time: long-press your home screen → Widgets → MyAssistant.',
              textAlign: TextAlign.center, style: TextStyle(color: Neon.textDim, fontSize: 12)),
        ],
      ),
    );
  }
}

/// One design: its picture on a "wallpaper", its name, and Add.
class _Design extends StatelessWidget {
  const _Design({
    required this.title,
    required this.line,
    required this.preview,
    required this.added,
    required this.onAdd,
  });
  final String title;
  final String line;
  final Widget preview;
  final bool added;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: Neon.glassBox(Neon.rCard),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // A wallpaper-ish backdrop, so it reads as "on your home screen".
          Container(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0F2A3D), Color(0xFF2B1B4F), Color(0xFF4A1F3A)],
              ),
            ),
            child: ExcludeSemantics(child: Center(child: preview)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: NeonType.manrope(16, FontWeight.w800).copyWith(color: Neon.textHi)),
                      const SizedBox(height: 2),
                      Text(line, style: TextStyle(color: Neon.textLo, fontSize: 12.5)),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                added
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Neon.success.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(Neon.rPill),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.check_rounded, size: 18, color: Neon.success),
                          const SizedBox(width: 4),
                          Text('Added', style: NeonType.manrope(14, FontWeight.w800).copyWith(color: Neon.success)),
                        ]),
                      )
                    : FilledButton.icon(
                        onPressed: onAdd,
                        icon: const Icon(Icons.add_rounded, size: 20),
                        label: Text('Add', style: NeonType.manrope(14.5, FontWeight.w800)),
                        style: FilledButton.styleFrom(
                          backgroundColor: Neon.accentFill,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── the previews: drawn as res/layout/widget_*.xml draw them ───────────

const _violet = Color(0xFF5B2EFF), _magenta = Color(0xFFB026E0), _orange = Color(0xFFFF7A45);
const _cardGrad = LinearGradient(
    begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF2A1C4D), Color(0xFF15102A)]);
const _iconGrad = LinearGradient(colors: [Color(0xFF7B4DFF), Color(0xFFD03CE8)]);

class _TalkPreview extends StatelessWidget {
  const _TalkPreview();

  @override
  Widget build(BuildContext context) => Container(
        height: 64,
        padding: const EdgeInsets.fromLTRB(10, 0, 18, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          gradient: const LinearGradient(colors: [_violet, _magenta, _orange]),
        ),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: const Icon(Icons.mic_rounded, color: Color(0xFF6B3BFF), size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Ask MyAssistant',
                    maxLines: 1, style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                Text('Tap and speak — I\'ll take care of it',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12)),
              ],
            ),
          ),
          const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 22),
        ]),
      );
}

class _DayPreview extends StatelessWidget {
  const _DayPreview();

  @override
  Widget build(BuildContext context) {
    Widget count(String n, String label) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(children: [
              Text(n, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
              Text(label, maxLines: 1, style: const TextStyle(color: Color(0xFFB9A8E8), fontSize: 11)),
            ]),
          ),
        );
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final now = DateTime.now();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: _cardGrad,
        border: Border.all(color: const Color(0xFF3A2C63)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(now.hour < 12 ? 'Good morning' : now.hour < 17 ? 'Good afternoon' : 'Good evening',
                    style: const TextStyle(color: Color(0xFFB9A8E8), fontSize: 12)),
                Text('${days[now.weekday - 1]}, ${now.day} ${months[now.month - 1]}',
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
              ]),
            ),
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(gradient: _iconGrad, shape: BoxShape.circle),
              child: const Icon(Icons.mic_rounded, color: Colors.white, size: 22),
            ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            count('2', 'Meetings'),
            const SizedBox(width: 8),
            count('3', 'Reminders'),
            const SizedBox(width: 8),
            count('1', 'Bills due'),
          ]),
          const SizedBox(height: 10),
          Text('Next · Team standup · 10:30 AM',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13)),
        ],
      ),
    );
  }
}

class _ShortcutsPreview extends StatelessWidget {
  const _ShortcutsPreview();

  @override
  Widget build(BuildContext context) {
    Widget sc(IconData i, String label) => Expanded(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(gradient: _iconGrad, shape: BoxShape.circle),
              child: Icon(i, color: Colors.white, size: 21),
            ),
            const SizedBox(height: 5),
            Text(label, maxLines: 1, style: const TextStyle(color: Colors.white, fontSize: 11)),
          ]),
        );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: _cardGrad,
        border: Border.all(color: const Color(0xFF3A2C63)),
      ),
      child: Row(children: [
        sc(Icons.mic_rounded, 'Talk'),
        sc(Icons.local_offer_rounded, 'Compare'),
        sc(Icons.flight_rounded, 'Flights'),
        sc(Icons.notifications_rounded, 'Reminders'),
      ]),
    );
  }
}

class _OrbPreview extends StatelessWidget {
  const _OrbPreview();

  @override
  Widget build(BuildContext context) => Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          color: const Color(0xFF120C1C),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFF2A1F3D)),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 50,
            height: 50,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [Color(0xFFB794FF), Color(0xFF6B3BFF)]),
            ),
            child: const Icon(Icons.mic_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 6),
          const Text('Talk', style: TextStyle(color: Color(0xFFCFC4E4), fontSize: 10.5)),
        ]),
      );
}
