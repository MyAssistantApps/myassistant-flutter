import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../ai/types.dart';
import '../../design/apple_kit.dart';
import '../../design/motion.dart';
import '../../design/neon_tokens.dart';
import '../../design/neon_widgets.dart';
import '../assistant/widgets/action_cards.dart' show SearchSuggestionChips;
import '../../ai/search_suggestions.dart';
import 'compare_views.dart';
import 'price_models.dart';
import 'price_service.dart';
import 'price_widgets.dart';
import 'shop_browser.dart';

/// ─────────────────────────────────────────────────────────────────────────
///  ONE COMPARISON, BuyHatke's order (2026-11-04, owner): the lowest price
///  first, then the AI's "buy now or wait", every store's price (cheapest
///  first, each opening that store), the price history, the offers and
///  coupons, and the price alert. The pages the prices came from and
///  Google's suggestions close it (Gemini API grounding terms).
/// ─────────────────────────────────────────────────────────────────────────
class PriceResultScreen extends StatefulWidget {
  const PriceResultScreen({super.key, required this.category, required this.query, this.budget, this.earlier});
  final PriceCategory category;
  final String query;
  final double? budget;

  /// A comparison from before (Recently compared): shown at once, with
  /// Refresh to check again.
  final PriceResult? earlier;

  @override
  State<PriceResultScreen> createState() => _PriceResultScreenState();
}

class _PriceResultScreenState extends State<PriceResultScreen> {
  final svc = PriceService.instance;
  PriceResult? _result;
  List<SourceLink> _sources = const [];
  List<SearchSuggestion> _suggestions = const [];
  bool _busy = false;
  String _error = '';
  int _elapsed = 0;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    svc.addListener(_changed);
    _result = widget.earlier;
    if (_result == null) _run();
  }

  @override
  void dispose() {
    svc.removeListener(_changed);
    _tick?.cancel();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _run() async {
    setState(() {
      _busy = true;
      _error = '';
      _elapsed = 0;
    });
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed++);
    });
    try {
      final a = await svc.compare(widget.category, widget.query, budget: widget.budget);
      if (!mounted) return;
      HapticFeedback.lightImpact();
      setState(() {
        _result = a.result;
        _sources = a.sources;
        _suggestions = a.suggestions;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e is PriceCompareException ? e.message : 'Something went wrong. Try again.');
    } finally {
      _tick?.cancel();
      if (mounted) setState(() => _busy = false);
    }
  }

  String get _progress {
    final where = widget.category.stores.isEmpty
        ? 'today\'s prices'
        : widget.category.stores.take(3).map((s) => s.name).join(', ');
    if (_elapsed < 5) return 'Searching $where…';
    if (_elapsed < 14) return 'Comparing prices… ${_elapsed}s';
    if (_elapsed < 30) return 'Checking offers and price history… ${_elapsed}s';
    return 'Almost there — ${_elapsed}s';
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    return NeonScaffold(
      appBar: appleAppBar(context, widget.category.label, actions: [
        if (r != null && !_busy)
          IconButton(tooltip: 'Check again', onPressed: _run, icon: const Icon(Icons.refresh_rounded)),
      ]),
      body: RefreshIndicator(
        onRefresh: _run,
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 4, 16, 32 + MediaQuery.paddingOf(context).bottom),
          children: [
            if (_busy) ...[
              _loading(),
              const SizedBox(height: 16),
            ],
            if (_error.isNotEmpty) ...[
              _errorBox(),
              const SizedBox(height: 16),
            ],
            if (r != null)
              StateSwitch(
                state: '${r.at?.millisecondsSinceEpoch}',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: _results(r),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _loading() => Container(
        padding: const EdgeInsets.all(18),
        decoration: Neon.glassBox(Neon.rCard),
        child: Row(
          children: [
            const NeonLoader(size: 34, semanticLabel: 'Comparing prices'),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.query,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: NeonType.manrope(15, FontWeight.w800).copyWith(color: Neon.textHi)),
                  const SizedBox(height: 4),
                  Text(_progress, style: TextStyle(color: Neon.textLo, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _errorBox() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Neon.error.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(Neon.rMd),
          border: Border.all(color: Neon.error.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline_rounded, color: Neon.error),
            const SizedBox(width: 10),
            Expanded(child: Text(_error, style: TextStyle(color: Neon.textHi, fontSize: 14))),
            TextButton(onPressed: _busy ? null : _run, child: const Text('Retry')),
          ],
        ),
      );

  /// Opens [o]'s page in the app, or null when it has none.
  VoidCallback? _opener(PriceOffer o) {
    final link = _link(o);
    return link.isEmpty ? null : () => openInShopBrowser(context, link, widget.category);
  }

  List<Widget> _results(PriceResult r) {
    final c = r.category;
    return [
      _header(r),
      const SizedBox(height: 14),
      // Each kind first shows what it is about.
      if (c == PriceCategory.cabs) ...[RideRouteCard(result: r), const SizedBox(height: 14)],
      if (c == PriceCategory.hotels) ...[HotelStayCard(result: r), const SizedBox(height: 14)],
      _hero(r),
      if (r.advice.isNotEmpty || r.bestPick.isNotEmpty) ...[
        const SizedBox(height: 14),
        _verdict(r),
      ],
      const SizedBox(height: 26),
      ...switch (c) {
        PriceCategory.shopping => [
            if (ProductDetailsCard.hasAny(r)) ...[ProductDetailsCard(result: r), const SizedBox(height: 26)],
            _title('Price at each store', trailing: '${r.offers.length} ${r.offers.length == 1 ? 'store' : 'stores'}'),
            const SizedBox(height: 10),
            _offers(r),
          ],
        PriceCategory.hotels => [HotelList(result: r, logo: _logo, open: _opener)],
        PriceCategory.cabs => [RideOptions(result: r, logo: _logo, open: _opener)],
        PriceCategory.grocery => [GroceryView(result: r, logo: _logo, open: _opener)],
        PriceCategory.flights => [
            _title('Price at each site', trailing: '${r.offers.length}'),
            const SizedBox(height: 10),
            _offers(r),
          ],
      },
      if (c == PriceCategory.shopping || c == PriceCategory.grocery) ...[
        const SizedBox(height: 26),
        _title('Is this a good price?'),
        const SizedBox(height: 10),
        _history(r),
      ],
      if (r.deals.isNotEmpty) ...[
        const SizedBox(height: 26),
        _title('Offers & coupons', trailing: '${r.deals.length}'),
        const SizedBox(height: 10),
        _deals(r),
      ],
      if (c != PriceCategory.cabs) ...[
        const SizedBox(height: 22),
        _alertCard(r),
      ],
      if (_sources.isNotEmpty || _suggestions.isNotEmpty) ...[
        const SizedBox(height: 26),
        _title('Where these prices came from'),
        const SizedBox(height: 10),
        _sourcesBox(),
      ],
      const SizedBox(height: 16),
      Text(
        c == PriceCategory.cabs
            ? 'Fares are estimates from the web; the app shows the real fare before you book.'
            : 'Prices as found on the web ${_when(r.at)}. They change often — the store shows the final price.',
        style: TextStyle(color: Neon.textDim, fontSize: NeonType.caption, height: 1.4),
      ),
    ];
  }

  Widget _title(String t, {String? trailing}) => Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(t,
                    style: NeonType.manrope(17, FontWeight.w800).copyWith(color: Neon.textHi, letterSpacing: -0.3)),
              ),
            ),
            if (trailing != null) Text(trailing, style: TextStyle(color: Neon.textDim, fontSize: 12.5)),
          ],
        ),
      );

  PriceStore? _store(String name) => PriceStores.named(name, [
        ...widget.category.stores,
        ...PriceStores.shopping,
        ...PriceStores.grocery,
        ...PriceStores.flights,
        ...PriceStores.hotels,
        ...PriceStores.cabs,
      ]);

  /// The store's own page: the web answer's link when it really is the
  /// store's, else the store's own search for the thing.
  String _link(PriceOffer o) {
    final s = _store(o.store);
    if (s == null) return '';
    if (o.url.isNotEmpty && s.owns(o.url)) return o.url;
    return s.urlFor(_result?.product ?? widget.query);
  }

  /// WHAT WAS COMPARED: the product, and how many stores, when.
  Widget _header(PriceResult r) {
    final tint = r.category.tint(Neon.violet);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(Neon.rPill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(r.category.icon, size: 14, color: tint),
                const SizedBox(width: 6),
                Text('${r.category.tileTitle} compare',
                    style: NeonType.manrope(12, FontWeight.w800).copyWith(color: tint)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(r.product,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style:
                  NeonType.manrope(21, FontWeight.w800).copyWith(color: Neon.textHi, letterSpacing: -0.5, height: 1.2)),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.verified_rounded, size: 15, color: Neon.success),
              const SizedBox(width: 6),
              Flexible(
                child: Text('Checked ${r.offers.length} ${r.offers.length == 1 ? 'store' : 'stores'} · ${_when(r.at)}',
                    style: TextStyle(color: Neon.textLo, fontSize: 13)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// A store's real logo when one is bundled, else its mark.
  Widget _logo(String store, double size) {
    final s = _store(store);
    final logo = brandLogoFor(store: s, host: s == null ? '${store.toLowerCase().replaceAll(' ', '')}.com' : '');
    if (logo == null) return StoreMark(s, name: store, size: size);
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.28),
      child: Image.asset(logo,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => StoreMark(s, name: store, size: size)),
    );
  }

  /// THE BEST PRICE, big and green: where, how much less than the dearest,
  /// and the way to buy it.
  Widget _hero(PriceResult r) {
    final low = r.lowest!;
    final link = _link(low);
    final green = Neon.success;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Neon.rCard),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(green.withValues(alpha: Neon.isDark ? 0.24 : 0.14), Neon.glassFill.colors.first),
            Color.alphaBlend(green.withValues(alpha: Neon.isDark ? 0.06 : 0.04), Neon.glassFill.colors.last),
          ],
        ),
        border: Border.all(color: green.withValues(alpha: 0.45)),
        boxShadow: Neon.glassShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.emoji_events_rounded, size: 18, color: green),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                    switch (r.category) {
                      PriceCategory.hotels => 'BEST DEAL · PER NIGHT',
                      PriceCategory.cabs => 'CHEAPEST RIDE',
                      PriceCategory.grocery => 'LOWEST PRICE',
                      _ => 'BEST PRICE',
                    },
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: NeonType.manrope(12.5, FontWeight.w900).copyWith(color: green, letterSpacing: 1.4)),
              ),
              if (low.offPercent != null) PriceBadge('${low.offPercent}% OFF', green),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _logo(low.store, 52),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(rupees(low.price),
                          style: NeonType.manrope(34, FontWeight.w800).copyWith(
                              color: Neon.textHi, letterSpacing: -1, height: 1.05, fontFeatures: NeonType.figures)),
                    ),
                    const SizedBox(height: 2),
                    if ((r.category == PriceCategory.hotels || r.category == PriceCategory.cabs) &&
                        (low.info.str('hotel').isNotEmpty || low.title.isNotEmpty))
                      Text(low.info.str('hotel').isNotEmpty ? low.info.str('hotel') : low.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: NeonType.manrope(14, FontWeight.w700).copyWith(color: Neon.textHi)),
                    Text.rich(
                      TextSpan(children: [
                        TextSpan(text: 'on ', style: TextStyle(color: Neon.textLo)),
                        TextSpan(text: low.store, style: TextStyle(color: Neon.textHi, fontWeight: FontWeight.w800)),
                        if (low.mrp != null) ...[
                          const TextSpan(text: '   '),
                          TextSpan(
                              text: 'MRP ${rupees(low.mrp!)}',
                              style: TextStyle(color: Neon.textDim, decoration: TextDecoration.lineThrough)),
                        ],
                      ]),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (r.saving > 0) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: green.withValues(alpha: Neon.isDark ? 0.16 : 0.10),
                borderRadius: BorderRadius.circular(Neon.rMd),
              ),
              child: Row(
                children: [
                  Icon(Icons.savings_rounded, size: 18, color: green),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text.rich(
                      TextSpan(children: [
                        const TextSpan(text: 'You save '),
                        TextSpan(text: rupees(r.saving), style: const TextStyle(fontWeight: FontWeight.w900)),
                        TextSpan(
                            text: switch (r.category) {
                          PriceCategory.hotels => ' a night vs the dearest hotel found',
                          PriceCategory.cabs => ' vs the dearest ride option',
                          _ => ' vs ${r.highest!.store}, the costliest store',
                        }),
                      ]),
                      style: TextStyle(color: Neon.textHi, fontSize: 13.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (link.isNotEmpty) ...[
            const SizedBox(height: 14),
            ApplePrimaryButton(
                label: switch (r.category) {
                  PriceCategory.hotels => 'Book on ${low.store}',
                  PriceCategory.cabs => 'Ride with ${low.store}',
                  PriceCategory.grocery => 'Order on ${low.store}',
                  _ => 'Buy on ${low.store}',
                },
                icon: Icons.shopping_cart_checkout_rounded,
                onPressed: () => openInShopBrowser(context, link, widget.category)),
          ],
        ],
      ),
    );
  }

  /// THE AI'S VERDICT, said plainly: a coloured BUY NOW / WAIT / FAIR PRICE
  /// banner, why, and the store it picks.
  Widget _verdict(PriceResult r) {
    final (color, icon, word, line) = switch (r.verdict) {
      PriceVerdict.buy => (
          Neon.success,
          Icons.thumb_up_alt_rounded,
          switch (r.category) { PriceCategory.hotels => 'BOOK NOW', PriceCategory.cabs => 'GOOD FARE', _ => 'BUY NOW' },
          switch (r.category) {
            PriceCategory.hotels => 'A good time to book',
            PriceCategory.cabs => 'Fares are normal right now',
            _ => 'A good time to buy',
          },
        ),
      PriceVerdict.wait => (
          Neon.warning,
          Icons.hourglass_top_rounded,
          'WAIT',
          r.category == PriceCategory.cabs ? 'Fares look high — try again soon' : 'The price may drop soon',
        ),
      PriceVerdict.okay => (Neon.cyan, Icons.balance_rounded, 'FAIR PRICE', 'Neither a deal nor too high'),
    };
    final pick = r.bestPick.isEmpty
        ? null
        : r.offers.where((o) => r.bestPick.toLowerCase().contains(o.store.toLowerCase())).firstOrNull;
    return Container(
      decoration: Neon.glassBox(Neon.rCard).copyWith(border: Border.all(color: color.withValues(alpha: 0.5))),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            color: color.withValues(alpha: Neon.isDark ? 0.22 : 0.14),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  child: Icon(icon, size: 19, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(word, style: NeonType.manrope(17, FontWeight.w900).copyWith(color: color, letterSpacing: 1)),
                      Text(line, style: TextStyle(color: Neon.textHi, fontSize: 12.5)),
                    ],
                  ),
                ),
                PriceBadge('AI ADVICE', Neon.violet),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (r.advice.isNotEmpty)
                  Text(r.advice, style: TextStyle(color: Neon.textHi, fontSize: 14, height: 1.45)),
                if (r.bestPick.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text('Best pick:', style: TextStyle(color: Neon.textLo, fontSize: 13)),
                      if (pick != null) _logo(pick.store, 22),
                      Text(pick?.store ?? r.bestPick,
                          style: NeonType.manrope(14, FontWeight.w800).copyWith(color: Neon.textHi)),
                      if (pick != null)
                        Text('· ${rupees(pick.price)}',
                            style: NeonType.manrope(14, FontWeight.w800).copyWith(color: color)),
                    ],
                  ),
                ],
                if (widget.budget != null) ...[
                  const SizedBox(height: 6),
                  Text('Your budget: ${rupees(widget.budget!)}', style: TextStyle(color: Neon.textDim, fontSize: 12)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// EVERY STORE, cheapest first, each with a bar for its price, so the
  /// gap is seen at a glance, and how much more it costs than the best.
  Widget _offers(PriceResult r) {
    final pick = r.bestPick.toLowerCase();
    final low = r.lowest!.price;
    final high = r.highest!.price;
    return Container(
      decoration: Neon.glassBox(Neon.rCard),
      child: Column(
        children: [
          for (final (i, o) in r.offers.indexed) ...[
            if (i > 0) Divider(height: 1, indent: 16, endIndent: 16, color: Neon.hairline),
            _offerRow(o,
                lowest: i == 0, picked: pick.isNotEmpty && pick.contains(o.store.toLowerCase()), low: low, high: high),
          ],
        ],
      ),
    );
  }

  Widget _offerRow(PriceOffer o,
      {required bool lowest, required bool picked, required double low, required double high}) {
    final link = _link(o);
    final extra = o.price - low;
    // The bar: the cheapest a third full, the dearest full.
    final fill = high <= low ? 1.0 : 0.35 + 0.65 * ((o.price - low) / (high - low));
    final same = extra < 1;
    final barColor = lowest || same ? Neon.success : Color.lerp(Neon.warning, Neon.error, (fill - 0.35) / 0.65)!;
    final row = Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _logo(o.store, 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(o.store,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: NeonType.manrope(15.5, FontWeight.w800).copyWith(color: Neon.textHi)),
                        ),
                        if (o.rating != null) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.star_rounded, size: 14, color: Neon.warning),
                          Flexible(
                            flex: 0,
                            child: Text(o.rating!.toStringAsFixed(1),
                                maxLines: 1, style: NeonType.manrope(12, FontWeight.w700).copyWith(color: Neon.textLo)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (lowest) PriceBadge('CHEAPEST', Neon.success),
                        if (picked) PriceBadge('AI PICK', Neon.violet),
                        if (!o.inStock) PriceBadge('OUT OF STOCK', Neon.error),
                        if (!lowest && same)
                          Text('Same price',
                              style: NeonType.manrope(12, FontWeight.w700).copyWith(color: Neon.success)),
                        if (!lowest && !same)
                          Text('+${rupees(extra)} more',
                              style: NeonType.manrope(12, FontWeight.w700).copyWith(color: barColor)),
                        if (o.mrp != null && o.offPercent != null)
                          Text('${o.offPercent}% off ${rupees(o.mrp!)}',
                              style: TextStyle(color: Neon.textDim, fontSize: 11.5)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 104),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(rupees(o.price),
                      style: NeonType.manrope(18, FontWeight.w800)
                          .copyWith(color: lowest ? Neon.success : Neon.textHi, fontFeatures: NeonType.figures)),
                ),
              ),
              if (link.isNotEmpty) ...[
                const SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded, color: Neon.textDim),
              ],
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(
              children: [
                Container(height: 6, color: Neon.hairline),
                FractionallySizedBox(
                  widthFactor: fill.clamp(0.0, 1.0),
                  child: Container(height: 6, color: barColor),
                ),
              ],
            ),
          ),
          if (widget.category == PriceCategory.shopping) ProductOfferExtras(offer: o),
          if (o.title.isNotEmpty || o.note.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text([o.title, o.note].where((t) => t.isNotEmpty).join(' · '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Neon.textLo, fontSize: 12, height: 1.35)),
          ],
        ],
      ),
    );
    if (link.isEmpty) return row;
    return Semantics(
      button: true,
      label: '${o.store}, ${rupees(o.price)}. Open ${o.store}',
      child: InkWell(onTap: () => openInShopBrowser(context, link, widget.category), child: row),
    );
  }

  /// IS THIS A GOOD PRICE: today's best price placed on the scale from the
  /// lowest to the highest reported, said in words, and the line of what
  /// this phone saw on its own checks (once there are two).
  Widget _history(PriceResult r) {
    final w = svc.watchFor(r.category, r.query);
    final points = w?.points ?? const <PricePoint>[];
    final h = r.history;
    final now = r.lowest!.price;
    final (color, line) = () {
      final lo = h.lowest, avg = h.average;
      if (lo != null && now <= lo * 1.02) return (Neon.success, 'Great price — at or near its lowest ever.');
      if (avg != null && avg > 0 && now < avg) {
        return (Neon.success, 'Good price — ${((avg - now) / avg * 100).round()}% below its usual price.');
      }
      if (avg != null && avg > 0 && now > avg * 1.05) {
        return (Neon.warning, 'High — ${((now - avg) / avg * 100).round()}% above its usual price. Set an alert.');
      }
      if (avg != null) return (Neon.cyan, 'About its usual price.');
      return (Neon.textLo, '');
    }();
    final lo = h.lowest, hi = h.highest;
    final scale = lo != null && hi != null && hi > lo;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: Neon.glassBox(Neon.rCard),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (line.isNotEmpty) ...[
            Row(
              children: [
                Icon(color == Neon.warning ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                    color: color, size: 22),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(line, style: NeonType.manrope(14.5, FontWeight.w800).copyWith(color: Neon.textHi))),
              ],
            ),
            const SizedBox(height: 14),
          ],
          if (scale) ...[
            LayoutBuilder(builder: (context, c) {
              final t = ((now - lo) / (hi - lo)).clamp(0.0, 1.0);
              final avgT = h.average == null ? null : ((h.average! - lo) / (hi - lo)).clamp(0.0, 1.0);
              final x = t * c.maxWidth;
              return SizedBox(
                height: 54,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 24,
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          gradient: LinearGradient(colors: [Neon.success, Neon.warning, Neon.error]),
                        ),
                      ),
                    ),
                    if (avgT != null)
                      Positioned(
                        left: avgT * c.maxWidth - 1,
                        top: 20,
                        child: Container(width: 2, height: 16, color: Neon.textLo),
                      ),
                    Positioned(
                      left: (x - 26).clamp(0.0, c.maxWidth - 52),
                      top: 0,
                      child: Container(
                        width: 52,
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        decoration: BoxDecoration(color: Neon.textHi, borderRadius: BorderRadius.circular(6)),
                        child: Text('NOW', style: NeonType.manrope(10, FontWeight.w900).copyWith(color: Neon.bg)),
                      ),
                    ),
                    Positioned(
                      left: (x - 8).clamp(0.0, c.maxWidth - 16),
                      top: 20,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: Neon.bg,
                          shape: BoxShape.circle,
                          border: Border.all(color: Neon.textHi, width: 3),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 4),
          ],
          Row(
            children: [
              _stat('Lowest', h.lowest, Neon.success),
              _stat('Usual', h.average, Neon.cyan),
              _stat('Highest', h.highest, Neon.error),
            ],
          ),
          if (points.length >= 2) ...[
            const SizedBox(height: 14),
            SizedBox(
              height: 120,
              child: CustomPaint(
                painter: _HistoryPainter(points,
                    target: w?.target,
                    line: Neon.violet,
                    grid: Neon.hairline,
                    targetColor: Neon.success,
                    text: Neon.textDim),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            [
              if (!h.isEmpty) h.note.isEmpty ? 'Lowest, usual and highest as reported on the web.' : h.note,
              if (h.isEmpty) 'No price history was found on the web for this one. Set an alert to track it.',
              if (points.length >= 2) 'The line is what this phone saw on its own checks.',
            ].join(' '),
            style: TextStyle(color: Neon.textDim, fontSize: 11.5, height: 1.35),
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, double? v, Color c) => Expanded(
        child: Column(
          children: [
            Text(label.toUpperCase(), style: NeonType.eyebrow.copyWith(color: Neon.textDim, fontSize: 10.5)),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(v == null ? '—' : rupees(v),
                  style: NeonType.manrope(16, FontWeight.w800).copyWith(color: v == null ? Neon.textDim : c)),
            ),
          ],
        ),
      );

  Widget _deals(PriceResult r) => Container(
        decoration: Neon.glassBox(Neon.rCard),
        child: Column(
          children: [
            for (final (i, d) in r.deals.indexed) ...[
              if (i > 0) Divider(height: 1, indent: 64, color: Neon.hairline),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                child: Row(
                  children: [
                    IconTile(d.code.isEmpty ? Icons.local_offer_rounded : Icons.confirmation_number_rounded, Neon.pink),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (d.store.isNotEmpty)
                            Text(d.store.toUpperCase(), style: NeonType.eyebrow.copyWith(color: Neon.textDim)),
                          Text(d.text, style: TextStyle(color: Neon.textHi, fontSize: 13.5, height: 1.35)),
                        ],
                      ),
                    ),
                    if (d.code.isNotEmpty)
                      TextButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: d.code));
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Copied ${d.code}')));
                        },
                        icon: const Icon(Icons.copy_rounded, size: 15),
                        label: Text(d.code),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      );

  /// THE PRICE ALERT — BuyHatke's big bell.
  Widget _alertCard(PriceResult r) {
    final w = svc.watchFor(r.category, r.query);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: Neon.glassBox(Neon.rCard),
      child: Row(
        children: [
          IconTile(w == null ? Icons.notifications_none_rounded : Icons.notifications_active_rounded, Neon.violet,
              size: 40),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(w == null ? 'Price drop alert' : 'Alert at ${rupees(w.target)}',
                    style: NeonType.manrope(15.5, FontWeight.w800).copyWith(color: Neon.textHi)),
                const SizedBox(height: 2),
                Text(
                  w == null
                      ? 'Get a notification when it drops to your price.'
                      : 'Checked each day you open Price compare.',
                  style: TextStyle(color: Neon.textLo, fontSize: 12.5, height: 1.35),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (w != null)
            IconButton(
              tooltip: 'Remove alert',
              onPressed: () => svc.unwatch(w.id),
              icon: Icon(Icons.delete_outline_rounded, color: Neon.textLo),
            ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Neon.accentFill, foregroundColor: Neon.onAccent),
            onPressed: () => _setAlert(r, w),
            child: Text(w == null ? 'Set' : 'Edit'),
          ),
        ],
      ),
    );
  }

  Future<void> _setAlert(PriceResult r, PriceWatch? w) async {
    final now = r.lowest!.price;
    final start = w?.target ?? (now * 0.9).roundToDouble();
    final c = TextEditingController(text: start.round().toString());
    final target = await showAppSheet<double>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.viewInsetsOf(ctx).bottom),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Tell me when it drops to',
                  style: NeonType.manrope(18, FontWeight.w800).copyWith(color: Neon.textHi)),
              const SizedBox(height: 4),
              Text('Now ${rupees(now)} on ${r.lowest!.store}', style: TextStyle(color: Neon.textLo, fontSize: 13)),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                children: [
                  for (final pct in [5, 10, 15, 20])
                    ActionChip(
                      label: Text('$pct% less'),
                      onPressed: () => c.text = (now * (100 - pct) / 100).round().toString(),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: c,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: NeonType.manrope(20, FontWeight.w800).copyWith(color: Neon.textHi),
                decoration: InputDecoration(
                  prefixText: '₹ ',
                  filled: true,
                  fillColor: Neon.surfaceHigh,
                  border:
                      OutlineInputBorder(borderRadius: BorderRadius.circular(Neon.rMd), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
              ApplePrimaryButton(
                label: 'Set alert',
                icon: Icons.notifications_active_rounded,
                onPressed: () {
                  final v = double.tryParse(c.text);
                  if (v != null && v > 0) Navigator.pop(ctx, v);
                },
              ),
            ],
          ),
        ),
      ),
    );
    c.dispose();
    if (target == null) return;
    svc.watch(r, target);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Alert set — ${rupees(target)} or less')));
    }
  }

  Widget _sourcesBox() => Container(
        padding: const EdgeInsets.all(14),
        decoration: Neon.glassBox(Neon.rCard, lift: false),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final s in _sources.take(6))
              InkWell(
                onTap: () => openPriceLink(s.uri),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Icon(Icons.public_rounded, size: 16, color: Neon.textLo),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text((s.title ?? '').isEmpty ? (Uri.tryParse(s.uri)?.host ?? s.uri) : s.title!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Neon.textHi, fontSize: 13)),
                      ),
                    ],
                  ),
                ),
              ),
            if (_suggestions.isNotEmpty) ...[
              const SizedBox(height: 8),
              SearchSuggestionChips(suggestions: _suggestions),
            ],
          ],
        ),
      );
}

String _when(DateTime? at) {
  if (at == null) return 'earlier';
  final d = DateTime.now().difference(at);
  if (d.inMinutes < 2) return 'just now';
  if (d.inHours < 1) return '${d.inMinutes} min ago';
  if (d.inDays < 1) return '${d.inHours} h ago';
  return '${d.inDays} days ago';
}

/// The prices this phone saw, as a line with the alert's target dashed.
class _HistoryPainter extends CustomPainter {
  _HistoryPainter(this.points,
      {this.target, required this.line, required this.grid, required this.targetColor, required this.text});
  final List<PricePoint> points;
  final double? target;
  final Color line, grid, targetColor, text;

  @override
  void paint(Canvas canvas, Size size) {
    final values = [for (final p in points) p.price, if (target != null) target!];
    var lo = values.reduce(math.min), hi = values.reduce(math.max);
    if (hi - lo < 1) {
      hi += 1;
      lo -= 1;
    }
    final pad = (hi - lo) * 0.12;
    lo -= pad;
    hi += pad;
    const bottom = 16.0;
    final h = size.height - bottom;
    double y(double v) => h - (v - lo) / (hi - lo) * h;
    final t0 = points.first.at.millisecondsSinceEpoch.toDouble();
    final t1 = points.last.at.millisecondsSinceEpoch.toDouble();
    double x(DateTime t) => t1 == t0 ? 0 : (t.millisecondsSinceEpoch - t0) / (t1 - t0) * size.width;

    final g = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var i = 0; i <= 2; i++) {
      final gy = h * i / 2;
      canvas.drawLine(Offset(0, gy), Offset(size.width, gy), g);
    }
    if (target != null) {
      final ty = y(target!);
      final tp = Paint()
        ..color = targetColor.withValues(alpha: 0.8)
        ..strokeWidth = 1.4;
      for (var dx = 0.0; dx < size.width; dx += 8) {
        canvas.drawLine(Offset(dx, ty), Offset(math.min(dx + 4, size.width), ty), tp);
      }
    }
    final path = Path();
    for (final (i, p) in points.indexed) {
      final o = Offset(x(p.at), y(p.price));
      i == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
    }
    final fill = Path.from(path)
      ..lineTo(x(points.last.at), h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(
        fill,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [line.withValues(alpha: 0.28), line.withValues(alpha: 0)],
          ).createShader(Offset.zero & Size(size.width, h)));
    canvas.drawPath(
        path,
        Paint()
          ..color = line
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round);
    final last = points.last;
    canvas.drawCircle(Offset(x(last.at), y(last.price)), 4, Paint()..color = line);

    void label(String s, Offset at, {bool right = false}) {
      final tp = TextPainter(
        text: TextSpan(text: s, style: TextStyle(color: text, fontSize: 10.5)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(right ? at.dx - tp.width : at.dx, at.dy));
    }

    String d(DateTime t) => '${t.day}/${t.month}';
    label(d(points.first.at), Offset(0, size.height - 13));
    label(d(last.at), Offset(size.width, size.height - 13), right: true);
  }

  @override
  bool shouldRepaint(_HistoryPainter old) => old.points != points || old.target != target || old.line != line;
}
