import 'package:flutter/material.dart';

import '../../design/apple_kit.dart';
import '../../design/neon_scaffold.dart';
import '../../design/neon_tokens.dart';
import '../../widgets/neon_cards.dart';
import 'refer_screen.dart';
import 'wallet_api.dart';
import 'wallet_sheets.dart';

/// ─────────────────────────────────────────────────────────────────────────
///  WALLET (2026-11-22). Hub → Wallet. The balance (cash + bonus), Add
///  money, Get money back, Refer and earn, the PIN, and what happened
///  lately. Everything shown is read from the server.
/// ─────────────────────────────────────────────────────────────────────────
class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final _api = WalletApi.instance;
  List<WalletTxn> _recent = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await _api.refresh();
    final (items, _) = await _api.transactions(limit: 5);
    if (!mounted) return;
    setState(() {
      _recent = items;
      _loading = false;
    });
  }

  Future<void> _addMoney(WalletSummary s) async {
    if (await showAddMoney(context, s)) await _load();
  }

  Future<void> _refund() async {
    if (await showRefund(context)) {
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Refund requested. It usually arrives in 5 to 7 working days.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return NeonScaffold(
      appBar: appleAppBar(context, 'Wallet'),
      body: ValueListenableBuilder<WalletSummary?>(
        valueListenable: _api.summary,
        builder: (context, s, _) {
          if (s == null && _loading) return const Center(child: CircularProgressIndicator());
          if (s == null || !s.available) {
            return _Message(
              icon: Icons.account_balance_wallet_outlined,
              text: s == null ? 'The wallet could not be loaded. Please check your connection.' : 'The wallet is not available yet.',
              onRetry: s == null ? _load : null,
            );
          }
          return RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 32 + MediaQuery.paddingOf(context).bottom),
              children: [
                if (WalletApi.preview) const _PreviewNote(),
                _BalanceCard(summary: s, onAdd: () => _addMoney(s), onRefund: _refund),
                const SizedBox(height: 14),
                _RowCard(
                  icon: Icons.card_giftcard_rounded,
                  tint: Neon.success,
                  title: 'Refer and earn',
                  line: 'Invite friends and both of you get bonus credit',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ReferScreen())),
                ),
                const SizedBox(height: 10),
                _RowCard(
                  icon: Icons.lock_rounded,
                  tint: Neon.accentA,
                  title: s.hasPin ? 'Change wallet PIN' : 'Set a wallet PIN',
                  line: 'Needed for payments over ${rupees(s.stepUpAbove)} and for refunds',
                  onTap: () async {
                    if (await showSetPin(context, change: s.hasPin)) await _load();
                  },
                ),
                const SizedBox(height: 22),
                Row(children: [
                  Expanded(child: Text('RECENT ACTIVITY', style: NeonType.eyebrow.copyWith(color: Neon.textLo))),
                  if (_recent.isNotEmpty)
                    TextButton(
                      onPressed: () => Navigator.of(context)
                          .push(MaterialPageRoute<void>(builder: (_) => const WalletTransactionsScreen())),
                      child: const Text('See all'),
                    ),
                ]),
                const SizedBox(height: 6),
                if (_recent.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text('No activity yet. Add money to get started.',
                        textAlign: TextAlign.center, style: TextStyle(color: Neon.textLo)),
                  )
                else
                  GlassCard(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(children: [for (final t in _recent) TxnTile(t)]),
                  ),
                const SizedBox(height: 18),
                Text(
                  'Wallet money can be spent inside MyAssistant. It cannot be sent to other people or withdrawn; '
                  'unspent money you added can be refunded to your payment method.',
                  style: TextStyle(color: Neon.textDim, fontSize: 12, height: 1.4),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.summary, required this.onAdd, required this.onRefund});
  final WalletSummary summary;
  final VoidCallback onAdd;
  final VoidCallback onRefund;

  @override
  Widget build(BuildContext context) {
    final s = summary;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Neon.rCard),
        gradient: Neon.gBrand,
        boxShadow: [BoxShadow(color: Neon.violet.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.account_balance_wallet_rounded, color: Neon.onBrand.withValues(alpha: 0.9), size: 20),
            const SizedBox(width: 8),
            Text('Wallet balance', style: TextStyle(color: Neon.onBrand.withValues(alpha: 0.9), fontWeight: FontWeight.w600)),
            const Spacer(),
            if (s.frozen)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(20)),
                child: Text('On hold', style: TextStyle(color: Neon.onBrand, fontSize: 11.5, fontWeight: FontWeight.w700)),
              ),
          ]),
          const SizedBox(height: 10),
          Text(rupees(s.total),
              style: NeonType.manrope(38, FontWeight.w800).copyWith(color: Neon.onBrand, letterSpacing: -1)),
          const SizedBox(height: 4),
          Text('${rupees(s.cash)} added · ${rupees(s.bonus)} bonus',
              style: TextStyle(color: Neon.onBrand.withValues(alpha: 0.85), fontSize: 13)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: s.frozen ? null : onAdd,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add money'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Neon.accentFill,
                  minimumSize: const Size.fromHeight(46),
                  shape: const StadiumBorder(),
                  textStyle: NeonType.manrope(15, FontWeight.w800),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: s.frozen || s.cash <= 0 ? null : onRefund,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.7)),
                  minimumSize: const Size.fromHeight(46),
                  shape: const StadiumBorder(),
                  textStyle: NeonType.manrope(15, FontWeight.w700),
                ),
                child: const Text('Get money back'),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

class _RowCard extends StatelessWidget {
  const _RowCard({required this.icon, required this.tint, required this.title, required this.line, required this.onTap});
  final IconData icon;
  final Color tint;
  final String title;
  final String line;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(Neon.rLg),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: Neon.glassBox(Neon.rLg),
          child: Row(children: [
            GlassTile(icon, tint, size: 42),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: NeonType.manrope(15.5, FontWeight.w800).copyWith(color: Neon.textHi)),
                const SizedBox(height: 2),
                Text(line, style: TextStyle(color: Neon.textLo, fontSize: 12.5)),
              ]),
            ),
            Icon(Icons.chevron_right_rounded, color: Neon.textDim),
          ]),
        ),
      ),
    );
  }
}

/// One transaction: what it was, when, and the amount in or out.
class TxnTile extends StatelessWidget {
  const TxnTile(this.t, {super.key});
  final WalletTxn t;

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  IconData get _icon => switch (t.type) {
        'topup' => Icons.add_circle_rounded,
        'spend' => Icons.shopping_bag_rounded,
        'refund' => Icons.undo_rounded,
        'referral_reward' => Icons.card_giftcard_rounded,
        'bonus_expiry' => Icons.hourglass_bottom_rounded,
        _ => Icons.swap_horiz_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final color = t.incoming ? Neon.success : Neon.textHi;
    final when = '${t.at.day} ${_months[t.at.month - 1]}, '
        '${t.at.hour.toString().padLeft(2, '0')}:${t.at.minute.toString().padLeft(2, '0')}';
    return ListTile(
      leading: Icon(_icon, color: t.incoming ? Neon.success : Neon.textLo),
      title: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(color: Neon.textHi, fontWeight: FontWeight.w600)),
      subtitle: Text(t.status == 'reversed' ? '$when · reversed' : when, style: TextStyle(color: Neon.textLo, fontSize: 12)),
      trailing: Text('${t.incoming ? '+' : '−'}${rupees(t.amount)}',
          style: NeonType.manrope(15, FontWeight.w800).copyWith(color: color)),
    );
  }
}

/// Every transaction, newest first, loading more as you scroll.
class WalletTransactionsScreen extends StatefulWidget {
  const WalletTransactionsScreen({super.key});

  @override
  State<WalletTransactionsScreen> createState() => _WalletTransactionsScreenState();
}

class _WalletTransactionsScreenState extends State<WalletTransactionsScreen> {
  final _items = <WalletTxn>[];
  String? _cursor;
  bool _loading = false;
  bool _end = false;

  @override
  void initState() {
    super.initState();
    _more();
  }

  Future<void> _more() async {
    if (_loading || _end) return;
    setState(() => _loading = true);
    final (items, next) = await WalletApi.instance.transactions(cursor: _cursor);
    if (!mounted) return;
    setState(() {
      _items.addAll(items);
      _cursor = next;
      _end = next == null;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return NeonScaffold(
      appBar: appleAppBar(context, 'Wallet activity'),
      body: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.extentAfter < 300) _more();
          return false;
        },
        child: ListView.builder(
          padding: EdgeInsets.fromLTRB(8, 8, 8, 24 + MediaQuery.paddingOf(context).bottom),
          itemCount: _items.length + 1,
          itemBuilder: (_, i) {
            if (i < _items.length) return TxnTile(_items[i]);
            if (_loading) return const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()));
            if (_items.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(32),
                child: Text('No activity yet.', textAlign: TextAlign.center, style: TextStyle(color: Neon.textLo)),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.onRetry});
  final IconData icon;
  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 48, color: Neon.textDim),
          const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center, style: TextStyle(color: Neon.textLo, fontSize: 15)),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            TextButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ]),
      ),
    );
  }
}

/// Shown only in a preview build, so sample data is never taken for real money.
class _PreviewNote extends StatelessWidget {
  const _PreviewNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Neon.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Neon.warning.withValues(alpha: 0.4)),
      ),
      child: Row(children: [
        Icon(Icons.science_rounded, size: 18, color: Neon.warning),
        const SizedBox(width: 10),
        Expanded(
          child: Text('Preview: sample data on this phone only. No real money moves.',
              style: TextStyle(color: Neon.textHi, fontSize: 13)),
        ),
      ]),
    );
  }
}
