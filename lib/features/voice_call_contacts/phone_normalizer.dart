/// A phone number in E.164 form ("+919876543210"), or null when it is not
/// a dialable personal number (short codes, USSD, too few digits).
///
/// No country database: numbers without a country code are taken to be
/// in [defaultCc] (India). Already-international numbers are kept as is.
String? toE164(String raw, {String defaultCc = '91'}) {
  var s = raw.trim();
  if (s.isEmpty || s.contains('*') || s.contains('#')) return null;
  final plus = s.startsWith('+');
  var d = s.replaceAll(RegExp(r'\D'), '');
  if (d.length < 7) return null;
  if (plus) return '+$d';
  if (d.startsWith('00')) return '+${d.substring(2)}';
  // 0 9876543210 — the domestic trunk prefix.
  if (d.length == 11 && d.startsWith('0')) d = d.substring(1);
  if (d.length == 10) return '+$defaultCc$d';
  if (d.length == 10 + defaultCc.length && d.startsWith(defaultCc)) return '+$d';
  // Anything else (landlines with STD codes, foreign numbers saved without
  // a plus) is kept digit for digit so it still dials and still dedupes.
  return '+$d';
}
