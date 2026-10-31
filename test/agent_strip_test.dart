// The nine agents on the home screen: ready while idle, lit while they work
// (lib/widgets/agent_strip.dart).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myassistant/ai/types.dart';
import 'package:myassistant/features/assistant/state/assistant_engine.dart';
import 'package:myassistant/widgets/agent_strip.dart';

Widget _host() => const MaterialApp(home: Scaffold(body: Padding(padding: EdgeInsets.all(16), child: AgentStrip())));

void main() {
  final engine = AssistantEngine.instance;
  tearDown(() => engine.agentControl.value = null);

  test('the roster is the manager plus the eight server specialists', () {
    expect(agentRoster.map((a) => a.id), [
      'manager', 'comms', 'planner', 'info', 'commerce', 'creative', 'device', 'memory', 'records',
    ]);
  });

  testWidgets('idle: all nine shown, ready', (tester) async {
    await tester.pumpWidget(_host());
    expect(find.text('9 agents ready'), findsOneWidget);
    for (final a in agentRoster) {
      expect(find.byIcon(a.icon), findsOneWidget);
    }
  });

  testWidgets('working: the caption names who has control, then who runs the tool', (tester) async {
    await tester.pumpWidget(_host());
    const control = AgentControl(
      via: 'rules',
      agents: [(id: 'planner', label: 'Planning')],
      toolAgent: {'create_reminder': 'planner'},
    );
    engine.agentControl.value = (control: control, running: null, done: const {}, over: false);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Manager → Planning'), findsOneWidget);
    engine.agentControl.value = (control: control, running: 'Planning', done: const {}, over: false);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Planning agent working'), findsOneWidget);
    engine.agentControl.value = null;
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('9 agents ready'), findsOneWidget);
  });

  testWidgets('tap: the list of who does what', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_host());
    await tester.tap(find.byType(AgentStrip));
    await tester.pumpAndSettle();
    expect(find.text('Your agents'), findsOneWidget);
    expect(find.text('Manager'), findsOneWidget);
    // Every agent is in the list (the test font is taller than a phone's,
    // so the last ones are scrolled to rather than assumed on screen).
    await tester.scrollUntilVisible(find.text('Records'), 120, scrollable: find.byType(Scrollable).last);
    expect(find.text('Records'), findsOneWidget);
    expect(find.text('Working'), findsNothing);
  });
}
