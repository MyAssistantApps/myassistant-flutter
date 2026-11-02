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
  });

  final AssistantRole role;
  final Color tint;
  final double size;
  final Color labelColor;

  @override
  State<RoleMicOrb> createState() => _RoleMicOrbState();
}

class _RoleMicOrbState extends State<RoleMicOrb> {
  final _engine = AssistantEngine.instance;

  @override
  void initState() {
    super.initState();
    _engine.addListener(_changed);
  }

  @override
  void dispose() {
    _engine.removeListener(_changed);
    if (_mine) {
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
    await _engine.useRole(widget.role);
    await _engine.beginInlineConversation(
        name: AuthService.instance.user?.name);
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
    return Semantics(
      button: true,
      label: talking
          ? 'Stop talking to ${widget.role.name}'
          : 'Talk to ${widget.role.name}',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _tap,
        child: Column(
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
                        speakerLevel: talking ? _engine.speakerLevelNow : null,
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
            const SizedBox(height: 6),
            Text(label,
                style: TextStyle(
                    color: widget.labelColor,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
