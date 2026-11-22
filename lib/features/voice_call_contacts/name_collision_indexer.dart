import 'package:drift/drift.dart';

import '../../services/call_service.dart';
import 'voice_call_contacts_db.dart';

/// Pass 2 of the import: people who share a NAME but not a number.
///
/// Pass 1 made one person per number. Two "Lobo" entries on different
/// numbers are therefore two people; here they become "Lobo 1" and
/// "Lobo 2" (ordered by primary number, so the numbering is the same on
/// every sync). Each gets the alias "Lobo 1" (so "call Lobo 1" is exact)
/// and keeps "Lobo" (so "call Lobo" asks which one). A name only one
/// person has is left as it is.
///
/// Run inside the import's transaction, after the people, numbers and
/// imported aliases are written.
class NameCollisionIndexer {
  NameCollisionIndexer(this.db);

  final VoiceCallContactsDb db;

  /// Above a plain saved name (1.0): the numbered label wins a tie.
  static const indexedWeight = 1.15;

  Future<void> run() async {
    final norm = CallService.instance.normalizedName;

    // personId → the number to dial (the primary one, else any).
    final primary = <int, String>{};
    for (final p in await db.select(db.personPhones).get()) {
      if (p.isPrimary || !primary.containsKey(p.personId)) {
        primary[p.personId] = p.e164;
      }
    }

    final persons = await db.select(db.canonicalPersons).get();
    final labels = <int, String>{};
    final byName = <String, List<CanonicalPerson>>{};
    for (final p in persons) {
      labels[p.id] = p.primaryName;
      // Someone kept only for a custom alias has no number: not numbered.
      if (!primary.containsKey(p.id)) continue;
      final n = norm(p.primaryName);
      if (n.isNotEmpty) byName.putIfAbsent(n, () => []).add(p);
    }

    final existing = {
      for (final a in await db.select(db.personAliases).get())
        (a.personId, a.normalizedAlias)
    };
    Future<void> addAlias(int personId, String alias, double weight) async {
      final n = norm(alias);
      if (n.isEmpty || !existing.add((personId, n))) return;
      await db.into(db.personAliases).insert(PersonAliasesCompanion.insert(
          personId: personId,
          alias: alias,
          normalizedAlias: n,
          origin: originDeviceImport,
          weight: Value(weight)));
    }

    for (final group in byName.values) {
      if (group.length < 2) continue;
      group.sort((a, b) => primary[a.id]!.compareTo(primary[b.id]!));
      for (var i = 0; i < group.length; i++) {
        final p = group[i];
        final label = '${p.primaryName} ${i + 1}';
        labels[p.id] = label;
        await addAlias(p.id, label, indexedWeight);
        await addAlias(p.id, p.primaryName, 1.0);
      }
    }

    for (final p in persons) {
      if (p.displayLabel == labels[p.id]) continue;
      await (db.update(db.canonicalPersons)..where((x) => x.id.equals(p.id)))
          .write(CanonicalPersonsCompanion(displayLabel: Value(labels[p.id])));
    }
  }
}
