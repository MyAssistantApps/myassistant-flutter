// The agents' hexagon on Home (lib/widgets/agent_hive.dart): hold for the
// honeycomb of all nine, tap for the list.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myassistant/ai/types.dart';
import 'package:myassistant/features/assistant/state/assistant_engine.dart';
import 'package:myassistant/widgets/agent_hive.dart';
import 'package:myassistant/widgets/agent_strip.dart';

Widget _host() => const MaterialApp(
    home: Scaffold(body: Center(child: AgentHiveButton())));

void main() {
  final engine = AssistantEngine.instance;
  tearDown(() => engine.agentControl.value = null);

  testWidgets('hold: the honeycomb opens with all nine agents', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_host());
    expect(find.text('9'), findsOneWidget);

    final g = await tester.startGesture(tester.getCenter(find.byType(AgentHiveButton)));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Your agents'), findsNothing); // still charging
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 700));
    await g.up();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Your agents'), findsOneWidget);
    expect(find.text('9 agents ready'), findsOneWidget);
    for (final a in agentRoster) {
      expect(find.text(a.chip), findsOneWidget);
    }

    // Tap an agent: what it does.
    await tester.tap(find.text('Planning'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(agentRoster.firstWhere((a) => a.id == 'planner').blurb), findsOneWidget);
  });

  testWidgets('tap: the list of who does what', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_host());
    await tester.tap(find.byType(AgentHiveButton));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Your agents'), findsOneWidget);
    expect(find.text('Manager'), findsOneWidget);
    expect(find.text('Working'), findsNothing);
  });

  testWidgets('working: the badge counts the agents on it', (tester) async {
    await tester.pumpWidget(_host());
    engine.agentControl.value = (
      control: const AgentControl(
        via: 'rules',
        agents: [(id: 'planner', label: 'Planning')],
      ),
      running: 'Planning',
      done: const {},
      over: false,
      persona: null,
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('2'), findsOneWidget);
    engine.agentControl.value = null;
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('9'), findsOneWidget);
  });
}
