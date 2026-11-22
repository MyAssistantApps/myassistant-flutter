import 'package:flutter_test/flutter_test.dart';
import 'package:myassistant/services/connect_service.dart';

void main() {
  test('a contact card parses, with first name and photo URL', () {
    final c = AssistantContact.fromJson({
      'id': 42,
      'ownerName': 'Alan Lobo',
      'assistantName': 'Nova',
      'voice': 'sage',
      'profession': 'Software Engineer',
      'persona': 'professional',
      'hasPhoto': true,
    });
    expect(c.id, 42);
    expect(c.firstName, 'Alan');
    expect(c.assistantName, 'Nova');
    expect(c.voice, 'sage');
    expect(c.hasPhoto, isTrue);
    expect(c.photoUrl, endsWith('/connect/42/photo'));
  });

  test('missing names fall back to readable words', () {
    final c = AssistantContact.fromJson({'id': 7, 'ownerName': '  ', 'assistantName': null});
    expect(c.ownerName, 'Your Contact');
    expect(c.assistantName, 'Assistant');
    expect(c.hasPhoto, isFalse);
  });

  test('a guest tool result reads ok and end-of-call', () {
    expect(const GuestToolResult({'ok': true, 'end': true}).ends, isTrue);
    expect(const GuestToolResult({'ok': false, 'error': 'x'}).ok, isFalse);
  });
}
