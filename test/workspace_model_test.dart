import 'package:flutter_test/flutter_test.dart';
import 'package:myassistant/services/workspace_service.dart';

void main() {
  final sample = <String, dynamic>{
    'day': '2026-11-21',
    'profession': 'Software Engineer',
    'pack': {
      'id': 'engineering',
      'title': 'Engineering Workspace',
      'tagline': 'Ship focused work.',
      'focus': 90,
      'day': [
        {'start': '09:30', 'end': '09:45', 'title': 'Stand-up', 'kind': 'meeting'},
      ],
      'routines': [
        {'id': 'standup', 'title': 'Stand-Up', 'detail': 'd', 'time': '09:15', 'repeat': 'daily', 'text': 't'},
        {'id': 'weekly', 'title': 'Weekly', 'detail': 'd', 'time': '16:30', 'repeat': 'weekly', 'weekday': 5, 'text': 't'},
        {'id': 'close', 'title': 'Close', 'detail': 'd', 'time': '10:00', 'repeat': 'monthly', 'monthDay': 22, 'text': 't'},
      ],
      'actions': [
        {'label': 'Draft My Stand-Up', 'icon': 'record_voice_over', 'ask': 'Draft it'},
      ],
    },
    'routines': [
      {'id': 'standup', 'on': true, 'time': '09:20', 'nextAt': 1795300000000},
      {'id': 'weekly', 'on': false, 'time': '16:30', 'nextAt': null},
    ],
    'today': {
      'reminders': [
        {'id': 3, 'text': 'Call Ravi', 'at': 1795290000000},
      ],
      'promises': [
        {'id': 4, 'text': 'Send the report', 'owedTo': 'Asha', 'dueAt': null},
      ],
    },
    'momentum': {
      'priorities': [
        {'id': 1, 'title': 'Ship the API', 'done': true},
        {'id': 2, 'title': 'Review PRs', 'done': false},
      ],
      'focus': {'todayMin': 45},
    },
    'plan': {
      'blocks': [
        {'start': '10:00', 'end': '12:00', 'title': 'Ship the API', 'kind': 'focus'},
      ],
      'note': 'Protect the morning.',
      'source': 'ai',
    },
  };

  test('the overview parses every section', () {
    final o = WorkspaceOverview.fromJson(sample);
    expect(o.pack.id, 'engineering');
    expect(o.pack.focus, 90);
    expect(o.pack.day.single.kind, 'meeting');
    expect(o.pack.routines, hasLength(3));
    expect(o.pack.actions.single.icon, 'record_voice_over');
    expect(o.routines['standup']!.on, isTrue);
    expect(o.routines['standup']!.time, '09:20');
    expect(o.routinesOn, 1);
    expect(o.reminders.single.text, 'Call Ravi');
    expect(o.promises.single.owedTo, 'Asha');
    expect(o.priorities.where((p) => p.done), hasLength(1));
    expect(o.focusMinutesToday, 45);
    expect(o.plan!.source, 'ai');
    expect(o.plan!.blocks.single.startMin, 600);
    expect(o.plan!.blocks.single.endMin, 720);
  });

  test('routine schedules read in words', () {
    final r = WorkspaceOverview.fromJson(sample).pack.routines;
    expect(r[0].when, 'Every day');
    expect(r[1].when, 'Every Friday');
    expect(r[2].when, 'Monthly on the 22nd');
  });

  test('an older or partial answer still parses', () {
    final o = WorkspaceOverview.fromJson({'pack': <String, dynamic>{}});
    expect(o.pack.id, 'general');
    expect(o.pack.routines, isEmpty);
    expect(o.priorities, isEmpty);
    expect(o.plan, isNull);
    expect(o.focusMinutesToday, 0);
  });
}
