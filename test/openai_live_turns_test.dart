import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:myassistant/ai/openai_live.dart';

void main() {
  test('a new realtime session is told to answer a finished question at once', () async {
    final incoming = StreamController<dynamic>();
    final sent = <Map<String, dynamic>>[];
    final session = OpenAiLiveSession(
      incoming.stream,
      (s) => sent.add(jsonDecode(s) as Map<String, dynamic>),
      () async {},
    );
    incoming.add(jsonEncode({'type': 'session.created'}));
    await session.ready;
    // The acknowledgement of our own update does not tune it again.
    incoming.add(jsonEncode({'type': 'session.updated'}));
    await Future<void>.delayed(Duration.zero);

    final updates = sent.where((e) => e['type'] == 'session.update').toList();
    expect(updates, hasLength(1));
    final turn = updates.single['session']['audio']['input']['turn_detection'] as Map;
    expect(turn['type'], 'semantic_vad');
    expect(turn['eagerness'], 'medium');
    expect(turn['interrupt_response'], false);
    expect(turn['create_response'], true);
    expect(updates.single['session']['audio']['output']['speed'], 1.0);
    await incoming.close();
  });

  test('cut off mid-reply, the model is told how much was heard', () async {
    final incoming = StreamController<dynamic>();
    final sent = <Map<String, dynamic>>[];
    final session = OpenAiLiveSession(
      incoming.stream,
      (s) => sent.add(jsonDecode(s) as Map<String, dynamic>),
      () async {},
    );
    incoming.add(jsonEncode({'type': 'session.created'}));
    await session.ready;
    // Nothing spoken yet: nothing to cut short.
    session.truncateHeard(500);
    expect(sent.where((e) => e['type'] == 'conversation.item.truncate'), isEmpty);
    incoming.add(jsonEncode({'type': 'response.created'}));
    incoming.add(jsonEncode({
      'type': 'response.output_audio.delta',
      'item_id': 'item_42',
      'delta': base64Encode(List<int>.filled(480, 0)),
    }));
    await Future<void>.delayed(Duration.zero);
    session.cancelReply();
    session.truncateHeard(1200);
    expect(sent.any((e) => e['type'] == 'response.cancel'), isTrue);
    final cut = sent.singleWhere((e) => e['type'] == 'conversation.item.truncate');
    expect(cut['item_id'], 'item_42');
    expect(cut['content_index'], 0);
    expect(cut['audio_end_ms'], 1200);
    await incoming.close();
  });
}
