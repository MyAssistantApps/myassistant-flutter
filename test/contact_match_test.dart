import 'package:flutter_test/flutter_test.dart';
import 'package:myassistant/services/call_service.dart';

/// Misheard names still find the saved contact (2026-10-11).
void main() {
  double s(String saved, String spoken) => CallService.soundAlike(saved, spoken);

  test('a misheard name sounds like the saved one', () {
    expect(s('Jayantha Mava', 'jayatha Mawa'), greaterThanOrEqualTo(0.88));
    expect(s('Ashalatha Rao', 'Ashratha Rao'), greaterThanOrEqualTo(0.88));
    expect(s('Ashalatha Rao', 'ashelatha rao'), greaterThanOrEqualTo(0.88));
    expect(s('Jayantha Karle', 'Jayant Karle'), greaterThanOrEqualTo(0.88));
  });

  test('a different person does not', () {
    // "Jayatha" has no "mava": never the match for "jayatha mawa".
    expect(s('Jayatha', 'jayatha Mawa'), lessThan(0.88));
    expect(s('Jayashree', 'Ashalatha Rao'), lessThan(0.88));
    expect(s('Ravi Kumar', 'Amma'), lessThan(0.88));
  });
}
