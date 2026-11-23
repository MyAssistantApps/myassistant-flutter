import 'package:flutter/foundation.dart';

import '../../services/api_service.dart';

/// ─────────────────────────────────────────────────────────────────────────
///  WALLET PREVIEW (debug builds only).
///
///  Lets the wallet screens be seen and tried on a phone before the server
///  has the wallet turned on or any Razorpay keys. It is a small in-memory
///  copy of the server: it answers the same paths with the same JSON, keeps
///  the same rules (limits, PIN, bonus spent before cash, refunds only of
///  cash) and forgets everything when the app is closed. No request leaves
///  the phone and no money moves.
///
///  Turn it on with:
///    flutter run --dart-define=WALLET_PREVIEW=true
///  A release build can never turn it on (kDebugMode is false there).
/// ─────────────────────────────────────────────────────────────────────────
class WalletPreview {
  WalletPreview._() {
    _seed();
  }
  static final WalletPreview instance = WalletPreview._();

  static const bool enabled = kDebugMode && bool.fromEnvironment('WALLET_PREVIEW');

  static const _min = 1000, _max = 1000000, _daily = 2000000, _cap = 5000000, _stepUp = 200000;

  int _cash = 0, _bonus = 0, _addedToday = 0, _n = 0;
  String? _pin;
  bool _codeApplied = false;
  final _txns = <Map<String, dynamic>>[];
  final _topups = <String, int>{};
  final _tokens = <String>{};

  int get _now => DateTime.now().millisecondsSinceEpoch;

  void _post(String type, String title, int paise, bool incoming, {int agoMin = 0, String status = 'posted'}) {
    _txns.insert(0, {
      'id': 'prev_${++_n}',
      'type': type,
      'title': title,
      'amount_paise': paise,
      'direction': incoming ? 'in' : 'out',
      'status': status,
      'created_at': _now - agoMin * 60000,
    });
  }

  void _seed() {
    // Oldest first, so the newest ends up on top.
    _post('topup', 'Added money', 100000, true, agoMin: 60 * 24 * 9);
    _post('referral_bonus', 'Referral bonus: Priya joined', 5000, true, agoMin: 60 * 24 * 6);
    _post('spend', 'Cab to Mangaluru Central', 18600, false, agoMin: 60 * 24 * 4);
    _post('spend', 'Mobile recharge ₹239', 23900, false, agoMin: 60 * 24 * 2);
    _post('topup', 'Added money', 50000, true, agoMin: 60 * 5);
    _post('refund', 'Money back to your bank', 20000, false, agoMin: 60 * 3, status: 'processing');
    _cash = 100000 - 18600 - 23900 + 50000 - 20000; // ₹875
    _bonus = 5000;
  }

  ApiResult _ok(Map<String, dynamic> body) => ApiResult(200, body);
  ApiResult _no(int status, String error, String message) => ApiResult(status, {'error': error, 'message': message});

  Map<String, dynamic> _summary() => {
        'available': true,
        'cash_paise': _cash,
        'bonus_paise': _bonus,
        'status': 'active',
        'payments_ready': true,
        'has_pin': _pin != null,
        'step_up_above_paise': _stepUp,
        'limits': {
          'min_topup_paise': _min,
          'max_topup_paise': _max,
          'daily_left_paise': _daily - _addedToday,
          'cap_left_paise': _cap - _cash - _bonus,
        },
      };

  bool _takeToken(Map<String, String> headers) => _tokens.remove(headers['X-Wallet-Step-Up']);

  /// Answers one wallet request the way the server would.
  Future<ApiResult> handle(String method, String path, Object? body, Map<String, String> headers) async {
    await Future<void>.delayed(const Duration(milliseconds: 350)); // feel like a network
    final b = (body is Map) ? body.cast<String, dynamic>() : const <String, dynamic>{};
    final uri = Uri.parse(path);
    final p = uri.path;
    int amount() => (b['amount_paise'] as num?)?.toInt() ?? 0;

    if (method == 'GET' && p == '/wallet') return _ok(_summary());

    if (method == 'GET' && p == '/wallet/transactions') {
      final limit = int.tryParse(uri.queryParameters['limit'] ?? '') ?? 20;
      final start = int.tryParse(uri.queryParameters['cursor'] ?? '') ?? 0;
      final page = _txns.skip(start).take(limit).toList();
      final next = start + page.length < _txns.length ? '${start + page.length}' : null;
      return _ok({'items': page, 'next_cursor': next});
    }

    if (method == 'POST' && p == '/wallet/topups') {
      final a = amount();
      if (a < _min) return _no(400, 'amount_too_small', 'The minimum is ₹10.');
      if (a > _max) return _no(400, 'amount_too_large', 'You can add up to ₹10,000 at a time.');
      if (_addedToday + a > _daily) return _no(400, 'daily_limit', 'Daily limit reached.');
      if (_cash + _bonus + a > _cap) return _no(400, 'wallet_cap', 'Your wallet can hold up to ₹50,000.');
      final id = 'tu_prev_${++_n}';
      _topups[id] = a;
      return _ok({
        'topup_id': id,
        'razorpay_order_id': 'order_prev_$_n',
        'key_id': 'rzp_test_preview',
        'amount_paise': a,
        'prefill': const {'name': 'Preview user'},
      });
    }

    final verify = RegExp(r'^/wallet/topups/([^/]+)/verify$').firstMatch(p);
    if (method == 'POST' && verify != null) {
      final a = _topups.remove(verify.group(1));
      if (a == null) return _ok({'status': 'credited'}); // repeated verify: already credited
      _cash += a;
      _addedToday += a;
      _post('topup', 'Added money', a, true);
      return _ok({'status': 'credited'});
    }
    if (method == 'GET' && p.startsWith('/wallet/topups/')) return _ok({'status': 'credited'});

    if (method == 'POST' && p == '/wallet/pin') {
      final pin = '${b['pin'] ?? ''}';
      if (_pin != null && b['current_pin'] != _pin) return _no(401, 'wrong_pin', 'Your current PIN is not right.');
      if (!RegExp(r'^\d{4,6}$').hasMatch(pin) || RegExp(r'^(\d)\1+$').hasMatch(pin) || '0123456789'.contains(pin)) {
        return _no(400, 'weak_pin', 'Choose 4 to 6 digits that are not all the same or in a row.');
      }
      _pin = pin;
      return _ok({'ok': true});
    }

    if (method == 'POST' && p == '/wallet/step-up') {
      if (_pin == null) return _no(400, 'no_pin', 'Set a PIN first.');
      if (b['pin'] != _pin) return _no(401, 'wrong_pin', 'That PIN is not right.');
      final t = 'stepup_prev_${++_n}';
      _tokens.add(t);
      return _ok({'step_up_token': t, 'expires_in': 300});
    }

    if (method == 'GET' && p == '/wallet/refundable') return _ok({'refundable_paise': _cash});
    if (method == 'GET' && p == '/wallet/refunds') {
      return _ok({'items': _txns.where((t) => t['type'] == 'refund').toList()});
    }
    if (method == 'POST' && p == '/wallet/refunds') {
      if (!_takeToken(headers)) return _no(401, 'step_up_required', 'Enter your wallet PIN to continue.');
      final a = amount();
      if (a <= 0 || a > _cash) return _no(400, 'over_refundable', 'You can get back up to the money you added.');
      _cash -= a;
      _post('refund', 'Money back to your bank', a, false, status: 'processing');
      return _ok({'status': 'processing'});
    }

    if (method == 'POST' && p == '/wallet/spend') {
      const price = 14900; // every preview purchase costs ₹149
      if (price > _stepUp && !_takeToken(headers)) {
        return _no(401, 'step_up_required', 'Enter your wallet PIN to continue.');
      }
      if (price > _cash + _bonus) return _no(402, 'insufficient_balance', 'Not enough balance. Add money and try again.');
      final fromBonus = price < _bonus ? price : _bonus;
      _bonus -= fromBonus;
      _cash -= price - fromBonus;
      _post('spend', 'Preview purchase', price, false);
      return _ok({'transaction_id': 'prev_$_n', 'amount_paise': price, 'paid_bonus_paise': fromBonus});
    }

    if (method == 'GET' && p == '/referrals/me') {
      return _ok({
        'code': 'PREV7K2Q',
        'share_url': 'https://myassistant.app/r/PREV7K2Q',
        'referrer_reward_paise': 5000,
        'referee_reward_paise': 2500,
        'min_topup_paise': 10000,
        'rewards_earned_paise': 5000,
        'rewarded': 1,
        'pending': 1,
        'can_apply_code': !_codeApplied,
      });
    }
    if (method == 'GET' && p == '/referrals/history') {
      return _ok({
        'items': [
          {'friend': 'Rahul S.', 'reward_paise': 5000, 'status_text': 'On its way: paid out on 30 Nov'},
          {'friend': 'Priya K.', 'reward_paise': 5000, 'status_text': 'Rewarded'},
        ],
      });
    }
    if (method == 'POST' && p == '/referrals/apply') {
      final code = '${b['code'] ?? ''}'.trim().toUpperCase();
      if (code == 'PREV7K2Q') return _no(400, 'own_code', 'You cannot use your own code.');
      if (code.length < 6) return _no(404, 'unknown_code', 'That code was not found.');
      _codeApplied = true;
      return _ok({'message': 'Code applied. You get ₹25 bonus after your first top-up of ₹100.'});
    }

    return _no(404, 'not_found', 'Preview has no answer for $method $p.');
  }
}
