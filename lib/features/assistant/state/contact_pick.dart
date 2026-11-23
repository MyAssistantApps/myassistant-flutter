import 'assistant_state.dart';

/// SEVERAL CONTACTS, ONE NAME (owner, 2026-11-21): "call Ravi" with three
/// Ravis saved is answered with a numbered list — "1. Ravi, number ending
/// 4321; 2. Ravi, ending 8765" — and the user picks by number. This reads
/// that answer: "1", "one", "first", "number 2", "the second one",
/// "option 3", "3rd", or the last digits ("the one ending 8765").
/// Returns the 0-based index into [options], or null when the answer
/// names none of them.
int? pickNumberedContact(String answer, List<ContactMatch> options) {
  if (options.isEmpty) return null;
  final a = answer.toLowerCase().trim();
  if (a.isEmpty) return null;

  // Last digits of a number ("ending 8765", "8765").
  final digits = RegExp(r'\d{3,}').firstMatch(a)?.group(0);
  if (digits != null) {
    final hits = <int>[
      for (var i = 0; i < options.length; i++)
        if (options[i].phone.replaceAll(RegExp(r'\D'), '').endsWith(digits)) i,
    ];
    // Digits that end none (or several) of the numbers are not a pick;
    // "the one ending 0000" must not fall through to "one".
    return hits.length == 1 ? hits.first : null;
  }

  const words = {
    'one': 1, 'first': 1, '1st': 1, 'two': 2, 'second': 2, '2nd': 2,
    'three': 3, 'third': 3, '3rd': 3, 'four': 4, 'fourth': 4, '4th': 4,
    'five': 5, 'fifth': 5, '5th': 5, 'six': 6, 'sixth': 6, '6th': 6,
    'last': -1,
  };
  int? n;
  final lone = RegExp(r'^(?:#|no\.?|number|option|choice|the)?\s*(\d)\b').firstMatch(a);
  if (lone != null) n = int.parse(lone.group(1)!);
  n ??= () {
    final m = RegExp(r'\b(?:number|option|choice|no\.?|#)\s*(\d)\b').firstMatch(a);
    return m == null ? null : int.parse(m.group(1)!);
  }();
  if (n == null) {
    for (final w in RegExp(r'[a-z0-9]+').allMatches(a).map((m) => m.group(0)!)) {
      if (words.containsKey(w)) {
        n = words[w];
        break;
      }
    }
  }
  if (n == null) return null;
  if (n == -1) return options.length - 1;
  return n >= 1 && n <= options.length ? n - 1 : null;
}

/// The options as they are read out: "1. Ravi, number ending 4321".
String numberedContacts(List<ContactMatch> options) {
  final b = StringBuffer();
  for (var i = 0; i < options.length; i++) {
    final d = options[i].phone.replaceAll(RegExp(r'\D'), '');
    final tail = d.length >= 4 ? d.substring(d.length - 4) : d;
    if (i > 0) b.write('; ');
    b.write('${i + 1}. ${options[i].name}${tail.isEmpty ? '' : ', number ending $tail'}');
  }
  return b.toString();
}
