import 'package:flutter_test/flutter_test.dart';
import 'package:myassistant/features/voice_call_contacts/contacts_screen.dart';

void main() {
  group('other names', () {
    test('leave out the shown name, any case', () {
      expect(otherNames('Rohan', ['Rohan', 'dad', 'ROHAN ']), ['dad']);
    });

    test('drop repeats and blanks, keeping saved order', () {
      expect(otherNames('Rohan', ['Dad', ' ', 'Papa', 'dad']), ['Dad', 'Papa']);
    });

    test('a person with one name has no other names', () {
      expect(otherNames('Asha', ['Asha']), isEmpty);
    });
  });

  group('sections', () {
    test('a name goes under its first letter, any case', () {
      expect(sectionOf('anita'), 'A');
      expect(sectionOf(' Rohan'), 'R');
    });

    test('a number saved without a name goes under #', () {
      expect(sectionOf('+91 98450 12345'), '#');
      expect(isNameless('+91 98450 12345'), isTrue);
      expect(sectionOf(''), '#');
    });

    test('A–Z in order, # last, names sorted inside each', () {
      final names = ['rohan', '+919845012345', 'Anita', 'Bharat', 'arjun', '#tag'];
      final s = sectionsOf(names);
      expect([for (final (k, _) in s) k], ['A', 'B', 'R', '#']);
      expect([for (final i in s.first.$2) names[i]], ['Anita', 'arjun']);
      expect([for (final i in s.last.$2) names[i]], ['#tag', '+919845012345']);
    });
  });

  group('voice commands name their contact', () {
    void expectReq(String words, String contact, ContactAction action,
        [String alias = '', String newAlias = '']) {
      final r = parseContactsCommand(words);
      expect(r, isNotNull, reason: words);
      expect((r!.contact, r.action, r.alias, r.newAlias),
          (contact, action, alias, newAlias),
          reason: words);
    }

    test('add an alias', () {
      expectReq('Give alias Papa to Allen', 'Allen', ContactAction.addAlias, 'Papa');
      expectReq('add the name Boss for Rohan Kulkarni.', 'Rohan Kulkarni',
          ContactAction.addAlias, 'Boss');
      expectReq('save Allen as Papa', 'Allen', ContactAction.addAlias, 'Papa');
    });

    test('change an alias', () {
      expectReq("change Allen's alias Papa to Dad", 'Allen',
          ContactAction.changeAlias, 'Papa', 'Dad');
      expectReq('change the alias Papa of Allen to Dad', 'Allen',
          ContactAction.changeAlias, 'Papa', 'Dad');
    });

    test('remove an alias', () {
      expectReq('remove alias Boss from Rohan', 'Rohan',
          ContactAction.removeAlias, 'Boss');
      expectReq("delete Rohan's alias Boss", 'Rohan', ContactAction.removeAlias,
          'Boss');
    });

    test('call and show', () {
      expectReq('Call Rohan', 'Rohan', ContactAction.call);
      expectReq("show me Allen's contact", 'Allen', ContactAction.show);
      expectReq('open Allen', 'Allen', ContactAction.show);
    });

    test('anything else is not a command', () {
      expect(parseContactsCommand('what is the weather'), isNull);
      expect(parseContactsCommand('   '), isNull);
    });
  });

  group('requests from the assistant', () {
    test('the server fields become a request', () {
      final r = ContactsRequest.fromAction({
        'screen': 'contacts',
        'contact': 'Allen',
        'contact_action': 'change_alias',
        'alias': 'Papa',
        'new_alias': 'Dad',
      })!;
      expect((r.contact, r.action, r.alias, r.newAlias),
          ('Allen', ContactAction.changeAlias, 'Papa', 'Dad'));
    });

    test('no contact just opens the list; an unknown action shows', () {
      expect(ContactsRequest.fromAction({'screen': 'contacts'}), isNull);
      expect(
          ContactsRequest.fromAction({'contact': 'Allen', 'contact_action': 'x'})!
              .action,
          ContactAction.show);
    });
  });
}
