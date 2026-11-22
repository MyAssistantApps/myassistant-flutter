import '../../services/call_service.dart';
import 'voice_call_contacts_db.dart';

/// One person the spoken name may mean.
class LocalCallMatch {
  const LocalCallMatch({
    required this.personId,
    required this.name,
    required this.phone,
    required this.alias,
    required this.score,
  });

  final int personId;

  /// The person's primary (saved) name — what the picker shows.
  final String name;

  /// Primary number, E.164.
  final String phone;

  /// The alias that matched best ("Dad" for "call dad").
  final String alias;
  final int score;

  /// Matched only by how it SOUNDS — a guess the user must confirm.
  bool get soundOnly => score > 0 && score < 40;
}

/// Resolves a spoken name against the local contacts database.
///
/// The scoring is CallService's own (exact 100, word 80, prefix 60, all
/// words 55, substring 40, sound-alike 30–38). The difference is that
/// scores are grouped by PERSON: "call Rohan" and "call Dad" both reach the
/// one person saved under both names, and never become a "which one?".
class LocalContactResolver {
  LocalContactResolver(this.db);

  final VoiceCallContactsDb db;

  /// Candidates for [spoken], best first; at most six, all within 20
  /// points of the best (the same window CallService.findContacts uses).
  Future<List<LocalCallMatch>> resolve(String spoken) async {
    if (spoken.trim().isEmpty) return const [];
    final aliases = await db.select(db.personAliases).get();
    final phones = await primaryPhones();
    final persons = {
      for (final p in await db.select(db.canonicalPersons).get()) p.id: p
    };

    final best = <int, (int, PersonAlias)>{};
    for (final a in aliases) {
      if (!phones.containsKey(a.personId)) continue; // nothing to dial
      final s = CallService.instance.nameScore(a.alias, spoken);
      if (s <= 0) continue;
      final cur = best[a.personId];
      if (cur == null ||
          s > cur.$1 ||
          (s == cur.$1 && a.weight > cur.$2.weight)) {
        best[a.personId] = (s, a);
      }
    }
    if (best.isEmpty) return const [];

    final scored = best.entries.toList()
      ..sort((x, y) {
        final byScore = y.value.$1 - x.value.$1;
        if (byScore != 0) return byScore;
        // Same score: the person called more often first.
        return (persons[y.key]?.callCount ?? 0) -
            (persons[x.key]?.callCount ?? 0);
      });
    final top = scored.first.value.$1;
    return [
      for (final e in scored)
        if (e.value.$1 >= top - 20)
          LocalCallMatch(
            personId: e.key,
            name: persons[e.key]?.primaryName ?? e.value.$2.alias,
            phone: phones[e.key]!,
            alias: e.value.$2.alias,
            score: e.value.$1,
          ),
    ].take(6).toList();
  }

  /// personId → the number to dial (the primary one, else any).
  Future<Map<int, String>> primaryPhones() async {
    final out = <int, String>{};
    for (final p in await db.select(db.personPhones).get()) {
      if (p.isPrimary || !out.containsKey(p.personId)) out[p.personId] = p.e164;
    }
    return out;
  }
}
