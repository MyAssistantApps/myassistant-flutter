// "Call your manager": the name under the orb follows who has the turn —
// the assistant, the agent asked for, or the specialist at work — and goes
// back to the assistant when the turn is done.
import 'package:flutter_test/flutter_test.dart';
import 'package:myassistant/ai/tool_server.dart';
import 'package:myassistant/ai/types.dart';
import 'package:myassistant/widgets/inline_voice.dart' show speakerFor;

AgentTurn _turn({String? persona, String? running, bool over = false, AgentControl? control}) => (
      control: control ?? const AgentControl(via: 'rules'),
      running: running,
      done: const <String>{},
      over: over,
      persona: persona,
    );

void main() {
  test('by default the assistant speaks', () {
    expect(speakerFor(null, 'Maya'), 'Maya');
    expect(speakerFor(_turn(), 'Maya'), 'Maya');
  });

  test('the agent asked for answers in person', () {
    expect(speakerFor(_turn(persona: 'Manager'), 'Maya'), 'Manager');
    expect(speakerFor(_turn(persona: 'Planning', running: 'Memory'), 'Maya'), 'Planning');
  });

  test('a specialist at work shows its short name', () {
    expect(speakerFor(_turn(running: 'Shopping and money'), 'Maya'), 'Shopping');
    expect(speakerFor(_turn(running: 'Planning'), 'Maya'), 'Planning');
  });

  test('when the turn is done it is the assistant again', () {
    expect(speakerFor(_turn(persona: 'Manager', over: true), 'Maya'), 'Maya');
  });

  test('the server says who was asked for', () {
    final ctx = AiContext.fromJson({
      'sessionId': 's',
      'manager': {
        'via': 'addressed',
        'agents': [],
        'toolAgent': {},
        'addressed': {'id': 'manager', 'label': 'Manager'},
      },
    });
    expect(ctx.manager!.addressed, (id: 'manager', label: 'Manager'));
    expect(AgentControl.fromJson({'via': 'rules'})!.addressed, isNull);
  });

  test('a Live turn adds each agent as its tool runs', () {
    const map = AgentControl(via: 'live', toolAgent: {'get_weather': 'info', 'set_alarm': 'planner'});
    final c = map.withAgent('info').withAgent('planner').withAgent('info');
    expect(c.agents.map((a) => a.id), ['info', 'planner']);
    expect(c.labelFor('set_alarm'), 'Planning');
    expect(c.toolAgent, map.toolAgent);
  });
}
