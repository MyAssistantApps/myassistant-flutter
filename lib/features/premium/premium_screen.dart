import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design/motion.dart' show Tappable;
import '../../design/neon_tokens.dart';
import '../../services/app_feedback.dart';
import '../../widgets/robot_badge.dart';
import 'premium_plans.dart';

/// PREMIUM (2026-11-12) — the plans page: Plus, Pro and Business, monthly or
/// yearly, a 14-day free trial of Pro and credit top-ups.
///
/// Follows the app theme (2026-11-13): light or dark, and the user's accent,
/// all read from [Neon] through [_P] below — a soft wash of the accent at the
/// top, raised cards, and the brand fill on the featured plan.
///
/// Billing isn't wired yet. Every buy button goes through [onPurchase];
/// without one, the page says payments are coming soon.
class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key, this.onPurchase});

  /// Called with the plan id ('plus' | 'pro' | 'business' | 'credits_1000'…)
  /// and the period. Plug Play Billing in here.
  final Future<void> Function(String productId, BillingPeriod period)? onPurchase;

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

/// The page's palette, taken from the app theme ([Neon]).
abstract final class _P {
  static bool get dark => Neon.isDark;
  static Color get bgTop => Color.lerp(Neon.bg, Neon.violet, dark ? 0.16 : 0.10)!;
  static Color get bgBottom => Neon.bg;
  static Color get card => Neon.surface;
  static Color get cardLo => Color.lerp(Neon.surface, Neon.bg, dark ? 0.5 : 0.35)!;
  static Color get cardHi => Color.lerp(Neon.surface, Neon.violet, dark ? 0.16 : 0.07)!;
  static Color get rim => Neon.violet.withValues(alpha: dark ? 0.22 : 0.16);
  static Color get violet => Neon.violet;
  static Color get violetSoft =>
      dark ? Color.lerp(Neon.violet, Colors.white, 0.35)! : Neon.violet;
  static Color get magenta => Neon.pink;
  static Color get gold => dark ? const Color(0xFFF2C14E) : const Color(0xFFC98A04);
  static Color get text => Neon.textHi;
  static Color get textLo => Neon.textLo;
  static Color get textDim => Neon.textDim;
  static Color get ok => Neon.violet;
  static Color get onBrand => Neon.onAccent;
  static LinearGradient get brand => Neon.gBrand;
}

class _PremiumScreenState extends State<PremiumScreen> {
  BillingPeriod _period = BillingPeriod.yearly;
  String _selected = 'pro';
  final _scroll = ScrollController();
  final _plansKey = GlobalKey();

  PremiumPlan get _plan => premiumPlans.firstWhere((p) => p.id == _selected);

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _buy(String productId) async {
    HapticFeedback.mediumImpact();
    final cb = widget.onPurchase;
    if (cb == null) {
      AppFeedback.show(
        "Payments open in the next update. Thanks for wanting in!",
        context: context,
      );
      return;
    }
    await cb(productId, _period);
  }

  void _toPlans() {
    final ctx = _plansKey.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(ctx,
        duration: const Duration(milliseconds: 420), curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _P.dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _P.bgBottom,
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_P.bgTop, _P.bgBottom],
            ),
          ),
          child: Stack(children: [
            const Positioned.fill(child: IgnorePointer(child: _Stars())),
            SafeArea(
              child: ListView(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                children: [
                  _topBar(context),
                  const SizedBox(height: 8),
                  const _Hero(),
                  const SizedBox(height: 18),
                  const _UnlockCard(),
                  const SizedBox(height: 22),
                  _PeriodToggle(
                    period: _period,
                    onChanged: (p) => setState(() => _period = p),
                  ),
                  const SizedBox(height: 22),
                  _planRow(key: _plansKey),
                  const SizedBox(height: 14),
                  _TrialNote(onStart: () => _buy('pro_trial')),
                  const SizedBox(height: 22),
                  _Includes(plan: _plan),
                  const SizedBox(height: 22),
                  _CreditPacks(onBuy: (p) => _buy('credits_${p.credits}')),
                  const SizedBox(height: 18),
                  const _SecureStrip(),
                  const SizedBox(height: 20),
                  const _Footer(),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _topBar(BuildContext context) {
    return Row(children: [
      Tappable(
        semanticLabel: 'Close',
        onTap: () => Navigator.of(context).maybePop(),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _P.card,
            border: Border.all(color: _P.rim),
          ),
          child: Icon(Icons.close_rounded, color: _P.textLo, size: 22),
        ),
      ),
      const Spacer(),
      Tappable(
        semanticLabel: 'See plans',
        onTap: _toPlans,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: _P.card,
            border: Border.all(color: _P.violet.withValues(alpha: 0.45)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.workspace_premium_rounded, color: _P.gold, size: 18),
            const SizedBox(width: 6),
            Text('Go Premium',
                style: TextStyle(
                    color: _P.text, fontWeight: FontWeight.w600, fontSize: 14)),
          ]),
        ),
      ),
    ]);
  }

  Widget _planRow({Key? key}) {
    return IntrinsicHeight(
      key: key,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < premiumPlans.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: _PlanCard(
                plan: premiumPlans[i],
                period: _period,
                featured: premiumPlans[i].badge != null,
                selected: premiumPlans[i].id == _selected,
                onSelect: () => setState(() => _selected = premiumPlans[i].id),
                onBuy: () => _buy(premiumPlans[i].id),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/* ───────────────────────────── hero ───────────────────────────── */

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: Stack(clipBehavior: Clip.none, children: [
        // A soft violet swoosh behind the robot.
        Positioned(
          right: -30,
          top: 30,
          child: Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                _P.violet.withValues(alpha: 0.28),
                _P.violet.withValues(alpha: 0.0),
              ]),
            ),
          ),
        ),
        const Positioned(right: 4, top: 34, child: RobotBadge(size: 148)),
        // The crown, floating above the robot.
        Positioned(
          right: 104,
          top: 6,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: _P.gold.withValues(alpha: 0.25),
                    blurRadius: 18,
                    spreadRadius: 1),
              ],
            ),
            child: Transform.rotate(
              angle: -0.18,
              child: Icon(Icons.workspace_premium_rounded,
                  color: _P.gold, size: 38),
            ),
          ),
        ),
        Positioned(
          left: 0,
          top: 24,
          right: 140,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(
                        text: 'My', style: TextStyle(color: _P.violetSoft)),
                    TextSpan(
                      text: 'Assistant',
                      style: TextStyle(
                        foreground: Paint()
                          ..shader = LinearGradient(
                            colors: [_P.violetSoft, _P.magenta],
                          ).createShader(const Rect.fromLTWH(0, 0, 160, 30)),
                      ),
                    ),
                  ]),
                  style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.8,
                      height: 1.1),
                ),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text('Premium',
                    style: TextStyle(
                        color: _P.text,
                        fontSize: 46,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.4,
                        height: 1.05)),
              ),
              const SizedBox(height: 10),
              Text('Smarter. More helpful.\nAlways with you.',
                  style: TextStyle(color: _P.textLo, fontSize: 16, height: 1.35)),
            ],
          ),
        ),
      ]),
    );
  }
}

/* ─────────────────────────── unlock card ─────────────────────────── */

class _UnlockCard extends StatelessWidget {
  const _UnlockCard();

  static const _items = [
    (Icons.mic_rounded, 'Live voice\nin 6 languages'),
    (Icons.phone_in_talk_rounded, 'AI calls\nfor you'),
    (Icons.auto_awesome_rounded, 'Posters, photos\n& videos'),
    (Icons.work_rounded, 'Meetings\n& research'),
  ];

  @override
  Widget build(BuildContext context) {
    return _Glass(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.star_rounded, color: _P.gold, size: 22),
            const SizedBox(width: 8),
            Text('Unlock powerful features',
                style: TextStyle(
                    color: _P.text, fontSize: 17, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 14),
          IntrinsicHeight(
            child: Row(children: [
              for (var i = 0; i < _items.length; i++) ...[
                if (i > 0)
                  VerticalDivider(
                      width: 1, thickness: 1, color: _P.rim.withValues(alpha: 0.6)),
                Expanded(
                  child: Column(children: [
                    Icon(_items[i].$1, color: _P.violetSoft, size: 26),
                    const SizedBox(height: 8),
                    Text(_items[i].$2,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: _P.textLo, fontSize: 12, height: 1.25)),
                  ]),
                ),
              ],
            ]),
          ),
        ],
      ),
    );
  }
}

/* ─────────────────────────── period toggle ─────────────────────────── */

class _PeriodToggle extends StatelessWidget {
  const _PeriodToggle({required this.period, required this.onChanged});
  final BillingPeriod period;
  final ValueChanged<BillingPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    final save = premiumPlans.map((p) => p.yearlySavingPercent).reduce(math.min);
    Widget seg(BillingPeriod p, String label, {String? extra}) {
      final on = p == period;
      return Expanded(
        child: Tappable(
          semanticLabel: label,
          onTap: () => onChanged(p),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: on ? _P.brand : null,
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(label,
                  style: TextStyle(
                      color: on ? _P.onBrand : _P.textLo,
                      fontWeight: FontWeight.w600,
                      fontSize: 14)),
              if (extra != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _P.gold.withValues(alpha: on ? 0.9 : 0.25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(extra,
                      style: TextStyle(
                          color: on ? const Color(0xFF2A1D00) : _P.gold,
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ]),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _P.card,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: _P.rim),
      ),
      child: Row(children: [
        seg(BillingPeriod.monthly, 'Monthly'),
        seg(BillingPeriod.yearly, 'Yearly', extra: 'Save $save%'),
      ]),
    );
  }
}

/* ───────────────────────────── plan card ───────────────────────────── */

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.period,
    required this.featured,
    required this.selected,
    required this.onSelect,
    required this.onBuy,
  });

  final PremiumPlan plan;
  final BillingPeriod period;
  final bool featured;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final yearly = period == BillingPeriod.yearly;
    final price = plan.priceFor(period);
    final borderColor = selected
        ? _P.violet.withValues(alpha: featured ? 0.85 : 0.6)
        : _P.rim;

    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      margin: EdgeInsets.only(top: featured ? 0 : 18),
      padding: const EdgeInsets.fromLTRB(8, 24, 8, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: featured
              ? [_P.cardHi, _P.card]
              : [_P.card, _P.cardLo],
        ),
        border: Border.all(color: borderColor, width: selected ? 1.4 : 1),
        boxShadow: featured
            ? [
                BoxShadow(
                    color: _P.violet.withValues(alpha: selected ? 0.28 : 0.16),
                    blurRadius: 22,
                    spreadRadius: -2),
              ]
            : null,
      ),
      child: Column(children: [
        Text(plan.name,
            style: TextStyle(
                color: _P.text, fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: FittedBox(
            key: ValueKey('$price'),
            fit: BoxFit.scaleDown,
            child: Text(rupees(price),
                style: TextStyle(
                    color: _P.text,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6)),
          ),
        ),
        Text(yearly ? '/ year' : '/ month',
            style: TextStyle(color: _P.textLo, fontSize: 13)),
        const SizedBox(height: 4),
        SizedBox(
          height: 18,
          child: yearly
              ? Text(rupees(plan.yearOfMonthly),
                  style: TextStyle(
                      color: _P.textDim,
                      fontSize: 12,
                      decoration: TextDecoration.lineThrough,
                      decorationColor: _P.textDim))
              : null,
        ),
        const SizedBox(height: 10),
        for (final h in plan.highlights)
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.check_rounded, color: _P.ok, size: 15),
              const SizedBox(width: 4),
              Expanded(
                child: Text(h,
                    style: TextStyle(
                        color: _P.textLo, fontSize: 11.5, height: 1.25)),
              ),
            ]),
          ),
        const Spacer(),
        const SizedBox(height: 8),
        _BuyButton(
          label: 'Subscribe',
          filled: featured,
          onTap: onBuy,
        ),
      ]),
    );

    return Tappable(
      scale: 0.985,
      semanticLabel: '${plan.name}, ${rupees(price)} ${yearly ? 'a year' : 'a month'}',
      onTap: onSelect,
      child: Stack(clipBehavior: Clip.none, alignment: Alignment.topCenter, children: [
        card,
        if (plan.badge != null)
          Positioned(top: -12, child: _Badge(text: plan.badge!, star: true))
        else if (plan.id == 'plus')
          const Positioned(top: 6, child: _Badge(text: 'Try first')),
      ]),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, this.star = false});
  final String text;
  final bool star;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: star ? _P.brand : null,
        color: star ? null : _P.card,
        border: Border.all(color: _P.violet.withValues(alpha: 0.55)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (star) ...[
          Icon(Icons.star_rounded, color: _P.gold, size: 13),
          const SizedBox(width: 3),
        ],
        Text(text,
            style: TextStyle(
                color: star ? _P.onBrand : _P.text,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _BuyButton extends StatelessWidget {
  const _BuyButton({required this.label, required this.filled, required this.onTap});
  final String label;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tappable(
      semanticLabel: label,
      onTap: onTap,
      child: Container(
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: filled
              ? _P.brand
              : null,
          border: filled ? null : Border.all(color: _P.violet.withValues(alpha: 0.7)),
          boxShadow: filled
              ? [
                  BoxShadow(
                      color: _P.magenta.withValues(alpha: 0.25),
                      blurRadius: 14,
                      offset: const Offset(0, 4)),
                ]
              : null,
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(label,
                  style: TextStyle(
                      color: filled ? _P.onBrand : _P.text,
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5)),
            ]),
          ),
        ),
      ),
    );
  }
}

/* ───────────────────────────── trial ───────────────────────────── */

class _TrialNote extends StatelessWidget {
  const _TrialNote({required this.onStart});
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Tappable(
      semanticLabel: 'Start your $freeTrialDays-day free trial of Pro',
      onTap: onStart,
      child: _Glass(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _P.gold.withValues(alpha: 0.14),
            ),
            child: Icon(Icons.card_giftcard_rounded, color: _P.gold, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Try Pro free for $freeTrialDays days',
                  style: TextStyle(
                      color: _P.text, fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 2),
              Text(
                  'Every Pro feature and ${grouped(freeTrialCredits)} credits. '
                  "We'll remind you 2 days before it ends.",
                  style: TextStyle(color: _P.textLo, fontSize: 12.5, height: 1.3)),
            ]),
          ),
          Icon(Icons.chevron_right_rounded, color: _P.textDim),
        ]),
      ),
    );
  }
}

/* ─────────────────────────── what's included ─────────────────────────── */

class _Includes extends StatelessWidget {
  const _Includes({required this.plan});
  final PremiumPlan plan;

  @override
  Widget build(BuildContext context) {
    return _Glass(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: Column(
          key: ValueKey(plan.id),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("What's in ${plan.name}",
                style: TextStyle(
                    color: _P.text, fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text('${plan.tagline} · tap a plan above to compare',
                style: TextStyle(color: _P.textDim, fontSize: 12.5)),
            const SizedBox(height: 12),
            for (final line in plan.includes)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    margin: const EdgeInsets.only(top: 1),
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _P.violet.withValues(alpha: 0.18),
                    ),
                    child: Icon(Icons.check_rounded, size: 13, color: _P.ok),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(line,
                        style: TextStyle(
                            color: _P.textLo, fontSize: 14, height: 1.3)),
                  ),
                ]),
              ),
          ],
        ),
      ),
    );
  }
}

/* ───────────────────────────── credits ───────────────────────────── */

class _CreditPacks extends StatelessWidget {
  const _CreditPacks({required this.onBuy});
  final ValueChanged<CreditPack> onBuy;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 4),
        child: Text('Need more credits?',
            style: TextStyle(color: _P.text, fontSize: 17, fontWeight: FontWeight.w700)),
      ),
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 12),
        child: Text('For AI calls, images, edits and videos. Top-ups never expire.',
            style: TextStyle(color: _P.textDim, fontSize: 12.5)),
      ),
      Row(children: [
        for (var i = 0; i < creditPacks.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: _pack(creditPacks[i])),
        ],
      ]),
    ]);
  }

  Widget _pack(CreditPack p) {
    return Tappable(
      semanticLabel: '${grouped(p.credits)} credits for ${rupees(p.price)}',
      onTap: () => onBuy(p),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: _P.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _P.rim),
        ),
        child: Column(children: [
          Icon(Icons.toll_rounded, color: _P.gold, size: 20),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(grouped(p.credits),
                style: TextStyle(
                    color: _P.text, fontSize: 17, fontWeight: FontWeight.w800)),
          ),
          Text('credits', style: TextStyle(color: _P.textDim, fontSize: 11)),
          const SizedBox(height: 6),
          Text(rupees(p.price),
              style: TextStyle(
                  color: _P.violetSoft, fontSize: 14, fontWeight: FontWeight.w700)),
          SizedBox(
            height: 16,
            child: p.bonus == null
                ? null
                : Text('${p.bonus} bonus',
                    style: TextStyle(color: _P.gold, fontSize: 11)),
          ),
        ]),
      ),
    );
  }
}

/* ───────────────────────── secure + footer ───────────────────────── */

class _SecureStrip extends StatelessWidget {
  const _SecureStrip();

  @override
  Widget build(BuildContext context) {
    Widget mark(String t, {bool italic = true}) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(t,
              style: TextStyle(
                  color: _P.textLo,
                  fontWeight: FontWeight.w800,
                  fontStyle: italic ? FontStyle.italic : FontStyle.normal,
                  fontSize: 13,
                  letterSpacing: -0.2)),
        );
    return _Glass(
      radius: 28,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _P.violet.withValues(alpha: 0.18),
          ),
          child: Icon(Icons.shield_rounded, color: _P.violetSoft, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Your payment is 100% secure',
                style: TextStyle(color: _P.text, fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text('Cancel any time',
                style: TextStyle(color: _P.textDim, fontSize: 11.5)),
          ]),
        ),
        Container(width: 1, height: 30, color: _P.rim),
        const SizedBox(width: 6),
        mark('UPI'),
        mark('VISA'),
        mark('RuPay'),
      ]),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.favorite_rounded, color: _P.violet, size: 16),
        const SizedBox(width: 8),
        Text('Thank you for choosing MyAssistant!',
            style: TextStyle(color: _P.textLo, fontSize: 14)),
        const SizedBox(width: 8),
        Icon(Icons.favorite_rounded, color: _P.violet, size: 16),
      ]),
      const SizedBox(height: 8),
      Text(
        'Prices include GST. Subscriptions renew automatically until cancelled.',
        textAlign: TextAlign.center,
        style: TextStyle(color: _P.textDim, fontSize: 11),
      ),
    ]);
  }
}

/* ───────────────────────────── shared ───────────────────────────── */

class _Glass extends StatelessWidget {
  const _Glass({required this.child, required this.padding, this.radius = 22});
  final Widget child;
  final EdgeInsets padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_P.card, _P.cardLo],
        ),
        border: Border.all(color: _P.rim),
        boxShadow: Neon.glassShadow,
      ),
      child: child,
    );
  }
}

/// A few still stars, drawn once.
class _Stars extends StatelessWidget {
  const _Stars();

  @override
  Widget build(BuildContext context) =>
      const RepaintBoundary(child: CustomPaint(painter: _StarPainter()));
}

class _StarPainter extends CustomPainter {
  const _StarPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final r = math.Random(7);
    final p = Paint();
    for (var i = 0; i < 38; i++) {
      final o = Offset(r.nextDouble() * size.width, r.nextDouble() * size.height * 0.45);
      final big = r.nextDouble() < 0.15;
      final dot = _P.dark ? Colors.white : _P.violet;
      p.color = dot.withValues(alpha: (big ? 0.45 : 0.18 + r.nextDouble() * 0.15) * (_P.dark ? 1 : 0.6));
      canvas.drawCircle(o, big ? 1.4 : 0.8, p);
    }
    // A faint violet wave at the bottom, as in the reference.
    final wave = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, size.height - 60)
      ..quadraticBezierTo(size.width * 0.3, size.height - 110, size.width * 0.6,
          size.height - 70)
      ..quadraticBezierTo(size.width * 0.85, size.height - 40, size.width,
          size.height - 80)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(
      wave,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_P.violet.withValues(alpha: 0.16), _P.violet.withValues(alpha: 0.02)],
        ).createShader(Rect.fromLTWH(0, size.height - 110, size.width, 110)),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
