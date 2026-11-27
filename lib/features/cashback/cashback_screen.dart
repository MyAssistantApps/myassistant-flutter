import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design/apple_kit.dart';
import '../../design/neon_tokens.dart';
import '../../design/neon_widgets.dart';
import '../../services/app_feedback.dart';
import '../../widgets/neon_cards.dart';
import '../home/partner_app.dart';
import 'cashback_service.dart';

/// ─────────────────────────────────────────────────────────────────────────
///  CASHBACK — the user's side (owner, 2026-11-27).
///
///  One screen: what is available to withdraw, what is still pending and
///  what has been paid; a withdrawal to a UPI ID; where cashback can be
///  earned; and every purchase and withdrawal so far.
///
///  Reached from the banner on Everyday Services, which appears only when
///  the server offers cashback on at least one partner.
/// ─────────────────────────────────────────────────────────────────────────
class CashbackScreen extends StatefulWidget {
  const CashbackScreen({super.key, this.service, this.openStore});

  /// Test seams.
  final CashbackService? service;
  final Future<bool> Function(String id)? openStore;

  @override
  State<CashbackScreen> createState() => _CashbackScreenState();
}

class _CashbackScreenState extends State<CashbackScreen> {
  CashbackService get _service => widget.service ?? CashbackService.instance;
  CashbackSummary? _s;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await _service.load();
    if (!mounted) return;
    setState(() {
      _failed = s == null && _s == null;
      if (s != null) _s = s;
    });
  }

  Future<void> _withdraw(CashbackSummary s) async {
    HapticFeedback.selectionClick();
    final done = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Neon.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(Neon.rCard))),
      builder: (_) => _WithdrawSheet(service: _service, amountPaise: s.availablePaise),
    );
    if (done == true && mounted) {
      AppFeedback.show(
          'Your withdrawal of ${CashbackService.inr(s.availablePaise)} has been requested.',
          context: context,
          tone: FeedbackTone.success);
      await _load();
    }
  }

  Future<void> _openStore(CashbackStore store) async {
    HapticFeedback.selectionClick();
    final open = widget.openStore ?? openPartnerLink;
    final ok = await open(store.id);
    if (!ok && mounted) {
      AppFeedback.show('Unable to open ${store.name}. Please try again.',
          context: context, tone: FeedbackTone.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    return NeonScaffold(
      appBar: appleAppBar(context, 'Cashback'),
      body: s == null
          ? (_failed
              ? NeonErrorState(
                  message: 'Unable to Load Your Cashback',
                  onRetry: () {
                    setState(() => _failed = false);
                    _load();
                  })
              : const Center(
                  child: NeonLoader.inline(size: 28, semanticLabel: 'Loading')))
          : !s.enabled
              ? const NeonEmptyState(
                  icon: Icons.savings_rounded,
                  title: 'Cashback Is Not Available Yet',
                  body: 'It will appear here as soon as it is switched on.')
              : RefreshIndicator(onRefresh: _load, child: _body(s)),
    );
  }

  Widget _body(CashbackSummary s) {
    final activity = <_Activity>[
      for (final t in s.txns) _Activity.txn(t),
      for (final p in s.payouts) _Activity.payout(p),
    ]..sort((a, b) => (b.at ?? DateTime(2000)).compareTo(a.at ?? DateTime(2000)));

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(16, 8, 16, 28 + MediaQuery.paddingOf(context).bottom),
      children: [
        _balanceCard(s),
        const GroupLabel('How It Works'),
        GroupedCard(dividerInset: 60, children: [
          AppleRow(
            leading: IconTile(Icons.storefront_rounded, AppleColors.blue),
            title: 'Open a Store From Here',
            subtitle: 'Start from this page or Everyday Services, so the purchase is tracked.',
            titleMaxLines: 2,
          ),
          AppleRow(
            leading: IconTile(Icons.hourglass_bottom_rounded, AppleColors.orange),
            title: 'Your Cashback Shows as Pending',
            subtitle: 'It appears here once the store reports your purchase.',
            titleMaxLines: 2,
          ),
          AppleRow(
            leading: IconTile(Icons.account_balance_wallet_rounded, AppleColors.green),
            title: 'Withdraw to Your UPI ID',
            subtitle: 'After the store confirms the order, usually when its return period ends.',
            titleMaxLines: 2,
          ),
        ]),
        if (s.stores.isNotEmpty) ...[
          const GroupLabel('Shop With Cashback'),
          GroupedCard(children: [
            for (final store in s.stores)
              AppleRow(
                title: store.name,
                subtitle: store.rateText.isEmpty ? store.category : '${store.rateText} cashback',
                trailing: Icon(Icons.chevron_right_rounded, color: Neon.textDim),
                onTap: () => _openStore(store),
              ),
          ]),
        ],
        const GroupLabel('Activity'),
        if (activity.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Text(
                'No purchases yet. Open a store above and shop as usual; your cashback appears here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Neon.textLo, fontSize: 13.5, height: 1.4)),
          )
        else
          GroupedCard(children: [for (final a in activity) _activityRow(a)]),
        const SizedBox(height: 18),
        Text(
            'Cashback is paid from the commission a store pays MyAssistant. '
            'A cancelled or returned order earns no cashback, and some stores do not allow it.',
            style: TextStyle(color: Neon.textDim, fontSize: 12, height: 1.45)),
      ],
    );
  }

  Widget _balanceCard(CashbackSummary s) {
    final String hint;
    if (s.heldPaise > 0) {
      hint = 'A withdrawal of ${CashbackService.inr(s.heldPaise)} is being processed.';
    } else if (s.canWithdraw) {
      hint = 'Paid to your UPI ID after a short check.';
    } else {
      hint = 'You can withdraw once your available cashback reaches '
          '${CashbackService.inr(s.minPayoutPaise)}.';
    }
    return GlassCard(
      glow: Neon.success,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('AVAILABLE', style: NeonType.eyebrow.copyWith(color: Neon.textLo)),
        const SizedBox(height: 4),
        Semantics(
          label: 'Available cashback ${CashbackService.inr(s.availablePaise)}',
          excludeSemantics: true,
          child: Text(CashbackService.inr(s.availablePaise),
              style: NeonType.manrope(40, FontWeight.w800)
                  .copyWith(color: Neon.textHi, letterSpacing: -1)),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _figure('Pending', s.pendingPaise)),
          Expanded(child: _figure('Paid', s.paidPaise)),
        ]),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: s.canWithdraw ? () => _withdraw(s) : null,
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
            child: const Text('Withdraw to UPI'),
          ),
        ),
        const SizedBox(height: 8),
        Text(hint, style: TextStyle(color: Neon.textLo, fontSize: 12.5, height: 1.35)),
      ]),
    );
  }

  Widget _figure(String label, int paise) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Neon.textLo, fontSize: 12.5)),
          const SizedBox(height: 2),
          Text(CashbackService.inr(paise),
              style: NeonType.manrope(17, FontWeight.w700).copyWith(color: Neon.textHi)),
        ],
      );

  Widget _activityRow(_Activity a) => AppleRow(
        title: a.title,
        subtitle: [if (a.at != null) _date(a.at!), a.detail].where((x) => x.isNotEmpty).join(' · '),
        titleMaxLines: 2,
        trailing: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(a.amount,
                style: NeonType.manrope(14.5, FontWeight.w700).copyWith(
                    color: a.struck ? Neon.textDim : Neon.textHi,
                    decoration: a.struck ? TextDecoration.lineThrough : null)),
            const SizedBox(height: 2),
            Text(a.state, style: TextStyle(color: a.stateColor, fontSize: 11.5, fontWeight: FontWeight.w600)),
          ],
        ),
      );

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  static String _date(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';
}

/// One line of the Activity list: a purchase or a withdrawal.
class _Activity {
  _Activity.txn(CashbackTxn t)
      : title = t.store,
        detail = t.salePaise > 0 ? 'Order of ${CashbackService.inr(t.salePaise)}' : '',
        amount = CashbackService.inr(t.cashbackPaise),
        at = t.occurredAt,
        struck = t.status == CashbackStatus.rejected,
        state = switch (t.status) {
          CashbackStatus.pending => 'Pending',
          CashbackStatus.confirmed => 'Confirmed',
          CashbackStatus.rejected => 'Cancelled',
        },
        stateColor = switch (t.status) {
          CashbackStatus.pending => Neon.warningInk,
          CashbackStatus.confirmed => Neon.successInk,
          CashbackStatus.rejected => Neon.textDim,
        };

  _Activity.payout(CashbackPayout p)
      : title = 'Withdrawal to ${p.upiId}',
        detail = p.status == 'rejected' && p.note.isNotEmpty ? p.note : '',
        amount = CashbackService.inr(p.amountPaise),
        at = p.requestedAt,
        struck = p.status == 'rejected',
        state = switch (p.status) {
          'paid' => 'Paid',
          'rejected' => 'Not Completed',
          _ => 'Processing',
        },
        stateColor = switch (p.status) {
          'paid' => Neon.successInk,
          'rejected' => Neon.errorInk,
          _ => Neon.warningInk,
        };

  final String title;
  final String detail;
  final String amount;
  final DateTime? at;
  final bool struck;
  final String state;
  final Color stateColor;
}

/// The UPI ID, checked before it is sent.
class _WithdrawSheet extends StatefulWidget {
  const _WithdrawSheet({required this.service, required this.amountPaise});
  final CashbackService service;
  final int amountPaise;

  @override
  State<_WithdrawSheet> createState() => _WithdrawSheetState();
}

class _WithdrawSheetState extends State<_WithdrawSheet> {
  final _upi = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _upi.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_busy) return;
    final upi = _upi.text.trim();
    if (!CashbackService.validUpi(upi)) {
      setState(() => _error = 'Please enter a valid UPI ID, for example name@bank.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final problem = await widget.service.withdraw(upi);
    if (!mounted) return;
    if (problem == null) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _busy = false;
        _error = problem;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Withdraw ${CashbackService.inr(widget.amountPaise)}',
            style: NeonType.manrope(22, FontWeight.w800).copyWith(color: Neon.textHi)),
        const SizedBox(height: 6),
        Text('Enter the UPI ID the amount should be sent to. Please check it carefully.',
            style: TextStyle(color: Neon.textLo, fontSize: 13.5, height: 1.4)),
        const SizedBox(height: 16),
        TextField(
          controller: _upi,
          autofocus: true,
          enabled: !_busy,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          enableSuggestions: false,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _send(),
          style: TextStyle(color: Neon.textHi),
          decoration: InputDecoration(
            labelText: 'UPI ID',
            hintText: 'name@bank',
            errorText: _error,
            errorMaxLines: 3,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(Neon.rInner)),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _busy ? null : _send,
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
            child: Text(_busy ? 'Requesting…' : 'Request Withdrawal'),
          ),
        ),
      ]),
    );
  }
}

/// The way in, on Everyday Services: the balance once it is known.
class CashbackBanner extends StatefulWidget {
  const CashbackBanner({super.key, required this.onOpen, this.service});
  final VoidCallback onOpen;
  final CashbackService? service;

  @override
  State<CashbackBanner> createState() => _CashbackBannerState();
}

class _CashbackBannerState extends State<CashbackBanner> {
  CashbackService get _service => widget.service ?? CashbackService.instance;

  @override
  void initState() {
    super.initState();
    if (_service.summary.value == null) _service.load();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<CashbackSummary?>(
        valueListenable: _service.summary,
        builder: (_, s, __) {
          final earned = s == null ? 0 : s.availablePaise + s.pendingPaise;
          final line = earned > 0
              ? '${CashbackService.inr(s!.availablePaise)} available · ${CashbackService.inr(s.pendingPaise)} pending'
              : 'Shop at the stores marked ₹ and earn on every order.';
          return Semantics(
            button: true,
            label: 'Cashback. $line',
            excludeSemantics: true,
            child: GroupedCard(dividerInset: 60, children: [
              AppleRow(
                leading: IconTile(Icons.savings_rounded, AppleColors.green),
                title: 'Cashback',
                subtitle: line,
                titleMaxLines: 1,
                trailing: Icon(Icons.chevron_right_rounded, color: Neon.textDim),
                onTap: widget.onOpen,
              ),
            ]),
          );
        },
      );
}

/// The small ₹ on a partner's icon: a purchase here earns cashback.
class CashbackDot extends StatelessWidget {
  const CashbackDot({super.key});

  @override
  Widget build(BuildContext context) => Container(
        width: 20,
        height: 20,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Neon.success,
          shape: BoxShape.circle,
          border: Border.all(color: Neon.surface, width: 2),
        ),
        child: const Text('₹',
            style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800, height: 1)),
      );
}
