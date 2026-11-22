import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myassistant/features/voice_call_contacts/contact_import.dart';
import 'package:myassistant/features/voice_call_contacts/local_contact_resolver.dart';
import 'package:myassistant/features/voice_call_contacts/phone_normalizer.dart';
import 'package:myassistant/features/voice_call_contacts/voice_call_contacts_db.dart';

/// Local calling contacts (2026-11-22): one person per number, resolved
/// by any of their names, kept only on the phone.
void main() {
  late VoiceCallContactsDb db;
  late SyncDeviceContactsToLocal importer;
  late LocalContactResolver resolver;

  setUp(() {
    db = VoiceCallContactsDb(NativeDatabase.memory());
    importer = SyncDeviceContactsToLocal(db);
    resolver = LocalContactResolver(db);
  });
  tearDown(() => db.close());

  const rohan = RawContact(name: 'Rohan Kulkarni', phones: [('98450 12345', 'mobile')]);
  const dad = RawContact(name: 'Dad', phones: [('+91 98450-12345', 'mobile')]);

  group('toE164', () {
    test('Indian numbers in every common form', () {
      expect(toE164('9845012345'), '+919845012345');
      expect(toE164('098450 12345'), '+919845012345');
      expect(toE164('+91 98450-12345'), '+919845012345');
      expect(toE164('919845012345'), '+919845012345');
      expect(toE164('0091 98450 12345'), '+919845012345');
    });

    test('international numbers keep their country', () {
      expect(toE164('+1 (415) 555-0100'), '+14155550100');
    });

    test('short codes and USSD are not personal numbers', () {
      expect(toE164('112'), isNull);
      expect(toE164('*121#'), isNull);
      expect(toE164(''), isNull);
    });
  });

  test('the same number saved as "Rohan" and "Dad" is one person', () async {
    await importer.run(const [rohan, dad]);

    final persons = await db.select(db.canonicalPersons).get();
    expect(persons, hasLength(1));
    expect(persons.single.mergedCount, 2);
    expect(persons.single.primaryName, 'Rohan Kulkarni');

    final phones = await db.select(db.personPhones).get();
    expect(phones.single.e164, '+919845012345');

    final aliases = {for (final a in await db.select(db.personAliases).get()) a.alias};
    expect(aliases, containsAll(['Rohan Kulkarni', 'Rohan', 'Dad']));
  });

  test('"call Rohan" and "call Dad" reach the same person and number', () async {
    await importer.run(const [rohan, dad]);

    final byName = await resolver.resolve('Rohan');
    final byFamily = await resolver.resolve('Dad');
    expect(byName, hasLength(1), reason: 'one person, so no "which one?"');
    expect(byFamily, hasLength(1));
    expect(byName.single.personId, byFamily.single.personId);
    expect(byName.single.phone, '+919845012345');
    expect(byFamily.single.phone, byName.single.phone);
    expect(byFamily.single.soundOnly, isFalse);
  });

  test('a misheard name finds the saved one by sound', () async {
    await importer.run(const [
      RawContact(name: 'Ashalatha Rao', phones: [('9900011111', 'mobile')]),
      RawContact(name: 'Jayashree', phones: [('9900022222', 'mobile')]),
    ]);

    final found = await resolver.resolve('Ashratha Rao');
    expect(found, hasLength(1));
    expect(found.single.name, 'Ashalatha Rao');
    expect(found.single.soundOnly, isTrue, reason: 'a guess the user confirms');
  });

  test('two different people with the same name both reach the picker', () async {
    await importer.run(const [
      RawContact(name: 'Ravi Kumar', phones: [('9811111111', 'mobile')]),
      RawContact(name: 'Ravi Shetty', phones: [('9822222222', 'mobile')]),
    ]);

    final found = await resolver.resolve('Ravi');
    expect(found, hasLength(2));
    expect(found.map((m) => m.personId).toSet(), hasLength(2));
    expect(found.map((m) => m.phone).toSet(),
        {'+919811111111', '+919822222222'});
  });

  test('custom aliases survive a re-import from the phone', () async {
    await importer.run(const [rohan]);
    final person = (await db.select(db.canonicalPersons).get()).single;
    await db.into(db.personAliases).insert(PersonAliasesCompanion.insert(
        personId: person.id,
        alias: 'Boss',
        normalizedAlias: 'boss',
        origin: originUserCustom));

    // The phone now also has "Dad" on the same number.
    await importer.run(const [rohan, dad]);

    final persons = await db.select(db.canonicalPersons).get();
    expect(persons.single.id, person.id, reason: 'same person, same id');
    expect(persons.single.mergedCount, 2);
    final custom = await (db.select(db.personAliases)
          ..where((a) => a.origin.equals(originUserCustom)))
        .get();
    expect(custom.single.alias, 'Boss');
    final found = await resolver.resolve('Boss');
    expect(found.single.personId, person.id);
  });

  test('a contact removed from the phone is removed here', () async {
    await importer.run(const [
      rohan,
      RawContact(name: 'Old Friend', phones: [('9833333333', 'mobile')]),
    ]);
    await importer.run(const [rohan]);
    final names = {for (final p in await db.select(db.canonicalPersons).get()) p.primaryName};
    expect(names, {'Rohan Kulkarni'});
    expect(await resolver.resolve('Old Friend'), isEmpty);
  });
}
