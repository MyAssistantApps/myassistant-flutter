// A round of pure reads runs its tool calls at the same time; a round with
// anything else in it runs in order (lib/ai/cloud.dart, 2026-10-31).
import 'dart:async';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myassistant/ai/cloud.dart';
import 'package:myassistant/ai/tool_server.dart';
import 'package:myassistant/ai/types.dart';

import 'fakes.dart';

const _tools = [
  AiToolSpec(name: 'get_weather'),
  AiToolSpec(name: 'web_search'),
  AiToolSpec(name: 'create_reminder'),
];

CloudRequest _request(Set<String> parallelSafe) => CloudRequest(
      model: 'test-model',
      text: 'weather in Pune and Delhi',
      tools: _tools,
      parallelSafe: parallelSafe,
    );

FakeModel _twoCalls(String a, String b) => FakeModel([
      partsChunk([
        FunctionCall(a, {'city': 'Pune'}, id: 'c1'),
        FunctionCall(b, {'city': 'Delhi'}, id: 'c2'),
      ]),
      textChunk('Done.'),
    ]);

/// Runs a turn whose tools each take [each]; returns how many ran at once
/// at the peak and the order the answers went back to the model.
Future<({int peak, List<String> order, FakeModel model})> _run(
  FakeModel model,
  Set<String> parallelSafe, {
  Duration each = const Duration(milliseconds: 40),
}) async {
  var running = 0;
  var peak = 0;
  final events = <CloudEvent>[];
  await for (final e in CloudEngine(model).turn(
    _request(parallelSafe),
    runTool: (name, args) async {
      running++;
      if (running > peak) peak = running;
      await Future<void>.delayed(each);
      running--;
      return {'ok': true, 'tool': name, 'city': args['city']};
    },
  )) {
    events.add(e);
  }
  final second = model.requests[1].contents.last;
  final order = [
    for (final p in second.parts)
      if (p is FunctionResponse) '${p.name}:${p.response['city']}',
  ];
  return (peak: peak, order: order, model: model);
}

void main() {
  test('two pure reads run at the same time, answers in call order', () async {
    final r = await _run(_twoCalls('get_weather', 'web_search'), {'get_weather', 'web_search'});
    expect(r.peak, 2);
    expect(r.order, ['get_weather:Pune', 'web_search:Delhi']);
  });

  test('a round with a write in it runs in order', () async {
    final r = await _run(_twoCalls('get_weather', 'create_reminder'), {'get_weather', 'web_search'});
    expect(r.peak, 1);
    expect(r.order, ['get_weather:Pune', 'create_reminder:Delhi']);
  });

  test('without the server saying so, nothing runs in parallel', () async {
    final r = await _run(_twoCalls('get_weather', 'web_search'), const {});
    expect(r.peak, 1);
  });

  test('a failing read is reported to the model and does not stop the other', () async {
    final model = _twoCalls('get_weather', 'web_search');
    final engine = CloudEngine(model);
    await engine
        .turn(
          _request({'get_weather', 'web_search'}),
          runTool: (name, args) async {
            if (name == 'get_weather') throw StateError('weather down');
            return {'ok': true};
          },
        )
        .drain<void>();
    final parts = model.requests[1].contents.last.parts.whereType<FunctionResponse>().toList();
    expect(parts.map((p) => p.name), ['get_weather', 'web_search']);
    expect(parts[0].response['ok'], false);
    expect(parts[1].response['ok'], true);
  });

  test('the server list is read from /ai/context', () {
    final ctx = AiContext.fromJson({
      'sessionId': 's',
      'turnId': 't',
      'tools': [],
      'parallelSafe': ['get_weather', 3, 'web_search'],
    });
    expect(ctx.parallelSafe, {'get_weather', 'web_search'});
    expect(AiContext.fromJson({}).parallelSafe, isEmpty);
  });
}
