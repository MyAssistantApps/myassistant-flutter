import 'package:flutter_test/flutter_test.dart';
import 'package:myassistant/screens/linked_accounts_screen.dart';

void main() {
  test('the server list becomes rows: linked, linkable, or available soon', () {
    final l = LinkedAccount.listFrom({
      'accounts': {
        'uber': {'label': 'Uber', 'available': true, 'linked': true},
        'swiggy': {'label': 'Swiggy', 'available': true, 'linked': false},
        'ola': {'label': 'Ola', 'available': false, 'linked': false},
      }
    });
    expect(l.map((a) => a.id), ['uber', 'swiggy', 'ola']);
    expect(l.first.linked, isTrue);
    expect(l[1].available && !l[1].linked, isTrue);
    expect(l.last.available, isFalse);
  });

  test('an older server or a failed call gives an empty list, not a crash', () {
    expect(LinkedAccount.listFrom(null), isEmpty);
    expect(LinkedAccount.listFrom(const {'accounts': 'x'}), isEmpty);
  });
}
