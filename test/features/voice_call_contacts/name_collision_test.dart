import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myassistant/features/voice_call_contacts/contact_import.dart';
import 'package:myassistant/features/voice_call_contacts/local_contact_resolver.dart';
import 'package:myassistant/features/voice_call_contacts/voice_call_contacts_db.dart';

/// Same name, different numbers: separate people, numbered "Lobo 1",
/// "Lobo 2" in the order of their numbers.
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

  const low = '+919123456789', high = '+919876543210';
  // Saved with the higher number first: the order must come from the
  // numbers, not from the address book.
  const loboHigh = RawContact(name: 'Lobo', phones: [('98765 43210', 'mobile')]);
  const loboLow = RawContact(name: 'Lobo', phones: [('91234 56789', 'mobile')]);
  const priya = RawContact(name: 'Priya', phones: [('9900033333', 'mobile')]);

  /// primary number → display label.
  Future<Map<String, String>> labelsByPhone() async {
    final persons = {
      for (final p in await db.select(db.canonicalPersons).get()) p.id: p
    };
    return {
      for (final ph in await db.select(db.personPhones).get())
        ph.e164: persons[ph.personId]!.label
    };
  }

  test('two "Lobo" on different numbers are "Lobo 1" and "Lobo 2"', () async {
    await importer.run(const [loboHigh, loboLow, priya]);

    final persons = await db.select(db.canonicalPersons).get();
    expect(persons.where((p) => p.primaryName == 'Lobo'), hasLength(2));
    final labels = await labelsByPhone();
    expect(labels[low], 'Lobo 1');
    expect(labels[high], 'Lobo 2');

    final one = persons.firstWhere((p) => p.displayLabel == 'Lobo 1');
    final aliases = await (db.select(db.personAliases)
          ..where((a) => a.personId.equals(one.id)))
        .get();
    expect({for (final a in aliases) a.alias: a.weight},
        {'Lobo 1': 1.15, 'Lobo': 1.0});
    expect(aliases.every((a) => a.origin == originDeviceImport), isTrue);
  });

  test('"call Lobo 1" and "call Lobo 2" each reach one number', () async {
    await importer.run(const [loboHigh, loboLow]);

    final one = await resolver.resolve('Lobo 1');
    expect(one, hasLength(1));
    expect(one.single.phone, low);
    expect(one.single.name, 'Lobo 1');
    expect(one.single.score, 100);

    final two = await resolver.resolve('Lobo 2');
    expect(two, hasLength(1));
    expect(two.single.phone, high);
    expect(two.single.name, 'Lobo 2');

    // As speech recognition may write it.
    final spoken = await resolver.resolve('lobo two');
    expect(spoken.single.phone, high);
  });

  test('"call Lobo" offers both, by their labels', () async {
    await importer.run(const [loboHigh, loboLow]);

    final found = await resolver.resolve('Lobo');
    expect(found.map((m) => m.name).toSet(), {'Lobo 1', 'Lobo 2'});
    expect(found.map((m) => m.phone).toSet(), {low, high});
  });

  test('a name only one person has is not numbered', () async {
    await importer.run(const [loboHigh, loboLow, priya]);

    final p = (await db.select(db.canonicalPersons).get())
        .singleWhere((p) => p.primaryName == 'Priya');
    expect(p.displayLabel, 'Priya');
    final aliases = await (db.select(db.personAliases)
          ..where((a) => a.personId.equals(p.id)))
        .get();
    expect(aliases.map((a) => a.alias), ['Priya']);
    expect((await resolver.resolve('Priya')).single.name, 'Priya');
    expect(await resolver.resolve('Priya 1'), isEmpty);
  });

  test('the same number under the same name twice is one person', () async {
    await importer.run(const [loboLow, loboLow]);
    final p = (await db.select(db.canonicalPersons).get()).single;
    expect(p.mergedCount, 2);
    expect(p.displayLabel, 'Lobo');
  });

  test('a re-sync keeps the numbering, the call history and custom aliases',
      () async {
    await importer.run(const [loboHigh, loboLow]);
    final before = await db.select(db.canonicalPersons).get();
    final two = before.firstWhere((p) => p.displayLabel == 'Lobo 2');
    await db.into(db.personAliases).insert(PersonAliasesCompanion.insert(
        personId: two.id,
        alias: 'Lobo Office',
        normalizedAlias: 'lobo office',
        origin: originUserCustom));
    final called = DateTime(2026, 11, 20, 9);
    await (db.update(db.canonicalPersons)..where((p) => p.id.equals(two.id)))
        .write(CanonicalPersonsCompanion(
            callCount: const Value(3), lastCalledAt: Value(called)));

    // The address book comes back in the other order.
    await importer.run(const [loboLow, loboHigh]);
    await importer.run(const [loboLow, loboHigh]);

    final after = await db.select(db.canonicalPersons).get();
    expect({for (final p in after) p.id: p.displayLabel},
        {for (final p in before) p.id: p.displayLabel});
    final same = after.firstWhere((p) => p.id == two.id);
    expect(same.callCount, 3);
    expect(same.lastCalledAt, called);
    expect((await labelsByPhone())[high], 'Lobo 2');

    final aliases = await (db.select(db.personAliases)
          ..where((a) => a.personId.equals(two.id)))
        .get();
    expect(aliases.map((a) => a.alias).toSet(), {'Lobo 2', 'Lobo', 'Lobo Office'},
        reason: 'no duplicates after repeated syncs');
    expect(aliases, hasLength(3));
    expect((await resolver.resolve('Lobo Office')).single.phone, high);
  });

  test('when one "Lobo" is deleted the other is plain "Lobo" again', () async {
    await importer.run(const [loboHigh, loboLow]);
    await importer.run(const [loboHigh]);

    final p = (await db.select(db.canonicalPersons).get()).single;
    expect(p.displayLabel, 'Lobo');
    expect(await resolver.resolve('Lobo 2'), isEmpty);
    expect((await resolver.resolve('Lobo')).single.phone, high);
  });

  test('a version 1 database is upgraded and labelled in place', () async {
    final old = VoiceCallContactsDb(NativeDatabase.memory(setup: (raw) {
      raw.execute('''
        CREATE TABLE canonical_persons (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          primary_name TEXT NOT NULL,
          merged_count INTEGER NOT NULL DEFAULT 1,
          call_count INTEGER NOT NULL DEFAULT 0,
          last_called_at INTEGER NULL);
        CREATE TABLE person_phones (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          person_id INTEGER NOT NULL REFERENCES canonical_persons (id) ON DELETE CASCADE,
          e164 TEXT NOT NULL UNIQUE,
          label TEXT NOT NULL,
          is_primary INTEGER NOT NULL CHECK (is_primary IN (0, 1)));
        CREATE TABLE person_aliases (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          person_id INTEGER NOT NULL REFERENCES canonical_persons (id) ON DELETE CASCADE,
          alias TEXT NOT NULL,
          normalized_alias TEXT NOT NULL,
          origin TEXT NOT NULL,
          weight REAL NOT NULL DEFAULT 1.0);
        INSERT INTO canonical_persons (id, primary_name, call_count) VALUES
          (1, 'Lobo', 4), (2, 'Lobo', 0), (3, 'Priya', 1);
        INSERT INTO person_phones (person_id, e164, label, is_primary) VALUES
          (1, '$high', 'mobile', 1), (2, '$low', 'mobile', 1),
          (3, '+919900033333', 'mobile', 1);
        INSERT INTO person_aliases (person_id, alias, normalized_alias, origin) VALUES
          (1, 'Lobo', 'lobo', 'device_import'), (2, 'Lobo', 'lobo', 'device_import'),
          (3, 'Priya', 'priya', 'device_import'), (1, 'Boss', 'boss', 'user_custom');
        PRAGMA user_version = 1;
      ''');
    }));
    addTearDown(old.close);

    final persons = {
      for (final p in await old.select(old.canonicalPersons).get()) p.id: p
    };
    expect(persons[1]!.displayLabel, 'Lobo 2');
    expect(persons[1]!.callCount, 4);
    expect(persons[2]!.displayLabel, 'Lobo 1');
    expect(persons[3]!.displayLabel, 'Priya');
    final r = LocalContactResolver(old);
    expect((await r.resolve('Lobo 1')).single.phone, low);
    expect((await r.resolve('Boss')).single.name, 'Lobo 2');
  });
}
