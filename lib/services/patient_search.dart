import '../models/client.dart';

/// VOICE SEARCH FOR PATIENT RECORDS (owner, 2026-11-22). What the doctor
/// says at the mic ("show me Ramesh Kumar's reports", "patient with
/// diabetes") becomes the words worth searching for: the request words
/// ("show", "open", "patient", "records", "details" …) are dropped, and a
/// possessive "'s" is cut, so "Ramesh's reports" searches "ramesh".
String spokenPatientQuery(String spoken) {
  final words = spoken
      .toLowerCase()
      .replaceAll(RegExp(r"[’']s\b"), '')
      .replaceAll(RegExp(r'[^a-z0-9ऀ-෿ ]+'), ' ')
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty && !_filler.contains(w));
  return words.join(' ');
}

const _filler = {
  'show', 'open', 'find', 'search', 'get', 'give', 'tell', 'display', 'pull',
  'up', 'bring', 'look', 'for', 'me', 'my', 'the', 'a', 'an', 'of', 'about',
  'please', 'patient', 'patients', 'record', 'records', 'file', 'files',
  'detail', 'details', 'report', 'reports', 'history', 'notes', 'note',
  'document', 'documents', 'case', 'with', 'named', 'called', 'name', 'is',
  'mr', 'mrs', 'ms', 'miss', 'shri', 'smt', 'can', 'you', 'i', 'want', 'to',
  'see', 'all', 'and', 'information', 'info', 'profile',
};

/// Patients matching [query]: every word must appear in the name, summary,
/// tags or phone. Name matches come first, then the rest as they were.
List<Client> searchPatients(String query, List<Client> all) {
  final words =
      query.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return all;
  final hits = <(int, Client)>[];
  for (final c in all) {
    final name = c.name.toLowerCase();
    final hay = '$name ${c.summary.toLowerCase()} ${c.tags.toLowerCase()} '
        '${c.phone.replaceAll(RegExp(r'\D'), '')}';
    if (!words.every(hay.contains)) continue;
    hits.add((words.where(name.contains).length, c));
  }
  // A stable sort: more words in the name first.
  final ranked = [for (var i = 0; i < hits.length; i++) (hits[i].$1, i, hits[i].$2)]
    ..sort((a, b) => a.$1 != b.$1 ? b.$1 - a.$1 : a.$2 - b.$2);
  return [for (final r in ranked) r.$3];
}
