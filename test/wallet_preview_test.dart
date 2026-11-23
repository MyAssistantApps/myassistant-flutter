import 'package:flutter_test/flutter_test.dart';
import 'package:myassistant/features/wallet/wallet_api.dart';
import 'package:myassistant/features/wallet/wallet_preview.dart';

void main() {
  final p = WalletPreview.instance;

  test('preview is off unless asked for at build time', () {
    expect(WalletPreview.enabled, isFalse);
    expect(WalletApi.preview, isFalse);
  });

  test('preview answers the wallet summary the screens parse', () async {
    final r = await p.handle('GET', '/wallet', null, const {});
    final s = WalletSummary.fromJson(r.body);
    expect(s.available, isTrue);
    expect(s.cash, 87500);
    expect(s.bonus, 5000);
    expect(s.canAdd, greaterThan(0));
  });

  test('a preview top-up is credited and shows in the activity', () async {
    final before = WalletSummary.fromJson((await p.handle('GET', '/wallet', null, const {})).body).cash;
    final t = await p.handle('POST', '/wallet/topups', {'amount_paise': 50000}, const {});
    expect(t.ok, isTrue);
    final v = await p.handle('POST', '/wallet/topups/${t.body['topup_id']}/verify', const {}, const {});
    expect(v.body['status'], 'credited');
    final after = WalletSummary.fromJson((await p.handle('GET', '/wallet', null, const {})).body).cash;
    expect(after - before, 50000);
    final page = await p.handle('GET', '/wallet/transactions?limit=1', null, const {});
    expect(WalletTxn.fromJson((page.body['items'] as List).first as Map<String, dynamic>).amount, 50000);
    expect(page.body['next_cursor'], isNotNull);
  });

  test('preview refunds need the PIN and never go above cash', () async {
    expect((await p.handle('POST', '/wallet/refunds', {'amount_paise': 100}, const {})).error, 'step_up_required');
    expect((await p.handle('POST', '/wallet/pin', {'pin': '1111'}, const {})).error, 'weak_pin');
    expect((await p.handle('POST', '/wallet/pin', {'pin': '4826'}, const {})).ok, isTrue);
    expect((await p.handle('POST', '/wallet/step-up', {'pin': '0000'}, const {})).error, 'wrong_pin');
    final tok = (await p.handle('POST', '/wallet/step-up', {'pin': '4826'}, const {})).body['step_up_token'] as String;
    final cash = (await p.handle('GET', '/wallet/refundable', null, const {})).body['refundable_paise'] as int;
    final over = await p.handle('POST', '/wallet/refunds', {'amount_paise': cash + 1}, {'X-Wallet-Step-Up': tok});
    expect(over.error, 'over_refundable');
  });

  test('preview referral codes: own code refused, another applied', () async {
    expect((await p.handle('POST', '/referrals/apply', {'code': 'prev7k2q'}, const {})).error, 'own_code');
    expect((await p.handle('POST', '/referrals/apply', {'code': 'FRIEND12'}, const {})).ok, isTrue);
    expect((await p.handle('GET', '/referrals/me', null, const {})).body['can_apply_code'], isFalse);
  });
}
