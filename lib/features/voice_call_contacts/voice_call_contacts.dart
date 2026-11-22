import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/log.dart';
import '../../services/call_service.dart';
import 'contact_import.dart';
import 'local_contact_resolver.dart';
import 'voice_call_contacts_db.dart';

export 'local_contact_resolver.dart' show LocalCallMatch;

/// A person as the Calling Contacts screen shows them.
class LocalPerson {
  const LocalPerson(this.person, this.phones, this.aliases);
  final CanonicalPerson person;
  final List<PersonPhone> phones;
  final List<PersonAlias> aliases;
}

/// THE LOCAL CALLING CONTACTS (2026-11-22) — on demand, on the phone only.
///
/// Nothing is opened, read or asked for at app start. The database opens
/// the first time a call needs a name resolved or the Calling Contacts
/// screen is opened, and closes itself again after a short idle spell.
/// The contacts stored here are never sent to the server.
class VoiceCallContacts {
  VoiceCallContacts._();
  static final VoiceCallContacts instance = VoiceCallContacts._();

  static const _importedKey = 'vcc_initial_import_done';

  /// Closed after this long with no use and no screen open.
  static const _idle = Duration(minutes: 2);

  /// A name nobody matched triggers at most one re-import this often.
  static const _missReimportGap = Duration(minutes: 1);

  VoiceCallContactsDb? _db;
  Timer? _idleTimer;
  int _holders = 0;
  int _active = 0;
  DateTime? _lastImport;
  Future<int>? _importing;

  VoiceCallContactsDb _open() {
    _idleTimer?.cancel();
    return _db ??= VoiceCallContactsDb();
  }

  Future<T> _use<T>(Future<T> Function(VoiceCallContactsDb db) fn) async {
    final db = _open();
    _active++;
    try {
      return await fn(db);
    } finally {
      _active--;
      _scheduleIdleClose();
    }
  }

  void _scheduleIdleClose() {
    _idleTimer?.cancel();
    if (_holders > 0 || _active > 0) return;
    _idleTimer = Timer(_idle, () {
      if (_holders == 0 && _active == 0) dispose();
    });
  }

  /// Tests: use [db] (e.g. `NativeDatabase.memory()`) instead of the file.
  @visibleForTesting
  void debugUseDb(VoiceCallContactsDb db) {
    _idleTimer?.cancel();
    _db = db;
  }

  /// A screen showing the data keeps the database open while it is up.
  void hold() {
    _holders++;
    _open();
  }

  void release() {
    if (_holders > 0) _holders--;
    _scheduleIdleClose();
  }

  /// Closes the database and drops everything held in memory.
  Future<void> dispose() async {
    _idleTimer?.cancel();
    _idleTimer = null;
    final db = _db;
    _db = null;
    await db?.close();
  }

  /// People matching [name], best first. Imports from the phone the first
  /// time, and once more when nobody matches (a contact saved since).
  /// Callers check the contacts permission first.
  Future<List<LocalCallMatch>> resolve(String name) => _use((db) async {
        final prefs = await SharedPreferences.getInstance();
        final empty = (await db.select(db.canonicalPersons).get()).isEmpty;
        var imported = false;
        if (prefs.getBool(_importedKey) != true || empty) {
          await _importFromPhone(db);
          imported = true;
        }
        final resolver = LocalContactResolver(db);
        var found = await resolver.resolve(name);
        final last = _lastImport;
        if (found.isEmpty &&
            !imported &&
            (last == null || DateTime.now().difference(last) > _missReimportGap)) {
          await _importFromPhone(db);
          found = await resolver.resolve(name);
        }
        return found;
      });

  /// "Sync From Phone": re-reads the address book. Custom aliases stay.
  /// Returns the number of people, or null without contacts permission.
  Future<int?> syncFromPhone() => _use((db) async {
        if (!await CallService.instance.ensurePermission()) return null;
        return _importFromPhone(db);
      });

  Future<int> _importFromPhone(VoiceCallContactsDb db) {
    return _importing ??= () async {
      try {
        final all = await FlutterContacts.getContacts(withProperties: true);
        final raw = [
          for (final c in all)
            RawContact(
              // A number saved without a name keeps the number as its name
              // (listed under '#' on the Contacts screen).
              name: c.displayName.trim().isNotEmpty || c.phones.isEmpty
                  ? c.displayName
                  : c.phones.first.number,
              nickname: c.name.nickname,
              phones: [
                for (final p in c.phones)
                  (
                    p.number,
                    p.label == PhoneLabel.custom && p.customLabel.isNotEmpty
                        ? p.customLabel
                        : p.label.name
                  )
              ],
            ),
        ];
        final n = await SyncDeviceContactsToLocal(db).run(raw);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_importedKey, true);
        _lastImport = DateTime.now();
        AppLog.add('contacts', 'local import: $n people from ${raw.length} entries');
        return n;
      } finally {
        _importing = null;
      }
    }();
  }

  /// Counts a call placed to [personId] (never blocks the dial).
  Future<void> recordCall(int personId) => _use((db) async {
        await db.customUpdate(
          'UPDATE canonical_persons SET call_count = call_count + 1, '
          'last_called_at = ? WHERE id = ?',
          variables: [Variable(DateTime.now()), Variable(personId)],
          updates: {db.canonicalPersons},
        );
      });

  Future<void> addAlias(int personId, String alias) => _use((db) async {
        final a = alias.trim();
        final n = CallService.instance.normalizedName(a);
        if (n.isEmpty) return;
        final dup = await (db.select(db.personAliases)
              ..where((x) => x.personId.equals(personId) & x.normalizedAlias.equals(n)))
            .get();
        if (dup.isNotEmpty) return;
        await db.into(db.personAliases).insert(PersonAliasesCompanion.insert(
            personId: personId,
            alias: a,
            normalizedAlias: n,
            origin: originUserCustom));
      });

  Future<void> removeAlias(int aliasId) => _use((db) async {
        await (db.delete(db.personAliases)
              ..where((x) => x.id.equals(aliasId) & x.origin.equals(originUserCustom)))
            .go();
      });

  /// Everyone, live: re-emits whenever a person, number or alias changes.
  /// Call [hold] first and [release] when the stream is no longer needed.
  Stream<List<LocalPerson>> watchPersons() {
    final db = _open();
    return db
        .customSelect('SELECT 1',
            readsFrom: {db.canonicalPersons, db.personPhones, db.personAliases})
        .watch()
        .asyncMap((_) => loadPersons(db));
  }

  /// Everyone, once (a voice request looking up its contact).
  Future<List<LocalPerson>> persons() => _use(loadPersons);

  /// Reads every person with their numbers and aliases.
  static Future<List<LocalPerson>> loadPersons(VoiceCallContactsDb db) async {
    final persons = await (db.select(db.canonicalPersons)
          ..orderBy([(p) => OrderingTerm(expression: p.primaryName.lower())]))
        .get();
    final phones = <int, List<PersonPhone>>{};
    for (final p in await db.select(db.personPhones).get()) {
      phones.putIfAbsent(p.personId, () => []).add(p);
    }
    final aliases = <int, List<PersonAlias>>{};
    for (final a in await db.select(db.personAliases).get()) {
      aliases.putIfAbsent(a.personId, () => []).add(a);
    }
    return [
      for (final p in persons)
        LocalPerson(p, phones[p.id] ?? const [], aliases[p.id] ?? const []),
    ];
  }
}
