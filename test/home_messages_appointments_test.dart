import 'package:flutter_test/flutter_test.dart';
import 'package:myassistant/features/home/appointment_strip.dart';
import 'package:myassistant/features/home/messages_card.dart';
import 'package:myassistant/models/brief.dart';

void main() {
  group('messages on Home', () {
    test('labels from older servers are removed', () {
      expect(cleanMessageText('(Call with your assistant Maya) The caller wants a call.'),
          'The caller wants a call.');
      expect(cleanMessageText('[URGENT] (Left with your assistant Nova) Server down'),
          'Server down');
      expect(cleanMessageText('Plain words stay'), 'Plain words stay');
    });

    test('an urgent message is flagged and its marker removed', () {
      final m = BriefMessage.fromJson({'from': 'Ravi', 'text': '[URGENT] Call now', 'id': 7});
      expect(m.urgent, isTrue);
      expect(m.text, 'Call now');
      expect(m.id, 7);
    });

    test('ten people at once: one row each, urgent senders first, newest next', () {
      final all = [
        for (var i = 0; i < 10; i++)
          BriefMessage(from: 'Person $i', text: 'hi', atMs: 1000 + i),
        const BriefMessage(from: 'Person 3', text: 'again', atMs: 5000),
        const BriefMessage(from: 'Boss', text: 'now', urgent: true, atMs: 10),
      ];
      final g = groupMessages(all);
      expect(g.length, 11);
      expect(g.first.from, 'Boss');
      expect(g[1].from, 'Person 3');
      expect(g[1].messages.length, 2);
    });
  });

  group('the next appointment', () {
    test('parses what the server sends, tolerating a missing list', () {
      final b = TodayBrief.fromJson({
        'appointments': [
          {'id': 3, 'with': 'Dr Meera', 'at': 1, 'minutes': 15, 'modeLabel': 'In person', 'when': 'Mon 24 Nov, 1:00 pm'}
        ]
      });
      expect(b.appointments.single.withName, 'Dr Meera');
      expect(TodayBrief.fromJson(const {}).appointments, isEmpty);
    });

    test('the countdown reads at a glance', () {
      final now = DateTime(2026, 11, 21, 10, 0);
      int at(DateTime t) => t.millisecondsSinceEpoch;
      expect(appointmentCountdown(at(DateTime(2026, 11, 21, 10, 40)), now: now), 'In 40 min');
      expect(appointmentCountdown(at(DateTime(2026, 11, 21, 15, 0)), now: now), 'In 5 h');
      expect(appointmentCountdown(at(DateTime(2026, 11, 22, 9, 0)), now: now), 'Tomorrow');
      expect(appointmentCountdown(at(DateTime(2026, 11, 24, 9, 0)), now: now), 'Tue');
    });
  });
}
