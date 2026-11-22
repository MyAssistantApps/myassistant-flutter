import 'package:drift/drift.dart';

import '../../services/call_service.dart';
import 'phone_normalizer.dart';
import 'voice_call_contacts_db.dart';

/// One address-book entry as read from the phone (plain data, so the
/// import can be tested without a device).
class RawContact {
  const RawContact({
    required this.name,
    this.nickname = '',
    this.phones = const [],
  });

  final String name;
  final String nickname;

  /// (number as saved, label such as 'mobile' / 'work' / 'home').
  final List<(String, String)> phones;
}

/// Family words people say instead of a name ("call Dad").
const _familyWords = {
  'dad', 'daddy', 'papa', 'pappa', 'appa', 'father', 'pa',
  'mom', 'mum', 'mummy', 'mommy', 'mother', 'amma', 'ma', 'maa',
  'akka', 'anna', 'bhaiya', 'bhai', 'didi', 'tangi', 'thangi',
  'wife', 'husband', 'son', 'daughter', 'brother', 'sister',
  'uncle', 'aunty', 'aunt', 'mama', 'mami', 'chacha', 'chachi',
  'nani', 'nana', 'dadi', 'dada', 'ajji', 'ajja', 'thatha', 'paati',
  'grandma', 'grandpa',
};

/// Imports the phone's contacts into the local database.
///
/// Entries that share a number are ONE person (phone-first clustering):
/// "Rohan" and "Dad" saved with the same mobile become one row with
/// mergedCount 2, and every name they were saved under becomes an alias.
/// A re-import replaces only what came from the phone; aliases the user
/// added in the app ('user_custom') stay on their person.
class SyncDeviceContactsToLocal {
  SyncDeviceContactsToLocal(this.db, {this.defaultCc = '91'});

  final VoiceCallContactsDb db;
  final String defaultCc;

  /// Returns the number of people stored.
  Future<int> run(List<RawContact> raw) async {
    final clusters = _cluster(raw);
    return db.transaction(() async {
      // Old number → person, so a person keeps its id (and with it the
      // call count and custom aliases) across re-imports.
      final oldOwner = {
        for (final p in await db.select(db.personPhones).get()) p.e164: p.personId
      };
      await (db.delete(db.personAliases)
            ..where((a) => a.origin.equals(originDeviceImport)))
          .go();
      await db.delete(db.personPhones).go();

      final kept = <int>{};
      for (final c in clusters) {
        int? id;
        for (final ph in c.phones) {
          final o = oldOwner[ph.$1];
          if (o != null && !kept.contains(o)) {
            id = o;
            break;
          }
        }
        if (id != null) {
          await (db.update(db.canonicalPersons)..where((p) => p.id.equals(id!)))
              .write(CanonicalPersonsCompanion(
                  primaryName: Value(c.primaryName),
                  mergedCount: Value(c.entries)));
        } else {
          id = await db.into(db.canonicalPersons).insert(
              CanonicalPersonsCompanion.insert(
                  primaryName: c.primaryName, mergedCount: Value(c.entries)));
        }
        kept.add(id);
        for (var i = 0; i < c.phones.length; i++) {
          await db.into(db.personPhones).insert(PersonPhonesCompanion.insert(
              personId: id,
              e164: c.phones[i].$1,
              label: c.phones[i].$2,
              isPrimary: i == c.primary));
        }
        for (final a in c.aliases.entries) {
          await db.into(db.personAliases).insert(PersonAliasesCompanion.insert(
              personId: id,
              alias: a.value.$1,
              normalizedAlias: a.key,
              origin: originDeviceImport,
              weight: Value(a.value.$2)));
        }
      }

      // People no longer in the address book: gone, unless the user gave
      // them a name of their own here (kept, but there is nothing to dial).
      final custom = {
        for (final a in await (db.select(db.personAliases)
                  ..where((a) => a.origin.equals(originUserCustom)))
                .get())
          a.personId
      };
      await (db.delete(db.canonicalPersons)
            ..where((p) => p.id.isNotIn(kept) & p.id.isNotIn(custom)))
          .go();
      return kept.length;
    });
  }

  List<_Cluster> _cluster(List<RawContact> raw) {
    // Each entry's valid numbers.
    final nums = [
      for (final r in raw)
        [
          for (final p in r.phones)
            if (toE164(p.$1, defaultCc: defaultCc) case final e?) (e, p.$2)
        ]
    ];
    // Union-find over entries: any shared number joins two entries.
    final parent = List<int>.generate(raw.length, (i) => i);
    int find(int i) {
      while (parent[i] != i) {
        parent[i] = parent[parent[i]];
        i = parent[i];
      }
      return i;
    }

    final firstWith = <String, int>{};
    for (var i = 0; i < raw.length; i++) {
      for (final n in nums[i]) {
        final j = firstWith.putIfAbsent(n.$1, () => i);
        if (j != i) parent[find(i)] = find(j);
      }
    }

    final groups = <int, List<int>>{};
    for (var i = 0; i < raw.length; i++) {
      if (nums[i].isEmpty || raw[i].name.trim().isEmpty) continue;
      groups.putIfAbsent(find(i), () => []).add(i);
    }

    return [
      for (final g in groups.values) _Cluster.of([for (final i in g) (raw[i], nums[i])])
    ];
  }
}

class _Cluster {
  _Cluster(this.primaryName, this.entries, this.phones, this.primary, this.aliases);

  final String primaryName;
  final int entries;
  final List<(String, String)> phones; // (e164, label)
  final int primary;

  /// normalizedAlias → (alias as written, weight).
  final Map<String, (String, double)> aliases;

  static _Cluster of(List<(RawContact, List<(String, String)>)> members) {
    final phones = <(String, String)>[];
    final seen = <String>{};
    for (final m in members) {
      for (final p in m.$2) {
        if (seen.add(p.$1)) phones.add(p);
      }
    }
    var primary = phones.indexWhere((p) => p.$2 == 'mobile');
    if (primary < 0) primary = 0;

    // The most specific saved name is the one shown: "Rohan Kulkarni"
    // rather than "Dad".
    final names = [for (final m in members) m.$1.name.trim()];
    final primaryName = (List.of(names)
          ..sort((a, b) {
            final w = b.split(' ').length - a.split(' ').length;
            return w != 0 ? w : b.length - a.length;
          }))
        .first;

    final aliases = <String, (String, double)>{};
    void add(String alias, double weight) {
      final a = alias.trim();
      if (a.isEmpty) return;
      final n = CallService.instance.normalizedName(a);
      if (n.isEmpty) return;
      final cur = aliases[n];
      if (cur == null || weight > cur.$2) aliases[n] = (a, weight);
    }

    for (final m in members) {
      final name = m.$1.name.trim();
      add(name, 1.0);
      final words = name.split(RegExp(r'\s+'));
      if (words.length > 1 && words.first.length >= 2) add(words.first, 0.8);
      for (final w in words) {
        if (_familyWords.contains(w.toLowerCase())) add(w, 0.9);
      }
      for (final n in m.$1.nickname.split(RegExp(r'[,/]'))) {
        add(n, 1.0);
      }
    }
    return _Cluster(primaryName, members.length, phones, primary, aliases);
  }
}
