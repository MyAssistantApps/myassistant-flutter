import 'package:flutter_test/flutter_test.dart';
import 'package:myassistant/features/assistant/state/assistant_state.dart';
import 'package:myassistant/features/assistant/state/contact_pick.dart';

void main() {
  const ravis = [
    ContactMatch(id: 'a', name: 'Ravi', phone: '+91 98450 14321'),
    ContactMatch(id: 'b', name: 'Ravi', phone: '+91 99000 18765'),
    ContactMatch(id: 'c', name: 'Ravi Kumar', phone: '080 2222 3333'),
  ];

  test('the options are read out numbered, with the last four digits', () {
    expect(numberedContacts(ravis),
        '1. Ravi, number ending 4321; 2. Ravi, number ending 8765; 3. Ravi Kumar, number ending 3333');
  });

  test('every way of saying a number picks the right contact', () {
    for (final (say, want) in [
      ('1', 0), ('2', 1), ('number 2', 1), ('the second one', 1), ('option 3', 2),
      ('first', 0), ('3rd', 2), ('two', 1), ('the last one', 2), ('#2', 1),
      ('the one ending 8765', 1), ('8765', 1), ('3333', 2),
    ]) {
      expect(pickNumberedContact(say, ravis), want, reason: say);
    }
  });

  test('anything else is not a pick', () {
    expect(pickNumberedContact('Ravi', ravis), isNull);
    expect(pickNumberedContact('7', ravis), isNull);
    expect(pickNumberedContact('the one ending 0000', ravis), isNull);
    expect(pickNumberedContact('2', const []), isNull);
  });
}
