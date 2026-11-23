import 'package:flutter_test/flutter_test.dart';
import 'package:myassistant/models/user_document.dart';
import 'package:myassistant/screens/documents_screen.dart';

UserDocument _doc(int id, String title,
        {String category = 'bill', String summary = '', String expires = ''}) =>
    UserDocument.fromJson({
      'id': id,
      'filename': '$title.pdf',
      'mime': 'application/pdf',
      'title': title,
      'category': category,
      'summary': summary,
      'expiresOn': expires,
      'createdAt': DateTime(2026, 11, 16).millisecondsSinceEpoch,
    });

void main() {
  test('before the list loads, the plain Documents Assistant answers', () {
    expect(documentsRoleFor(null), documentsRole);
  });

  test('no documents: the assistant says so and points at the button', () {
    final r = documentsRoleFor(const []);
    expect(r.brief, contains('No documents were saved'));
    // Still searches first: a file may have been added a moment ago.
    expect(r.brief, contains('call find_document first'));
    expect(r.brief, contains('Add a Document'));
  });

  test('every document, with its details, is in the role', () {
    final r = documentsRoleFor([
      _doc(1, 'Electricity bill', summary: 'BESCOM bill for October, Rs 1,240.'),
      _doc(2, 'Passport', category: 'id', expires: '2027-01-10'),
    ]);
    expect(r.brief, contains('the 2 documents'));
    // The list is a snapshot: a named file not on it is searched for, not
    // refused (owner, 2026-11-21: "open my PAN card").
    expect(r.brief, contains('NOT on this list, call find_document anyway'));
    expect(r.brief, contains('"Electricity bill" (bill, saved 2026-11-16): BESCOM bill'));
    expect(r.brief, contains('"Passport" (id, expires 2027-01-10'));
    // Asked to show one: it opens at once.
    expect(r.brief, contains('find_document AT ONCE'));
  });

  test('a long shelf is cut off with a pointer to search', () {
    final many = [
      for (var i = 0; i < 200; i++)
        _doc(i, 'Receipt $i', summary: 'x' * 170),
    ];
    final r = documentsRoleFor(many);
    expect(r.brief.length, lessThan(9000));
    expect(r.brief, contains('more; use search_documents'));
  });
}
