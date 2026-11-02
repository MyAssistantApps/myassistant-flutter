import 'dart:async';

import 'package:flutter/services.dart';

import 'api_service.dart';

/// THE PHONE'S HANDS IN OTHER APPS (owner, 2026-11-01: "should be able to
/// open any app I asked for and do task", with confirmations).
///
/// [ScreenAgent] talks to ScreenAgentService.kt (Settings → Accessibility →
/// "MyAssistant screen control"); [ScreenTaskRunner] runs one task as a
/// loop: read the screen, ask the server for ONE step (POST
/// /ai/screen/step, backend ai/screenTask.js), ask the owner first when
/// the step sends, pays, orders or deletes, do it, and again — until done,
/// failed, stopped by the owner, stuck, or [ScreenTaskRunner.maxSteps].
abstract interface class ScreenHands {
  Future<bool> enabled();
  Future<Map<String, Object?>?> dump();

  /// Null when done; otherwise why it could not be.
  Future<String?> act(String action, {int? node, String? text, String? direction});
  Future<void> status(String say);
  Future<bool> confirm(String question);
  Future<bool> stopRequested();
  Future<void> hide();
}

class ScreenAgent implements ScreenHands {
  const ScreenAgent();
  static const _ch = MethodChannel('hari/screen');

  @override
  Future<bool> enabled() async => (await _ch.invokeMethod<bool>('enabled')) ?? false;

  Future<void> openSettings() => _ch.invokeMethod<bool>('openSettings');

  @override
  Future<Map<String, Object?>?> dump() async {
    final m = await _ch.invokeMethod<Map<Object?, Object?>>('dump');
    return m?.map((k, v) => MapEntry('$k', v));
  }

  @override
  Future<String?> act(String action, {int? node, String? text, String? direction}) =>
      _ch.invokeMethod<String>('act',
          {'action': action, 'node': node, 'text': text, 'direction': direction});

  @override
  Future<void> status(String say) => _ch.invokeMethod<bool>('status', {'say': say});

  @override
  Future<bool> confirm(String question) async =>
      (await _ch.invokeMethod<bool>('confirm', {'question': question})) ?? false;

  @override
  Future<bool> stopRequested() async => (await _ch.invokeMethod<bool>('stopRequested')) ?? true;

  @override
  Future<void> hide() => _ch.invokeMethod<bool>('hide');
}

/// How a task ended, in a sentence for the assistant to say.
class ScreenTaskResult {
  const ScreenTaskResult(this.ok, this.summary, {this.steps = 0});
  final bool ok;
  final String summary;
  final int steps;
}

typedef ScreenStep = Future<Map<String, dynamic>?> Function(
    String goal, Map<String, Object?> screen, List<Map<String, Object?>> history);

class ScreenTaskRunner {
  ScreenTaskRunner({
    this.hands = const ScreenAgent(),
    ScreenStep? step,
    this.maxSteps = 25,
    this.settle = const Duration(milliseconds: 900),
  }) : _step = step ?? _serverStep;

  final ScreenHands hands;
  final ScreenStep _step;
  final int maxSteps;

  /// How long the app gets to react to a step before the screen is read again.
  final Duration settle;

  static Future<Map<String, dynamic>?> _serverStep(
          String goal, Map<String, Object?> screen, List<Map<String, Object?>> history) =>
      ApiService.postJson('/ai/screen/step', {'goal': goal, 'screen': screen, 'history': history});

  static String _sig(Map<String, Object?> screen) {
    final nodes = (screen['nodes'] as List?) ?? const [];
    return '${screen['pkg']}|${nodes.length}|${nodes.map((n) => n is Map ? '${n['text']}${n['desc']}' : '').join('|').hashCode}';
  }

  Future<ScreenTaskResult> run(String goal, {String app = ''}) async {
    final history = <Map<String, Object?>>[];
    var unchanged = 0;
    var waits = 0;
    try {
      await hands.status('Working in ${app.isEmpty ? 'the app' : app}…');
      for (var n = 1; n <= maxSteps; n++) {
        if (await hands.stopRequested()) {
          return ScreenTaskResult(false, 'They tapped Stop, so I stopped.', steps: n - 1);
        }
        final screen = await hands.dump();
        if (screen == null) {
          return ScreenTaskResult(false, 'Screen control is switched off.', steps: n - 1);
        }
        screen['app'] = app;
        final step = await _step(goal, screen, history);
        if (step == null) {
          return ScreenTaskResult(false, "I couldn't reach the server to work out the next step.", steps: n - 1);
        }
        final action = '${step['action'] ?? 'fail'}';
        final say = '${step['say'] ?? ''}'.trim();
        if (say.isNotEmpty) await hands.status(say);
        if (action == 'done') {
          return ScreenTaskResult(true, '${step['result'] ?? 'Done.'}', steps: n - 1);
        }
        if (action == 'fail') {
          return ScreenTaskResult(false, '${step['result'] ?? "I couldn't finish it."}', steps: n - 1);
        }
        if (action == 'wait') {
          if (++waits > 4) return ScreenTaskResult(false, 'The app kept loading, so I stopped.', steps: n);
          await Future<void>.delayed(settle * 2);
          continue;
        }
        waits = 0;
        // ASK FIRST: anything that sends, pays, orders or deletes.
        if (step['sensitive'] == true) {
          final ok = await hands.confirm(say.isEmpty ? 'Go ahead with this step?' : say);
          if (!ok) return ScreenTaskResult(false, 'They said no at the last step, so nothing was sent or paid.', steps: n - 1);
        }
        final before = _sig(screen);
        final node = step['node'] is num ? (step['node'] as num).toInt() : null;
        final why = await hands.act(action,
            node: node, text: step['text'] as String?, direction: step['direction'] as String?);
        await Future<void>.delayed(settle);
        final after = await hands.dump();
        final changed = why == null && after != null && _sig(after) != before;
        history.add({'action': action, 'node': node, 'text': step['text'], 'say': say, 'changed': changed,
          if (why != null) 'error': why});
        // STUCK: three steps in a row that changed nothing.
        unchanged = changed || action == 'type' ? 0 : unchanged + 1;
        if (unchanged >= 3) return ScreenTaskResult(false, 'I got stuck on that screen, so I stopped.', steps: n);
      }
      return ScreenTaskResult(false, 'It was taking too many steps, so I stopped.', steps: maxSteps);
    } on PlatformException catch (e) {
      return ScreenTaskResult(false, 'Screen control failed: ${e.message ?? e.code}.');
    } finally {
      await hands.hide();
    }
  }
}
