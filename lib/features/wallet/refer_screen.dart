import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../design/apple_kit.dart';
import '../../design/neon_scaffold.dart';
import '../../design/neon_tokens.dart';
import '../../widgets/neon_cards.dart';
import 'wallet_api.dart';

/// ─────────────────────────────────────────────────────────────────────────
///  REFER AND EARN (2026-11-22, wallet plan Phase 3). Your code and share
///  link, what you have earned, your friends' progress (initials only),
///  and — for a new account — a place to enter someone's code.
/// ─────────────────────────────────────────────────────────────────────────
class ReferScreen extends StatefulWidget {
  const ReferScreen({super.key});

  @override
  State<ReferScreen> createState() => _ReferScreenState();
}

class _ReferScreenState extends State<ReferScreen> {
  Map<String, dynamic>? _me;
  List<Map<String, dynamic>> _history = const [];
  String _error = '';
  final _code = TextEditingController();
  bool _applying = false;
  String _applyNote = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final me = await WalletApi.instance.referralMe();
    final h = await WalletApi.instance.referralHistory();
    if (!mounted) return;
    setState(() {
      if (me.ok) {
        _me = me.body;
        _error = '';
      } else {
        _error = me.message('Could not load your referral details.');
      }
      _history = (h.body['items'] as List? ?? const []).whereType<Map>().map((m) => m.cast<String, dynamic>()).toList();
    });
  }

  int _p(String k) => (_me?[k] as num?)?.toInt() ?? 0;

  Future<void> _share() async {
    final url = _me?['share_url'] as String?;
    final code = _me?['code'] as String?;
    if (url == null || code == null) return;
    HapticFeedback.selectionClick();
    await Share.share(
      'Join me on MyAssistant, the personal assistant that gets things done. '
      'Use my code $code when you sign up and get ${rupees(_p('referee_reward_paise'))} bonus '
      'after your first top-up of ${rupees(_p('min_topup_paise'))}: $url',
    );
  }

  Future<void> _apply() async {
    if (_code.text.trim().isEmpty || _applying) return;
    setState(() {
      _applying = true;
      _applyNote = '';
    });
    final r = await WalletApi.instance.applyCode(_code.text.trim());
    if (!mounted) return;
    setState(() {
      _applying = false;
      _applyNote = r.ok ? (r.body['message'] as String? ?? 'Code added.') : r.message('This code cannot be used.');
    });
    if (r.ok) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final code = _me?['code'] as String?;
    return NeonScaffold(
      appBar: appleAppBar(context, 'Refer and earn'),
      body: _me == null && _error.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 32 + MediaQuery.paddingOf(context).bottom),
                children: [
                  if (_error.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(_error, textAlign: TextAlign.center, style: TextStyle(color: Neon.textLo)),
                    ),
                  if (_me != null) ...[
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(Neon.rCard),
                        gradient: LinearGradient(colors: [
                          Color.alphaBlend(Neon.success.withValues(alpha: 0.25), Neon.surface),
                          Neon.surface,
                        ]),
                        border: Border.all(color: Neon.success.withValues(alpha: 0.45)),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Give ${rupees(_p('referee_reward_paise'))}, get ${rupees(_p('referrer_reward_paise'))}',
                            style: NeonType.manrope(22, FontWeight.w800).copyWith(color: Neon.textHi)),
                        const SizedBox(height: 6),
                        Text(
                          'When a friend joins with your code and adds ${rupees(_p('min_topup_paise'))} or more, '
                          'they get ${rupees(_p('referee_reward_paise'))} and you get ${rupees(_p('referrer_reward_paise'))} '
                          'as bonus credit, about a week after their payment.',
                          style: TextStyle(color: Neon.textLo, fontSize: 13.5, height: 1.4),
                        ),
                        const SizedBox(height: 16),
                        if (code != null)
                          Row(children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(Neon.rMd),
                                  border: Border.all(color: Neon.hairline, width: 1.5),
                                ),
                                child: SelectableText(code,
                                    style: NeonType.manrope(22, FontWeight.w800)
                                        .copyWith(color: Neon.textHi, letterSpacing: 4)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filledTonal(
                              tooltip: 'Copy code',
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: code));
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(const SnackBar(content: Text('Code copied.')));
                              },
                              icon: const Icon(Icons.copy_rounded),
                            ),
                          ]),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: code == null ? null : _share,
                          icon: const Icon(Icons.share_rounded),
                          label: const Text('Share with friends'),
                          style: FilledButton.styleFrom(
                            backgroundColor: Neon.accentFill,
                            foregroundColor: Neon.onAccent,
                            minimumSize: const Size.fromHeight(50),
                            shape: const StadiumBorder(),
                            textStyle: NeonType.manrope(15.5, FontWeight.w800),
                          ),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 14),
                    Row(children: [
                      Expanded(child: _Stat(rupees(_p('rewards_earned_paise')), 'earned')),
                      const SizedBox(width: 10),
                      Expanded(child: _Stat('${_p('rewarded')}', 'friends rewarded')),
                      const SizedBox(width: 10),
                      Expanded(child: _Stat('${_p('pending')}', 'on the way')),
                    ]),
                    if (_me?['can_apply_code'] == true) ...[
                      const SizedBox(height: 22),
                      Text('HAVE A REFERRAL CODE?', style: NeonType.eyebrow.copyWith(color: Neon.textLo)),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(
                          child: TextField(
                            controller: _code,
                            textCapitalization: TextCapitalization.characters,
                            maxLength: 9,
                            decoration: const InputDecoration(hintText: 'Enter the code', counterText: ''),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(onPressed: _applying ? null : _apply, child: Text(_applying ? '…' : 'Apply')),
                      ]),
                      if (_applyNote.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(_applyNote, style: TextStyle(color: Neon.textLo, fontSize: 13)),
                        ),
                    ],
                    const SizedBox(height: 22),
                    Text('YOUR INVITES', style: NeonType.eyebrow.copyWith(color: Neon.textLo)),
                    const SizedBox(height: 8),
                    if (_history.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text('No one has joined with your code yet.',
                            textAlign: TextAlign.center, style: TextStyle(color: Neon.textLo)),
                      )
                    else
                      GlassCard(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Column(children: [
                          for (final h in _history)
                            ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Neon.surfaceHigh,
                                child: Text('${h['friend']}'.replaceAll('.', ''),
                                    style: TextStyle(color: Neon.textHi, fontWeight: FontWeight.w700, fontSize: 13)),
                              ),
                              title: Text('${h['status_text']}', style: TextStyle(color: Neon.textHi)),
                              trailing: ((h['reward_paise'] as num?)?.toInt() ?? 0) > 0
                                  ? Text('+${rupees((h['reward_paise'] as num).toInt())}',
                                      style: NeonType.manrope(14, FontWeight.w800).copyWith(color: Neon.success))
                                  : null,
                            ),
                        ]),
                      ),
                    const SizedBox(height: 18),
                    Text(
                      'Bonus credit can be spent in MyAssistant, is used before money you added, cannot be refunded '
                      'or withdrawn, and expires after 90 days. Rewards need the friend\'s verified phone number and '
                      'a payment method different from yours.',
                      style: TextStyle(color: Neon.textDim, fontSize: 12, height: 1.4),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.value, this.label);
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: Neon.glassBox(Neon.rLg),
      child: Column(children: [
        Text(value, style: NeonType.manrope(18, FontWeight.w800).copyWith(color: Neon.textHi)),
        const SizedBox(height: 2),
        Text(label, textAlign: TextAlign.center, style: TextStyle(color: Neon.textLo, fontSize: 11.5)),
      ]),
    );
  }
}
