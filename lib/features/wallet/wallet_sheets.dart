import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../../core/log.dart';
import '../../design/motion.dart';
import '../../design/neon_tokens.dart';
import 'wallet_api.dart';

/// ─────────────────────────────────────────────────────────────────────────
///  WALLET SHEETS — Add money (Razorpay Checkout), the wallet PIN, and a
///  refund request. Each one ends by reading the wallet again from the
///  server; none of them adds to a balance itself.
/// ─────────────────────────────────────────────────────────────────────────

Widget _sheetFrame(BuildContext context, {required String title, required List<Widget> children}) {
  return Padding(
    padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(color: Neon.hairline, borderRadius: BorderRadius.circular(2)),
          ),
        ),
        Text(title, style: NeonType.manrope(20, FontWeight.w800).copyWith(color: Neon.textHi)),
        const SizedBox(height: 14),
        ...children,
      ],
    ),
  );
}

ButtonStyle _primary() => FilledButton.styleFrom(
      backgroundColor: Neon.accentFill,
      foregroundColor: Neon.onAccent,
      minimumSize: const Size.fromHeight(52),
      shape: const StadiumBorder(),
      textStyle: NeonType.manrope(16, FontWeight.w800),
    );

/* ======================================================================= */
/*  ADD MONEY                                                              */
/* ======================================================================= */

/// Opens Add money; returns true when money was added.
Future<bool> showAddMoney(BuildContext context, WalletSummary s) async {
  final r = await showAppSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _AddMoneySheet(summary: s),
  );
  return r == true;
}

class _AddMoneySheet extends StatefulWidget {
  const _AddMoneySheet({required this.summary});
  final WalletSummary summary;

  @override
  State<_AddMoneySheet> createState() => _AddMoneySheetState();
}

enum _Stage { pick, paying, confirming, done, failed }

class _AddMoneySheetState extends State<_AddMoneySheet> {
  final _amount = TextEditingController(text: '500');
  final _rzp = Razorpay();
  _Stage _stage = _Stage.pick;
  String _message = '';
  String? _topupId;
  String? _orderId;
  String? _key; // one Idempotency-Key per Pay tap

  static const _presets = [10000, 50000, 100000, 200000];

  @override
  void initState() {
    super.initState();
    _rzp.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onSuccess);
    _rzp.on(Razorpay.EVENT_PAYMENT_ERROR, _onError);
    _rzp.on(Razorpay.EVENT_EXTERNAL_WALLET, _onExternal);
  }

  @override
  void dispose() {
    _rzp.clear();
    _amount.dispose();
    super.dispose();
  }

  int? get _paise => paiseFromText(_amount.text);

  String? get _problem {
    final p = _paise;
    final s = widget.summary;
    if (p == null) return 'Enter an amount in rupees.';
    if (p < s.minTopup) return 'The minimum is ${rupees(s.minTopup)}.';
    if (p > s.canAdd) return s.canAdd <= 0 ? 'You cannot add more money today.' : 'You can add up to ${rupees(s.canAdd)} now.';
    return null;
  }

  Future<void> _pay() async {
    final p = _paise;
    if (p == null || _problem != null) return;
    HapticFeedback.mediumImpact();
    _key ??= WalletApi.newKey();
    setState(() {
      _stage = _Stage.paying;
      _message = 'Starting the payment…';
    });
    final r = await WalletApi.instance.createTopup(p, _key!);
    if (!mounted) return;
    if (!r.ok) {
      setState(() {
        _stage = _Stage.failed;
        _message = r.message('Could not start the payment. Please try again.');
      });
      _key = null;
      return;
    }
    _topupId = r.body['topup_id'] as String?;
    _orderId = r.body['razorpay_order_id'] as String?;
    final prefill = (r.body['prefill'] as Map?)?.cast<String, dynamic>() ?? const {};
    try {
      _rzp.open({
        'key': r.body['key_id'],
        'order_id': _orderId,
        'amount': r.body['amount_paise'],
        'currency': 'INR',
        'name': 'MyAssistant',
        'description': 'Add money to your wallet',
        'prefill': {
          if ((prefill['name'] as String?)?.isNotEmpty == true) 'name': prefill['name'],
          if ((prefill['email'] as String?)?.isNotEmpty == true) 'email': prefill['email'],
        },
        'theme': {'color': '#8B5CF6'},
        'retry': {'enabled': true, 'max_count': 2},
      });
    } catch (e) {
      AppLog.add('wallet', 'checkout failed to open: $e');
      setState(() {
        _stage = _Stage.failed;
        _message = 'Could not open the payment page. Please try again.';
      });
    }
  }

  Future<void> _onSuccess(PaymentSuccessResponse resp) async {
    if (!mounted || _topupId == null) return;
    setState(() {
      _stage = _Stage.confirming;
      _message = 'Payment received. Adding it to your wallet…';
    });
    final v = await WalletApi.instance.verifyTopup(_topupId!,
        paymentId: resp.paymentId ?? '', orderId: resp.orderId ?? _orderId ?? '', signature: resp.signature ?? '');
    if (!mounted) return;
    var status = (v.body['status'] as String?) ?? (v.ok ? 'pending' : 'error');
    // The webhook may land a moment later: wait up to 30 s for the credit.
    for (var i = 0; i < 15 && status != 'credited' && status != 'failed'; i++) {
      await Future<void>.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      final s = await WalletApi.instance.topupStatus(_topupId!);
      status = (s.body['status'] as String?) ?? status;
    }
    await WalletApi.instance.refresh();
    if (!mounted) return;
    setState(() {
      if (status == 'credited') {
        _stage = _Stage.done;
        _message = '${rupees(_paise ?? 0)} added to your wallet.';
        HapticFeedback.heavyImpact();
      } else if (status == 'failed' || status == 'flagged') {
        _stage = _Stage.failed;
        _message = 'The payment could not be added. If money left your account, it will be returned.';
      } else {
        _stage = _Stage.done;
        _message = 'Your payment is being confirmed. It will appear in your wallet within a few minutes.';
      }
    });
  }

  void _onError(PaymentFailureResponse resp) {
    if (!mounted) return;
    final cancelled = resp.code == Razorpay.PAYMENT_CANCELLED;
    setState(() {
      _stage = _Stage.failed;
      _message = cancelled ? 'Payment cancelled. No money was taken.' : (resp.message?.isNotEmpty == true
          ? 'Payment failed: ${resp.message}'
          : 'Payment failed. No money was taken.');
    });
    _key = null; // a new tap is a new attempt
  }

  void _onExternal(ExternalWalletResponse resp) {
    if (!mounted) return;
    setState(() {
      _stage = _Stage.confirming;
      _message = 'Finishing in ${resp.walletName ?? 'your wallet app'}…';
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.summary;
    final busy = _stage == _Stage.paying || _stage == _Stage.confirming;
    final finished = _stage == _Stage.done;
    return _sheetFrame(context, title: 'Add money', children: [
      if (!finished) ...[
        TextField(
          controller: _amount,
          enabled: !busy,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
          style: NeonType.manrope(30, FontWeight.w800).copyWith(color: Neon.textHi),
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            prefixText: '₹ ',
            prefixStyle: NeonType.manrope(30, FontWeight.w800).copyWith(color: Neon.textLo),
            border: InputBorder.none,
            errorText: _amount.text.isEmpty ? null : _problem,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final p in _presets)
            ChoiceChip(
              label: Text(rupees(p)),
              selected: _paise == p,
              onSelected: busy ? null : (_) => setState(() => _amount.text = (p ~/ 100).toString()),
            ),
        ]),
        const SizedBox(height: 10),
        Text(
          'Up to ${rupees(s.canAdd > 0 ? s.canAdd : 0)} can be added now · UPI, card or netbanking',
          style: TextStyle(color: Neon.textLo, fontSize: 12.5),
        ),
        const SizedBox(height: 18),
      ],
      if (_message.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(children: [
            if (busy)
              const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            else
              Icon(_stage == _Stage.failed ? Icons.error_outline_rounded : Icons.check_circle_rounded,
                  color: _stage == _Stage.failed ? Neon.warning : Neon.success),
            const SizedBox(width: 10),
            Expanded(child: Text(_message, style: TextStyle(color: Neon.textHi, fontSize: 14, height: 1.35))),
          ]),
        ),
      if (finished)
        FilledButton(style: _primary(), onPressed: () => Navigator.pop(context, true), child: const Text('Done'))
      else
        FilledButton(
          style: _primary(),
          onPressed: busy || _problem != null || !s.paymentsReady ? null : _pay,
          child: Text(!s.paymentsReady
              ? 'Payments are not available yet'
              : busy
                  ? 'Please wait…'
                  : 'Pay ${_paise == null ? '' : rupees(_paise!)}'),
        ),
    ]);
  }
}

/* ======================================================================= */
/*  PIN                                                                    */
/* ======================================================================= */

/// Asks for the wallet PIN and returns a step-up token, or null. When no
/// PIN is set yet, it sets one first.
Future<String?> askStepUp(BuildContext context, {required String why}) async {
  final s = WalletApi.instance.summary.value ?? await WalletApi.instance.refresh();
  if (!context.mounted) return null;
  if (s != null && !s.hasPin) {
    final made = await showSetPin(context);
    if (!made || !context.mounted) return null;
  }
  return showAppSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _PinSheet(why: why),
  );
}

/// Sets (or changes) the PIN; true when saved.
Future<bool> showSetPin(BuildContext context, {bool change = false}) async {
  final r = await showAppSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _SetPinSheet(change: change),
  );
  return r == true;
}

Widget _pinField(TextEditingController c, String label, {bool autofocus = false, ValueChanged<String>? onSubmitted}) {
  return TextField(
    controller: c,
    autofocus: autofocus,
    obscureText: true,
    keyboardType: TextInputType.number,
    maxLength: 6,
    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    onSubmitted: onSubmitted,
    style: NeonType.manrope(24, FontWeight.w800).copyWith(color: Neon.textHi, letterSpacing: 8),
    decoration: InputDecoration(labelText: label, counterText: ''),
  );
}

class _PinSheet extends StatefulWidget {
  const _PinSheet({required this.why});
  final String why;

  @override
  State<_PinSheet> createState() => _PinSheetState();
}

class _PinSheetState extends State<_PinSheet> {
  final _pin = TextEditingController();
  String _error = '';
  bool _busy = false;

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  Future<void> _go() async {
    if (_pin.text.length < 4 || _busy) return;
    setState(() {
      _busy = true;
      _error = '';
    });
    final r = await WalletApi.instance.stepUp(_pin.text);
    if (!mounted) return;
    if (r.ok) {
      Navigator.pop(context, r.body['step_up_token'] as String?);
      return;
    }
    _pin.clear();
    setState(() {
      _busy = false;
      _error = r.message('Wrong PIN.');
    });
  }

  @override
  Widget build(BuildContext context) {
    return _sheetFrame(context, title: 'Enter your wallet PIN', children: [
      Text(widget.why, style: TextStyle(color: Neon.textLo, fontSize: 14)),
      const SizedBox(height: 12),
      _pinField(_pin, 'PIN', autofocus: true, onSubmitted: (_) => _go()),
      if (_error.isNotEmpty) Text(_error, style: TextStyle(color: Neon.error, fontSize: 13)),
      const SizedBox(height: 16),
      FilledButton(style: _primary(), onPressed: _busy ? null : _go, child: Text(_busy ? 'Checking…' : 'Continue')),
    ]);
  }
}

class _SetPinSheet extends StatefulWidget {
  const _SetPinSheet({required this.change});
  final bool change;

  @override
  State<_SetPinSheet> createState() => _SetPinSheetState();
}

class _SetPinSheetState extends State<_SetPinSheet> {
  final _current = TextEditingController();
  final _pin = TextEditingController();
  final _again = TextEditingController();
  String _error = '';
  bool _busy = false;

  @override
  void dispose() {
    _current.dispose();
    _pin.dispose();
    _again.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_pin.text != _again.text) {
      setState(() => _error = 'The two PINs do not match.');
      return;
    }
    setState(() {
      _busy = true;
      _error = '';
    });
    final r = await WalletApi.instance.setPin(_pin.text, current: widget.change ? _current.text : null);
    if (!mounted) return;
    if (r.ok) {
      await WalletApi.instance.refresh();
      if (mounted) Navigator.pop(context, true);
      return;
    }
    setState(() {
      _busy = false;
      _error = r.message('Could not save the PIN.');
    });
  }

  @override
  Widget build(BuildContext context) {
    return _sheetFrame(context, title: widget.change ? 'Change wallet PIN' : 'Set a wallet PIN', children: [
      Text('Your PIN protects large payments and refunds. Use 4 to 6 digits that are hard to guess.',
          style: TextStyle(color: Neon.textLo, fontSize: 14, height: 1.35)),
      const SizedBox(height: 8),
      if (widget.change) _pinField(_current, 'Current PIN', autofocus: true),
      _pinField(_pin, 'New PIN', autofocus: !widget.change),
      _pinField(_again, 'Repeat the new PIN', onSubmitted: (_) => _save()),
      if (_error.isNotEmpty) Text(_error, style: TextStyle(color: Neon.error, fontSize: 13)),
      const SizedBox(height: 16),
      FilledButton(style: _primary(), onPressed: _busy ? null : _save, child: Text(_busy ? 'Saving…' : 'Save PIN')),
    ]);
  }
}

/* ======================================================================= */
/*  REFUND                                                                 */
/* ======================================================================= */

/// Asks for money back to the original payment method; true when asked.
Future<bool> showRefund(BuildContext context) async {
  final refundable = await WalletApi.instance.refundable();
  if (!context.mounted) return false;
  final r = await showAppSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _RefundSheet(refundable: refundable),
  );
  return r == true;
}

class _RefundSheet extends StatefulWidget {
  const _RefundSheet({required this.refundable});
  final int refundable;

  @override
  State<_RefundSheet> createState() => _RefundSheetState();
}

class _RefundSheetState extends State<_RefundSheet> {
  late final _amount = TextEditingController(text: (widget.refundable ~/ 100).toString());
  String _error = '';
  bool _busy = false;
  final String _key = WalletApi.newKey();

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _go() async {
    final p = paiseFromText(_amount.text);
    if (p == null || p <= 0 || p > widget.refundable) {
      setState(() => _error = 'Enter an amount up to ${rupees(widget.refundable)}.');
      return;
    }
    final token = await askStepUp(context, why: 'Confirm the refund of ${rupees(p)}.');
    if (token == null || !mounted) return;
    setState(() {
      _busy = true;
      _error = '';
    });
    final r = await WalletApi.instance.requestRefund(p, key: _key, stepUpToken: token);
    await WalletApi.instance.refresh();
    if (!mounted) return;
    if (r.ok) {
      Navigator.pop(context, true);
      return;
    }
    setState(() {
      _busy = false;
      _error = r.message('Could not request the refund.');
    });
  }

  @override
  Widget build(BuildContext context) {
    final none = widget.refundable <= 0;
    return _sheetFrame(context, title: 'Get money back', children: [
      Text(
        none
            ? 'There is no money that can be refunded. Bonus credit and money added more than six months ago cannot be refunded.'
            : 'Up to ${rupees(widget.refundable)} can go back to the payment method you used. Refunds usually arrive in 5 to 7 working days. Bonus credit is not refunded.',
        style: TextStyle(color: Neon.textLo, fontSize: 14, height: 1.35),
      ),
      if (!none) ...[
        const SizedBox(height: 10),
        TextField(
          controller: _amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
          style: NeonType.manrope(26, FontWeight.w800).copyWith(color: Neon.textHi),
          decoration: const InputDecoration(prefixText: '₹ ', border: InputBorder.none),
        ),
      ],
      if (_error.isNotEmpty) Text(_error, style: TextStyle(color: Neon.error, fontSize: 13)),
      const SizedBox(height: 16),
      FilledButton(
        style: _primary(),
        onPressed: none || _busy ? null : _go,
        child: Text(_busy ? 'Requesting…' : 'Request refund'),
      ),
    ]);
  }
}
