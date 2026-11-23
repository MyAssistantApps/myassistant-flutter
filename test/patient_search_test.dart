import 'package:flutter_test/flutter_test.dart';
import 'package:myassistant/models/client.dart';
import 'package:myassistant/services/patient_search.dart';

Client c(int id, String name, {String summary = '', String tags = '', String phone = ''}) =>
    Client.fromJson({'id': id, 'name': name, 'summary': summary, 'tags': tags, 'phone': phone});

void main() {
  test('spoken requests keep only the words worth searching', () {
    expect(spokenPatientQuery("Show me Ramesh Kumar's reports"), 'ramesh kumar');
    expect(spokenPatientQuery('open patient record of Priya'), 'priya');
    expect(spokenPatientQuery('patients with diabetes'), 'diabetes');
    expect(spokenPatientQuery('show records'), '');
  });

  test('every word must match; name matches rank first', () {
    final all = [
      c(1, 'Anil Rao', summary: 'Ramesh referred'),
      c(2, 'Ramesh Kumar', summary: '42M, type-2 diabetic'),
      c(3, 'Ramesh Shetty', phone: '+91 98450 12345'),
    ];
    expect(searchPatients('ramesh', all).map((x) => x.id), [2, 3, 1]);
    expect(searchPatients('ramesh diabetic', all).map((x) => x.id), [2]);
    expect(searchPatients('12345', all).map((x) => x.id), [3]);
    expect(searchPatients('', all).length, 3);
    expect(searchPatients('zzz', all), isEmpty);
  });
}
