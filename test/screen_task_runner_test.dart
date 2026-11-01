// Tasks inside other apps (services/screen_agent.dart): the loop asks
// before anything sensitive, stops when told, notices being stuck, and
// always takes its overlay down.
import 'package:flutter_test/flutter_test.dart';
import 'package:myassistant/services/screen_agent.dart';

class FakeHands implements ScreenHands {
  FakeHands({this.allow = true, this.stopAfter = 999, this.frozen = false});
  final bool allow;
  final int stopAfter;
  final bool frozen;
  final acts = <String>[];
  final asked = <String>[];
  var hidden = false;
  var screen = 0;

  @override
  Future<bool> enabled() async => true;
  @override
  Future<Map<String, Object?>?> dump() async => {
        'pkg': 'com.whatsapp',
        'nodes': [
          {'i': 0, 'text': 'screen $screen'}
        ],
      };
  @override
  Future<String?> act(String action, {int? node, String? text, String? direction}) async {
    acts.add('$action${node == null ? '' : ' #$node'}${text == null ? '' : ' "$text"'}');
    if (!frozen) screen++;
    return null;
  }
  @override
  Future<void> status(String say) async {}
  @override
  Future<bool> confirm(String question) async {
    asked.add(question);
    return allow;
  }
  @override
  Future<bool> stopRequested() async => acts.length >= stopAfter;
  @override
  Future<void> hide() async => hidden = true;
}

/// A WhatsApp message: chat, field, type, send (needs a yes), done.
ScreenStep script() {
  final steps = [
    {'action': 'tap', 'node': 3, 'say': "Opening Ravi's chat"},
    {'action': 'tap', 'node': 4, 'say': 'Tapping the message box'},
    {'action': 'type', 'node': 4, 'text': 'running late', 'say': 'Typing the message'},
    {'action': 'tap', 'node': 6, 'say': 'Send the message to Ravi', 'sensitive': true},
    {'action': 'done', 'result': 'Sent Ravi "running late".'},
  ];
  var k = 0;
  return (goal, screen, history) async => steps[k++ < steps.length ? k - 1 : steps.length - 1];
}

void main() {
  test('does the task, asking before it sends', () async {
    final hands = FakeHands();
    final r = await ScreenTaskRunner(hands: hands, step: script(), settle: Duration.zero)
        .run('send Ravi running late', app: 'WhatsApp');
    expect(r.ok, isTrue);
    expect(r.summary, 'Sent Ravi "running late".');
    expect(hands.acts, ['tap #3', 'tap #4', 'type #4 "running late"', 'tap #6']);
    expect(hands.asked, ['Send the message to Ravi']);
    expect(hands.hidden, isTrue);
  });

  test('a no at the confirm card sends nothing', () async {
    final hands = FakeHands(allow: false);
    final r = await ScreenTaskRunner(hands: hands, step: script(), settle: Duration.zero).run('x');
    expect(r.ok, isFalse);
    expect(hands.acts, isNot(contains('tap #6')), reason: 'the send was never tapped');
    expect(r.summary, contains('nothing was sent'));
    expect(hands.hidden, isTrue);
  });

  test('Stop on the pill stops it at once', () async {
    final hands = FakeHands(stopAfter: 2);
    final r = await ScreenTaskRunner(hands: hands, step: script(), settle: Duration.zero).run('x');
    expect(r.ok, isFalse);
    expect(hands.acts.length, 2);
    expect(r.summary, contains('Stop'));
  });

  test('three steps that change nothing: stuck, stopped', () async {
    final hands = FakeHands(frozen: true);
    final r = await ScreenTaskRunner(
      hands: hands,
      step: (g, s, h) async => {'action': 'tap', 'node': 1, 'say': 'Trying'},
      settle: Duration.zero,
    ).run('x');
    expect(r.ok, isFalse);
    expect(r.summary, contains('stuck'));
    expect(hands.acts.length, 3);
  });

  test('never more than maxSteps, and no server means no steps', () async {
    final busy = FakeHands();
    final r = await ScreenTaskRunner(
      hands: busy,
      step: (g, s, h) async => {'action': 'scroll', 'node': null, 'direction': 'down', 'say': 'Looking'},
      maxSteps: 5,
      settle: Duration.zero,
    ).run('x');
    expect(busy.acts.length, 5);
    expect(r.summary, contains('too many steps'));

    final none = FakeHands();
    final r2 = await ScreenTaskRunner(hands: none, step: (g, s, h) async => null, settle: Duration.zero).run('x');
    expect(r2.ok, isFalse);
    expect(none.acts, isEmpty);
    expect(none.hidden, isTrue);
  });
}
