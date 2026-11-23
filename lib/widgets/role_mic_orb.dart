import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ai/assistant_role.dart';
import '../features/assistant/state/assistant_engine.dart';
import '../features/assistant/state/assistant_state.dart';
import '../services/auth_service.dart';
import 'inline_voice.dart' show orbMoodFor;
import 'neuron_orb.dart';
import 'voice_orb.dart' show OrbMood;

/// THE ASSISTANT'S OWN MIC (owner, 2026-11-02: "in front of that Doctor's
/// text I need a mic orb that talks as a Doctor's Assistant"). Tap: the
/// voice conversation starts as [role]; tap again: it ends. The neuron orb
/// shows what the voice is doing, with a word under it. Leaving the page
/// ends a conversation it started and hands the everyday assistant back.
class RoleMicOrb extends StatefulWidget {
  const RoleMicOrb({
    super.key,
    required this.role,
    required this.tint,
    this.size = 64,
    this.labelColor = Colors.white,
    this.showLabel = true,
    this.endOnDispose = true,
    this.topic,
    this.openingNote,
    this.autoStart = false,
    this.orbBuilder,
  });

  /// The page speaks first: worked out when the conversation starts (so it
  /// can say what is saved by then) and handed to the engine as the
  /// conversation's first turn, in place of the generic hello.
  final String? Function()? openingNote;

  /// Start once on arrival, without a tap (the Jyotish guru greets the user
  /// as the screen opens). Never over a conversation already running.
  final bool autoStart;

  /// The orb's own look (the Jyotish guru's mandala); the neuron orb when
  /// null. Gets whether this orb's conversation is running, what the voice
  /// is doing, and the word for it.
  final Widget Function(
          BuildContext context, bool talking, OrbMood mood, String label)?
      orbBuilder;

  /// What a screen reader says it is about ("Patient Records"), when the
  /// page has more than one orb.
  final String? topic;

  final AssistantRole role;
  final Color tint;
  final double size;
  final Color labelColor;

  /// The word under the orb ("Tap to talk", "Listening…"). Off on a small
  /// orb inside a card, where the orb's own motion shows the state.
  final bool showLabel;

  /// End this orb's conversation when the orb goes away. Off for an orb in
  /// a scrolling grid — a tile scrolled out of view is not the page being
  /// left; the page ends it instead (ProAssistantScreen.dispose).
  final bool endOnDispose;

  @override
  State<RoleMicOrb> createState() => _RoleMicOrbState();
}

class _RoleMicOrbState extends State<RoleMicOrb> {
  final _engine = AssistantEngine.instance;

  @override
  void initState() {
    super.initState();
    _engine.addListener(_changed);
    if (widget.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_runningOn(_engine)) unawaited(_start());
      });
    }
  }

  @override
  void dispose() {
    _engine.removeListener(_changed);
    if (_mine && widget.endOnDispose) {
      final e = _engine;
      unawaited(() async {
        if (_runningOn(e)) await e.endInlineConversation();
        await e.useRole(null);
      }());
    }
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  bool get _mine => AssistantRole.current.value == widget.role;

  static bool _runningOn(AssistantEngine e) =>
      e.starting ||
      e.inlineVoice ||
      e.liveActive ||
      (e.phase != AssistantPhase.idle && e.phase != AssistantPhase.completed);

  bool get _talking => _mine && _runningOn(_engine);

  Future<void> _tap() async {
    HapticFeedback.mediumImpact();
    if (_runningOn(_engine)) {
      // One tap stops, always — the same rule as the dock mic.
      await _engine.endInlineConversation();
      return;
    }
    await _start();
  }

  Future<void> _start() async {
    await _engine.useRole(widget.role);
    await _engine.beginInlineConversation(
        name: AuthService.instance.user?.name,
        openingNote: widget.openingNote?.call());
  }

  String _label(OrbMood mood) {
    if (!_talking) return 'Tap to talk';
    return switch (mood) {
      OrbMood.speaking => 'Speaking…',
      OrbMood.connecting => 'Connecting…',
      OrbMood.thinking || OrbMood.responding => 'Thinking…',
      OrbMood.listening => 'Listening…',
      _ => 'Tap to stop',
    };
  }

  @override
  Widget build(BuildContext context) {
    final talking = _talking;
    final mood = talking ? orbMoodFor(_engine) : OrbMood.idle;
    final s = widget.size;
    final label = _label(mood);
    final custom = widget.orbBuilder;
    final about = widget.topic == null ? '' : ' about ${widget.topic}';
    return Semantics(
      container: true,
      button: true,
      label: talking
          ? 'Stop speaking to ${widget.role.name}'
          : 'Speak to ${widget.role.name}$about',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _tap,
        child: custom != null
            ? custom(context, talking, mood, label)
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: s,
                    height: s,
                    child: Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        // A soft disc behind, so the orb reads over any photo.
                        Container(
                          width: s,
                          height: s,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black.withValues(alpha: 0.35),
                            border: Border.all(
                                color: widget.tint.withValues(alpha: 0.7),
                                width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                  color: widget.tint
                                      .withValues(alpha: talking ? 0.6 : 0.35),
                                  blurRadius: talking ? 22 : 14),
                            ],
                          ),
                        ),
                        Positioned(
                          left: -s * 0.25,
                          right: -s * 0.25,
                          top: -s * 0.25,
                          bottom: -s * 0.25,
                          child: IgnorePointer(
                            child: NeuronOrb(
                              radius: s * 0.28,
                              mood: mood,
                              levelListenable:
                                  talking ? _engine.micLevelListenable : null,
                              speakerLevel:
                                  talking ? _engine.speakerLevelNow : null,
                              active: talking,
                            ),
                          ),
                        ),
                        if (!talking)
                          Icon(Icons.mic_rounded,
                              color: Colors.white, size: s * 0.38),
                      ],
                    ),
                  ),
                  if (widget.showLabel) ...[
                    const SizedBox(height: 6),
                    Text(label,
                        style: TextStyle(
                            color: widget.labelColor,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700)),
                  ],
                ],
              ),
      ),
    );
  }
}
