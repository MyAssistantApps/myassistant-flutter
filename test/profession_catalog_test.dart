import 'package:flutter_test/flutter_test.dart';
import 'package:myassistant/services/persona.dart';

void main() {
  const keys = {'doctor', 'advocate', 'business', 'professional', 'student', 'personal'};

  test('every profession maps to a real workspace and has one', () {
    for (final p in Persona.professions) {
      expect(keys, contains(p.persona), reason: p.label);
      expect(Persona.workspaces[p.persona], isNotNull, reason: p.label);
    }
    for (final k in keys) {
      expect(Persona.workspaces[k]!.perks, hasLength(3), reason: k);
    }
  });

  test('labels are unique', () {
    final labels = Persona.professions.map((p) => p.label.toLowerCase()).toList();
    expect(labels.toSet().length, labels.length);
  });

  test('quick picks cover every everyday workspace', () {
    final picked = Persona.popular.map((p) => p.persona).toSet();
    expect(picked, containsAll(keys));
    expect(Persona.popular.length, lessThanOrEqualTo(12));
  });

  test('search ranks prefix matches first and finds words inside labels', () {
    expect(Persona.search('den').first.label, 'Dentist');
    expect(Persona.search('advocate').first.persona, 'advocate');
    expect(Persona.search('owner').map((p) => p.persona), everyElement('business'));
    expect(Persona.search('upsc').single.persona, 'student');
    expect(Persona.search('   '), isEmpty);
    expect(Persona.search('zzzz'), isEmpty);
    expect(Persona.search('e').length, lessThanOrEqualTo(8));
  });
}
