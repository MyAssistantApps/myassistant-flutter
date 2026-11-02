// "Talk to your manager": the Manager panel slides in while the Manager
// has the conversation, shows what it is doing, and goes when it hands back.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myassistant/ai/types.dart';
import 'package:myassistant/features/assistant/state/assistant_engine.dart';
import 'package:myassistant/widgets/inline_voice.dart' show ManagerPanel;

void main() {
  final engine = AssistantEngine.instance;
  tearDown(() {
    engine.managerOn.value = false;
    engine.activityLabel.value = null;
  });

  double opacity(WidgetTester t) => t
      .widget<AnimatedOpacity>(
          find.descendant(of: find.byType(ManagerPanel), matching: find.byType(AnimatedOpacity)))
      .opacity;

  testWidgets('hidden until the Manager has the conversation, then shows what it does', (t) async {
    await t.pumpWidget(MaterialApp(home: Scaffold(body: ManagerPanel(engine: engine))));
    expect(opacity(t), 0, reason: 'Maya alone: nothing shown');

    engine.managerOn.value = true;
    await t.pumpAndSettle();
    expect(opacity(t), 1);
    expect(find.text('Manager'), findsOneWidget);
    expect(find.text('Taking over from your assistant'), findsOneWidget);

    engine.activityLabel.value = 'Searching the web';
    await t.pump();
    expect(find.text('Searching the web'), findsOneWidget);

    engine.managerOn.value = false;
    await t.pumpAndSettle();
    expect(opacity(t), 0, reason: 'handed back: the panel goes');
  });

  test('the server says who has the turn: only an explicit ask is the Manager', () {
    final asked = AgentControl.fromJson({
      'via': 'manager', 'agents': [], 'toolAgent': {},
      'addressed': {'id': 'manager', 'label': 'Manager'},
    })!;
    expect(asked.addressed?.id, 'manager');
    final maya = AgentControl.fromJson({'via': 'maya', 'agents': [], 'toolAgent': {}})!;
    expect(maya.addressed, isNull);
  });
}
