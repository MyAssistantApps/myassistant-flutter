import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../design/motion.dart';

import '../design/apple_kit.dart';
import '../services/app_feedback.dart';
import '../services/overlay_bridge.dart';

/// ─────────────────────────────────────────────────────────────────────────
///  OVER OTHER APPS (2026-10-19, owner): the two switches on the You tab.
///
///  • Notification pop-ups — every new notification is sorted by the
///    assistant: a message gets a pop-up that listens for the reply and
///    sends it after 3 seconds; something worth seeing gets a short pop-up;
///    a lasting fact goes to Memory. Needs Notification access and
///    "Display over other apps", which Android only grants on its own pages.
///  • Floating mic — the orb over other apps; a tap opens a conversation.
///
///  A switch shows on only when Android has granted what it needs, so the
///  page never claims something that is not working. Coming back from
///  Android's page refreshes it.
/// ─────────────────────────────────────────────────────────────────────────
class OverlaySection extends StatefulWidget {
  const OverlaySection({super.key});

  @override
  State<OverlaySection> createState() => _OverlaySectionState();
}

class _OverlaySectionState extends State<OverlaySection> with WidgetsBindingObserver {
  OverlayStatus _s = const OverlayStatus();

  /// What the owner was turning on when they went to Android's page.
  String? _wanted;

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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_refresh(finish: true));
  }

  Future<void> _refresh({bool finish = false}) async {
    var s = await OverlayBridge.status();
    // Back from Android's page with what was missing: finish what they began.
    if (finish && _wanted != null) {
      final w = _wanted;
      _wanted = null;
      if (w == 'replies') await _setReplies(true, status: s);
      if (w == 'bubble') await _setBubble(true, status: s);
      s = await OverlayBridge.status();
    }
    if (mounted) setState(() => _s = s);
  }

  Future<void> _setReplies(bool on, {OverlayStatus? status}) async {
    HapticFeedback.selectionClick();
    final s = status ?? _s;
    if (on && !s.overlay) {
      _wanted = 'replies';
      _say('Allow "Display over other apps" for Hari Assistant, then come back.');
      await OverlayBridge.openOverlaySettings();
      return;
    }
    if (on && !s.notifications) {
      // Android 13+ shows "Restricted setting" for an app installed outside
      // the Play Store until it is allowed on the app's info page — every
      // tester's case (measured on the owner's phone, 2026-10-19).
      final pick = await showAppDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Allow notification access'),
          content: const Text(
            'On the next screen, turn on Notification access for Hari Assistant.\n\n'
            'If Android says "Restricted setting": open App info, tap ⋮ at the top right, '
            'choose "Allow restricted settings", then come back and turn this on again.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, 'info'), child: const Text('Open App info')),
            TextButton(onPressed: () => Navigator.pop(ctx, 'access'), child: const Text('Continue')),
          ],
        ),
      );
      if (pick == null) return;
      _wanted = 'replies';
      if (pick == 'info') {
        await openAppSettings();
      } else {
        await OverlayBridge.openNotificationAccess();
      }
      return;
    }
    await OverlayBridge.setReplies(on);
    await _refresh();
  }

  Future<void> _setBubble(bool on, {OverlayStatus? status}) async {
    HapticFeedback.selectionClick();
    final s = status ?? _s;
    if (on && !s.overlay) {
      _wanted = 'bubble';
      _say('Allow "Display over other apps" for Hari Assistant, then come back.');
      await OverlayBridge.openOverlaySettings();
      return;
    }
    await OverlayBridge.setBubble(on);
    await _refresh();
  }

  void _say(String text) {
    if (mounted) AppFeedback.show(text, context: context);
  }

  @override
  Widget build(BuildContext context) {
    final repliesOn = _s.replies && _s.overlay && _s.notifications;
    final bubbleOn = _s.bubble && _s.overlay;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const GroupLabel('Over other apps'),
        GroupedCard(
          dividerInset: 60,
          children: [
            AppleRow(
              leading: IconTile(Icons.notifications_active_rounded, AppleColors.orange),
              title: 'Notification pop-ups',
              titleMaxLines: 2,
              subtitle: 'Reads new notifications: offers to reply to messages by voice, '
                  'flags what matters and keeps lasting details in Memory. '
                  'Codes and passwords never leave the phone.',
              trailing: Switch(value: repliesOn, onChanged: (v) => _setReplies(v)),
            ),
            AppleRow(
              leading: IconTile(Icons.mic_rounded, AppleColors.purple),
              title: 'Floating mic',
              subtitle: 'The orb over other apps — tap it to talk',
              trailing: Switch(value: bubbleOn, onChanged: (v) => _setBubble(v)),
            ),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
