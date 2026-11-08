import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../core/log.dart';
import '../features/assistant/state/assistant_engine.dart';
import '../features/assistant/state/assistant_state.dart';
import '../features/briefing/brief_player.dart';

/// ─────────────────────────────────────────────────────────────────────────
///  THE SCREEN STAYS ON WHILE SHE TALKS (owner, 2026-11-04: "the phone
///  should not go to sleep when the user is using it or the AI is talking
///  — sometimes it talks more than a minute").
///
///  Touching the screen already resets Android's sleep timer; what blanked
///  it was a long spoken answer with nobody touching. So the screen is kept
///  on (FLAG_KEEP_SCREEN_ON, "hari/device" keepScreenOn) for as long as any
///  reason holds:
///    * 'assistant' — a voice conversation is running, or the assistant
///      is listening, thinking, working or speaking;
///    * 'brief'     — Play my day is reading aloud;
///    * any other  — a screen that needs it (the meeting recorder, the ID
///      video) holds its own reason through [hold] / [release].
///
///  One owner for the flag, so one reason ending never switches the screen
///  off under another. When the last reason ends, the flag is kept for a
///  short [_grace]: Android counts its timeout from the last touch, so
///  clearing it the moment she stops would blank the screen at once.
/// ─────────────────────────────────────────────────────────────────────────
class ScreenAwake {
  ScreenAwake._();
  static final ScreenAwake instance = ScreenAwake._();

  static const _device = MethodChannel('hari/device');
  static const _grace = Duration(seconds: 45);

  final Set<String> _reasons = {};
  bool _on = false;
  Timer? _release;
  bool _watching = false;

  /// Keep the screen on for [reason] until [release] is called with it.
  void hold(String reason) {
    _reasons.add(reason);
    _sync();
  }

  void release(String reason) {
    if (_reasons.remove(reason)) _sync();
  }

  /// Start following the assistant and the brief player (once, at start).
  void watch() {
    if (_watching) return;
    _watching = true;
    final engine = AssistantEngine.instance;
    final brief = BriefPlayer.instance;
    void assistant() => _set('assistant', _assistantBusy(engine));
    void reading() => _set(
        'brief',
        brief.state == BriefPlayState.playing ||
            brief.state == BriefPlayState.loading);
    engine.addListener(assistant);
    brief.addListener(reading);
    assistant();
    reading();
  }

  @visibleForTesting
  static bool assistantBusy(bool liveActive, AssistantPhase phase) =>
      liveActive ||
      !(phase == AssistantPhase.idle ||
          phase == AssistantPhase.completed ||
          phase == AssistantPhase.error);

  static bool _assistantBusy(AssistantEngine e) =>
      assistantBusy(e.liveActive, e.phase);

  void _set(String reason, bool on) => on ? hold(reason) : release(reason);

  void _sync() {
    if (_reasons.isNotEmpty) {
      _release?.cancel();
      _release = null;
      if (!_on) {
        _on = true;
        _apply(true);
      }
      return;
    }
    if (!_on || _release != null) return;
    _release = Timer(_grace, () {
      _release = null;
      if (_reasons.isEmpty && _on) {
        _on = false;
        _apply(false);
      }
    });
  }

  void _apply(bool on) {
    AppLog.add('screen', on ? 'kept on' : 'may sleep');
    _device.invokeMethod('keepScreenOn', {'on': on}).catchError((_) => null);
  }
}
