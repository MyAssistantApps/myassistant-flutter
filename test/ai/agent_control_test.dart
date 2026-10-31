// What the owner is shown about who has control of a turn: the server's
// manager agent and the specialists it chose (lib/ai/types.dart).
import 'package:flutter_test/flutter_test.dart';
import 'package:myassistant/ai/tool_server.dart';
import 'package:myassistant/ai/types.dart';

void main() {
  final json = {
    'via': 'rules',
    'agents': [
      {'id': 'commerce', 'label': 'Shopping and money'},
      {'id': 'comms', 'label': 'Communication'},
      {'id': 7, 'label': 'broken'},
    ],
    'toolAgent': {'order_food': 'commerce', 'send_agent_message': 'comms', 'x': 3},
  };

  test('reads the manager decision, skipping malformed entries', () {
    final c = AgentControl.fromJson(json)!;
    expect(c.via, 'rules');
    expect(c.agents.map((a) => a.id), ['commerce', 'comms']);
    expect(c.toolAgent, {'order_food': 'commerce', 'send_agent_message': 'comms'});
    expect(c.skipped, isFalse);
  });

  test('says who has control, and who runs each tool', () {
    final c = AgentControl.fromJson(json)!;
    expect(c.summary, 'Manager → Shopping and money + Communication');
    expect(c.labelFor('order_food'), 'Shopping and money');
    expect(c.labelFor('send_agent_message'), 'Communication');
    expect(c.labelFor('web_search'), isNull);
  });

  test('no specialist: the manager itself has control', () {
    final c = AgentControl.fromJson({'via': 'none', 'agents': []})!;
    expect(c.summary, 'Manager');
    expect(c.skipped, isFalse);
  });

  test('a skipped turn and an older server show nothing', () {
    expect(AgentControl.fromJson({'via': 'skip'})!.skipped, isTrue);
    expect(AgentControl.fromJson(null), isNull);
    expect(AiContext.fromJson({'sessionId': 's'}).manager, isNull);
  });

  test('/ai/context carries it', () {
    final ctx = AiContext.fromJson({'sessionId': 's', 'turnId': 't', 'manager': json});
    expect(ctx.manager!.summary, startsWith('Manager → Shopping'));
  });
}
