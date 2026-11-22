// The wallet in the app (features/wallet): money is shown, typed and read
// exactly — paise in, rupees out, Indian digit grouping — and the server's
// answers (balances, limits, refusals) are read as sent.
import 'package:flutter_test/flutter_test.dart';
import 'package:myassistant/features/wallet/wallet_api.dart';
import 'package:myassistant/services/api_service.dart';

void main() {
  test('rupees: whole, paise, Indian grouping, negative', () {
    expect(rupees(0), '₹0');
    expect(rupees(1050), '₹10.50');
    expect(rupees(150000), '₹1,500');
    expect(rupees(10000000), '₹1,00,000');
    expect(rupees(1234567899), '₹1,23,45,678.99');
    expect(rupees(-2500), '-₹25');
  });

  test('typed amounts become paise, or null', () {
    expect(paiseFromText('500'), 50000);
    expect(paiseFromText('₹1,250'), 125000);
    expect(paiseFromText('10.5'), 1050);
    expect(paiseFromText('10.05'), 1005);
    expect(paiseFromText('10.555'), isNull);
    expect(paiseFromText('-5'), isNull);
    expect(paiseFromText('abc'), isNull);
    expect(paiseFromText(''), isNull);
  });

  test('the wallet summary is read as the server sends it', () {
    final s = WalletSummary.fromJson({
      'available': true,
      'cash_paise': 70000,
      'bonus_paise': 2500,
      'status': 'active',
      'limits': {'min_topup_paise': 1000, 'max_topup_paise': 1000000, 'daily_left_paise': 300000, 'cap_left_paise': 4930000},
      'payments_ready': true,
      'has_pin': false,
      'step_up_above_paise': 200000,
    });
    expect(s.available, isTrue);
    expect(s.total, 72500);
    expect(s.canAdd, 300000, reason: 'the smallest of max, daily and cap');
    expect(s.frozen, isFalse);
    expect(WalletSummary.fromJson({'available': false}).available, isFalse);
    expect(WalletSummary.fromJson({'available': true, 'status': 'frozen'}).frozen, isTrue);
  });

  test('a refusal carries the server\'s own words; no network says so', () {
    const r = ApiResult(402, {'error': 'insufficient_balance', 'message': 'Not enough money in your wallet.'});
    expect(r.ok, isFalse);
    expect(r.error, 'insufficient_balance');
    expect(r.message(), 'Not enough money in your wallet.');
    const off = ApiResult(0, {});
    expect(off.error, 'offline');
    expect(off.message(), contains('No internet'));
    expect(const ApiResult(500, {}).message('Fallback.'), 'Fallback.');
  });

  test('idempotency keys are long, random and different', () {
    final a = WalletApi.newKey(), b = WalletApi.newKey();
    expect(a.length, 32);
    expect(a, isNot(b));
    expect(RegExp(r'^[0-9a-f]{32}$').hasMatch(a), isTrue);
  });
}
