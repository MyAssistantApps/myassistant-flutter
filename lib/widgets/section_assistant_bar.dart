import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ai/assistant_role.dart';
import '../design/neon_tokens.dart';
import '../design/neon_widgets.dart';
import '../features/assistant/state/assistant_engine.dart';
import '../features/assistant/state/assistant_state.dart';
import '../services/app_feedback.dart';
import '../services/auth_service.dart';
import 'inline_voice.dart' show pickAskPhotoSource;
import 'role_mic_orb.dart';

/// A SPEAKER AND A CAMERA IN EVERY SECTION (client, 2026-11-22: "hotel
/// bookings, flight searches, doctor, lawyer assistance and other services
/// require a speaker to interact with users effectively … speaker and a
/// camera is a must in each section").
///
/// The pair the professional pages already carry, for any section: the mic
/// orb talks as that section's assistant ([role]); the camera takes or
/// picks a photo (a ticket, a booking, a place, a label) and asks that same
/// assistant about it, in the voice conversation, out loud.
class SectionAssistantBar extends StatefulWidget {
  const SectionAssistantBar({
    super.key,
    required this.role,
    required this.title,
    required this.line,
    required this.photoQuestion,
    this.tint,
  });

  /// Who the orb and the camera talk to ("the Hotels Assistant").
  final AssistantRole role;

  /// The card's heading ("Ask the Hotels Assistant").
  final String title;

  /// One line under it: what to say or show.
  final String line;

  /// Asked with the photo ("Help me with my hotel stay using this photo.").
  final String photoQuestion;

  final Color? tint;

  @override
  State<SectionAssistantBar> createState() => _SectionAssistantBarState();
}

class _SectionAssistantBarState extends State<SectionAssistantBar> {
  final _engine = AssistantEngine.instance;
  bool _busy = false;

  static bool _runningOn(AssistantEngine e) =>
      e.starting ||
      e.inlineVoice ||
      e.liveActive ||
      (e.phase != AssistantPhase.idle && e.phase != AssistantPhase.completed);

  Future<void> _camera() async {
    if (_busy) return;
    HapticFeedback.selectionClick();
    final source = await pickAskPhotoSource(context);
    if (source == null || !mounted) return;
    setState(() => _busy = true);
    try {
      // The same assistant the orb talks as; the conversation opens if it
      // is not already on, so the answer is seen and heard where it is.
      await _engine.useRole(widget.role);
      if (!_runningOn(_engine)) {
        await _engine.beginInlineConversation(
            name: AuthService.instance.user?.name);
      }
      // The photo goes in once the voice is up (the type bar's "+" waits
      // for the same thing).
      final until = DateTime.now().add(const Duration(seconds: 8));
      while ((_engine.starting || _engine.connecting) &&
          DateTime.now().isBefore(until)) {
        await Future<void>.delayed(const Duration(milliseconds: 150));
      }
      final ok =
          await _engine.askWithPhoto(source, question: widget.photoQuestion);
      if (!ok) {
        AppFeedback.toast('Unable to load the picture. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static Widget _fit(Widget child) => SizedBox(
      width: 68, child: FittedBox(fit: BoxFit.scaleDown, child: child));

  @override
  Widget build(BuildContext context) {
    final tint = widget.tint ?? Neon.violet;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Neon.rLg),
        gradient: Neon.glassFill,
        border: Border.all(color: tint.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.title,
                    style: NeonType.manrope(16, FontWeight.w800)
                        .copyWith(color: Neon.textHi)),
                const SizedBox(height: 4),
                Text(widget.line,
                    style: TextStyle(
                        color: Neon.textLo, fontSize: 13, height: 1.3)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Fixed widths: with a large font setting the captions would
          // otherwise widen the pair and squeeze the words beside them.
          _fit(_CameraButton(tint: tint, busy: _busy, onTap: _camera)),
          const SizedBox(width: 12),
          _fit(RoleMicOrb(
              role: widget.role, tint: tint, size: 52, labelColor: Neon.textHi)),
        ],
      ),
    );
  }
}

/// THE BAR STAYS PUT (client, 2026-11-22: it "should not hide when we scroll
/// down"): [bar] is pinned at the top of the section and only [list]
/// scrolls under it.
class PinnedSectionBar extends StatelessWidget {
  const PinnedSectionBar({super.key, required this.bar, required this.list});

  final SectionAssistantBar bar;

  /// The section's scrolling content (its own top padding starts below
  /// the bar).
  final Widget list;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 0), child: bar),
        Expanded(child: list),
      ],
    );
  }
}

/// The camera beside the orb: the same size and caption line, so the two
/// read as a pair (as on the professional pages).
class _CameraButton extends StatelessWidget {
  const _CameraButton(
      {required this.tint, required this.busy, required this.onTap});
  final Color tint;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Show the assistant a photo: take one or select from the gallery',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: busy ? null : onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: Neon.glassFill,
                border:
                    Border.all(color: tint.withValues(alpha: 0.7), width: 1.4),
                boxShadow: Neon.halo(tint, strength: 0.5),
              ),
              child: busy
                  ? const Center(
                      child: NeonLoader.inline(semanticLabel: 'Working'))
                  : Icon(Icons.photo_camera_rounded,
                      color: Neon.textHi, size: 22),
            ),
            const SizedBox(height: 6),
            Text('Camera',
                style: TextStyle(
                    color: Neon.textHi,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

/// Each section's assistant, in the professional pages' words.
abstract final class SectionRoles {
  static const flights = AssistantRole(
      'the Flights Assistant',
      'You help the owner plan and book flights: routes, dates, fares, '
          'airlines, baggage, web check-in and boarding passes.');
  static const buses = AssistantRole(
      'the Buses Assistant',
      'You help the owner find and book bus journeys: routes, operators, '
          'timings, seats, fares and boarding points.');
  static const hotels = AssistantRole(
      'the Hotels Assistant',
      'You help the owner find and book stays: hotels, resorts and Airbnb '
          'homes — where to stay, dates, guests, rooms, prices and '
          'what a booking includes.');
  static const services = AssistantRole(
      'the Services Assistant',
      'You help the owner with everyday services: fashion, beauty, '
          'medicines, groceries, moving, repairs and other bookings — which '
          'service fits and how to get it done.');
  static const prices = AssistantRole(
      'the Price Compare Assistant',
      'You help the owner compare product prices across shops: which '
          'product, where it is cheapest, offers, delivery and whether it '
          'fits their budget.');
}
