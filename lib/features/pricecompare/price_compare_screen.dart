import 'dart:math' as math;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design/apple_kit.dart';
import '../../design/neon_scaffold.dart';
import '../../design/motion.dart';
import '../../design/neon_tokens.dart';
import 'flight_search_screen.dart';
import 'price_models.dart';
import 'price_result_screen.dart';
import 'product_screens.dart';
import 'price_service.dart';
import 'price_widgets.dart';
import 'shop_browser.dart';

/// ─────────────────────────────────────────────────────────────────────────
///  PRICE COMPARE, THE HUB (2026-11-04, owner: "layout of the feature like
///  BuyHatke"): the search on top — pick what you are comparing, type it
///  or paste a link, an optional budget — then your price alerts and
///  what you compared lately. A comparison opens PriceResultScreen.
/// ─────────────────────────────────────────────────────────────────────────
class PriceCompareScreen extends StatefulWidget {
  const PriceCompareScreen({super.key, this.category = PriceCategory.shopping, this.focus = false, this.paste = false});
  final PriceCategory category;

  /// Open with the keyboard up (Home's search box).
  final bool focus;

  /// Open by comparing the link on the clipboard (Home's paste button).
  final bool paste;

  @override
  State<PriceCompareScreen> createState() => _PriceCompareScreenState();
}

class _PriceCompareScreenState extends State<PriceCompareScreen> {
  late PriceCategory _cat = widget.category;
  final _query = TextEditingController();
  final _budget = TextEditingController();
  final _focus = FocusNode();
  final svc = PriceService.instance;

  @override
  void initState() {
    super.initState();
    svc.addListener(_changed);
    _focus.addListener(_changed);
    unawaited(svc.load().then((_) => svc.checkWatches()));
    if (widget.paste) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _paste());
    } else if (widget.focus) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
    }
  }

  @override
  void dispose() {
    svc.removeListener(_changed);
    _query.dispose();
    _budget.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  /// PASTE A LINK (BuyHatke's way in), read only when tapped: reading the
  /// clipboard unasked shows Android's "pasted from clipboard" notice.
  Future<void> _paste() async {
    try {
      final d = await Clipboard.getData(Clipboard.kTextPlain);
      final t = d?.text?.trim() ?? '';
      if (t.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Copy a product link from Amazon or Flipkart first')));
        }
        return;
      }
      _query.text = t;
      _go();
    } catch (_) {}
  }

  void _flights() {
    FocusScope.of(context).unfocus();
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FlightSearchScreen()));
  }

  void _go([String? query, PriceCategory? cat]) {
    if (query == null && _cat == PriceCategory.flights) return _flights();
    final q = (query ?? _query.text).trim();
    if (q.isEmpty) {
      _focus.requestFocus();
      return;
    }
    FocusScope.of(context).unfocus();
    HapticFeedback.mediumImpact();
    final budget = double.tryParse(_budget.text.replaceAll(RegExp(r'[^\d.]'), ''));
    final c = cat ?? _cat;
    // Products: a results grid to pick from (a pasted link goes straight
    // to its product page); the rest compare at once.
    final link = q.startsWith('http://') || q.startsWith('https://');
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => c == PriceCategory.shopping && budget == null
          ? (link ? ProductDetailScreen(query: q) : ProductSearchScreen(query: q))
          : PriceResultScreen(category: c, query: q, budget: budget),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return NeonScaffold(
      appBar: appleAppBar(context, 'Price compare'),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 4, 16, 32 + MediaQuery.paddingOf(context).bottom),
          children: [
            _searchCard(),
            const SizedBox(height: 22),
            _sectionTitle('Shop in the app'),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 2, 4, 10),
              child: Text('Open a store here. When you open a product, tap Compare to see its price everywhere.',
                  style: TextStyle(color: Neon.textLo, fontSize: 13, height: 1.35)),
            ),
            _shopStores(),
            const SizedBox(height: 22),
            _sectionTitle('What are you comparing?'),
            const SizedBox(height: 10),
            _categories(),
            if (svc.watches.isNotEmpty) ...[
              const SizedBox(height: 24),
              _sectionTitle('Your price alerts'),
              const SizedBox(height: 10),
              _alerts(),
            ],
            if (svc.recent.isNotEmpty) ...[
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(child: _sectionTitle('Recently compared')),
                  TextButton(onPressed: svc.clearRecent, child: const Text('Clear')),
                ],
              ),
              const SizedBox(height: 4),
              _recent(),
            ],
            const SizedBox(height: 22),
            Text(
              'Prices are found on the web with Google Search and can change at any moment — the store '
              'shows the final price before you pay. Alerts are checked when you open Price compare.',
              style: TextStyle(color: Neon.textDim, fontSize: NeonType.caption, height: 1.4),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => showPhotoCredits(context),
                child: const Text('Photo credits'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// THE STORES THAT RUN IN THE APP: each opens its site in
  /// [ShopBrowserScreen], where a product page brings up Compare. Round
  /// app icons with their names, like a phone's dock.
  Widget _shopStores() {
    final stores = [
      for (final s in PriceStores.shopping) (s, PriceCategory.shopping),
      for (final s in PriceStores.grocery) (s, PriceCategory.grocery),
    ];
    return SizedBox(
      height: 28 + MediaQuery.textScalerOf(context).scale(58),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: stores.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (_, i) {
          final (s, cat) = stores[i];
          final logo = brandLogoFor(store: s);
          return Semantics(
            button: true,
            label: 'Open ${s.name} in the app',
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => openInShopBrowser(
                  context,
                  s == PriceStores.instamart ? 'https://www.swiggy.com/instamart' : 'https://www.${s.domains.first}/',
                  cat),
              child: SizedBox(
                width: 64,
                child: Column(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25), blurRadius: 10, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: logo == null
                            ? StoreMark(s, size: 56)
                            : Image.asset(logo, width: 56, height: 56, fit: BoxFit.cover),
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(s.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Neon.textHi, fontSize: 11.5, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _sectionTitle(String t) => Semantics(
        header: true,
        child: Padding(
          padding: const EdgeInsets.only(left: 4),
          child:
              Text(t, style: NeonType.manrope(17, FontWeight.w800).copyWith(color: Neon.textHi, letterSpacing: -0.3)),
        ),
      );

  /// THE SEARCH (2026-11-07, Manish: "improve this page"): a short title,
  /// one row of category tiles, one search pill (paste and go inside it),
  /// tap-to-try examples, two small extras, and the stores it checks.
  Widget _searchCard() {
    final stores = _cat.stores;
    final examples = _cat.example
        .replaceFirst(RegExp(r'^e\.g\.\s*'), '')
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .take(3)
        .toList();
    final tint = _cat.tint(Neon.violet);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Title
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(children: [
                  const TextSpan(text: 'Compare before\n'),
                  TextSpan(text: 'you pay', style: TextStyle(color: Neon.violet)),
                ]),
                style:
                    NeonType.manrope(30, FontWeight.w800).copyWith(color: Neon.textHi, letterSpacing: -1, height: 1.1),
              ),
              const SizedBox(height: 8),
              Text('Every store\'s price, the history, and the AI\'s buy-or-wait.',
                  style: TextStyle(color: Neon.textLo, fontSize: 14, height: 1.35)),
            ],
          ),
        ),
        const SizedBox(height: 18),
        // Categories: one row of tiles
        Row(
          children: [
            for (final c in PriceCategory.values) ...[
              if (c != PriceCategory.values.first) const SizedBox(width: 8),
              Expanded(child: _catTile(c)),
            ],
          ],
        ),
        const SizedBox(height: 16),
        // The search pill
        AnimatedContainer(
          duration: Motion.short,
          padding: const EdgeInsets.fromLTRB(16, 4, 6, 4),
          decoration: BoxDecoration(
            color: Neon.surfaceHigh.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(Neon.rPill),
            border: Border.all(color: _focus.hasFocus ? tint : Neon.hairline, width: _focus.hasFocus ? 1.6 : 1),
            boxShadow: _focus.hasFocus ? Neon.halo(tint, strength: 0.25) : Neon.glassShadow,
          ),
          child: Row(
            children: [
              Icon(Icons.search_rounded, color: Neon.textLo, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _query,
                  focusNode: _focus,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _go(),
                  onTap: () => setState(() {}),
                  style: TextStyle(color: Neon.textHi, fontSize: 16),
                  decoration: InputDecoration(
                    hintText: _cat.ask,
                    hintStyle: TextStyle(color: Neon.textDim, fontSize: 15),
                    filled: false,
                    isDense: true,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
              ),
              if (_cat == PriceCategory.shopping || _cat == PriceCategory.grocery)
                IconButton(
                  tooltip: 'Paste a product link',
                  onPressed: _paste,
                  icon: Icon(Icons.content_paste_rounded, color: Neon.textLo, size: 21),
                ),
              Material(
                color: Neon.accentFill,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _go,
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 22),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Examples to try
        if (examples.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('Try', style: TextStyle(color: Neon.textDim, fontSize: 13)),
              for (final e in examples)
                ActionChip(
                  label: Text(e),
                  labelStyle: TextStyle(color: Neon.textHi, fontSize: 12.5),
                  backgroundColor: Neon.surfaceHigh.withValues(alpha: 0.5),
                  side: BorderSide(color: Neon.hairline),
                  shape: const StadiumBorder(),
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    _query.text = e;
                    _go();
                  },
                ),
            ],
          ),
        ],
        // Budget, and the stores it checks
        const SizedBox(height: 14),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 10,
          runSpacing: 8,
          children: [
            if (_cat != PriceCategory.flights)
              ActionChip(
                avatar: Icon(Icons.account_balance_wallet_rounded, size: 16, color: Neon.cyan),
                label: Text(_budget.text.isEmpty ? 'Add budget' : 'Budget ₹${_budget.text}'),
                labelStyle: TextStyle(color: Neon.textHi, fontSize: 12.5),
                backgroundColor: Neon.cyan.withValues(alpha: 0.10),
                side: BorderSide(color: Neon.cyan.withValues(alpha: 0.4)),
                shape: const StadiumBorder(),
                visualDensity: VisualDensity.compact,
                onPressed: _askBudget,
              ),
            if (stores.isNotEmpty)
              Row(mainAxisSize: MainAxisSize.min, children: [
                Text('Checks', style: TextStyle(color: Neon.textDim, fontSize: 12.5)),
                const SizedBox(width: 6),
                SizedBox(
                  height: 26,
                  width: 26 + 16.0 * (math.min(stores.length, 5) - 1),
                  child: Stack(
                    children: [
                      for (final (i, s) in stores.take(5).indexed)
                        Positioned(
                          left: 16.0 * i,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Neon.bg, width: 2),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: brandLogoFor(store: s) == null
                                  ? StoreMark(s, size: 22)
                                  : Image.asset(brandLogoFor(store: s)!, width: 22, height: 22, fit: BoxFit.cover),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ]),
          ],
        ),
      ],
    );
  }

  Widget _catTile(PriceCategory c) {
    final on = c == _cat;
    final tint = c.tint(Neon.violet);
    return Semantics(
      button: true,
      selected: on,
      label: c.label,
      child: InkWell(
        borderRadius: BorderRadius.circular(Neon.rLg),
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _cat = c);
          if (c == PriceCategory.flights) _flights();
        },
        child: AnimatedContainer(
          duration: Motion.short,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: on ? tint.withValues(alpha: Neon.isDark ? 0.22 : 0.14) : Neon.surfaceHigh.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(Neon.rLg),
            border: Border.all(color: on ? tint : Neon.hairline, width: on ? 1.5 : 1),
          ),
          child: Column(
            children: [
              Icon(c.icon, color: on ? tint : Neon.textLo, size: 24),
              const SizedBox(height: 5),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(c.label,
                    maxLines: 1,
                    style: NeonType.manrope(11.5, FontWeight.w800).copyWith(color: on ? Neon.textHi : Neon.textLo)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _askBudget() async {
    final c = TextEditingController(text: _budget.text);
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Your budget'),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(prefixText: '₹ ', hintText: 'The AI weighs it in its pick'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, ''), child: const Text('Clear')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Done')),
        ],
      ),
    );
    c.dispose();
    if (v != null && mounted) setState(() => _budget.text = v);
  }

  Widget _categories() => PriceCategoryShowcase(
        selected: _cat,
        onTap: (c) {
          setState(() => _cat = c);
          c == PriceCategory.flights ? _flights() : _focus.requestFocus();
        },
      );

  Widget _alerts() => Container(
        decoration: Neon.glassBox(Neon.rCard),
        child: Column(
          children: [
            for (final w in svc.watches)
              AppleRow(
                leading: IconTile(w.reached ? Icons.trending_down_rounded : Icons.notifications_active_rounded,
                    w.reached ? Neon.success : Neon.violet),
                title: w.product,
                subtitle: [
                  'Alert at ${rupees(w.target)}',
                  if (w.last != null) 'now ${rupees(w.last!)}${w.store.isEmpty ? '' : ' on ${w.store}'}',
                ].join(' · '),
                onTap: () => _go(w.query, w.category),
              ),
          ],
        ),
      );

  Widget _recent() => Container(
        decoration: Neon.glassBox(Neon.rCard),
        child: Column(
          children: [
            for (final r in svc.recent)
              AppleRow(
                leading: IconTile(r.category.icon, r.category.tint(Neon.violet)),
                title: r.product,
                subtitle: r.lowest == null
                    ? r.category.label
                    : 'Lowest ${rupees(r.lowest!.price)} on ${r.lowest!.store} · ${_ago(r.at)}',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => r.category == PriceCategory.shopping
                      ? ProductDetailScreen(query: r.query, earlier: r)
                      : PriceResultScreen(category: r.category, query: r.query, earlier: r),
                )),
              ),
          ],
        ),
      );
}

String _ago(DateTime? at) {
  if (at == null) return 'earlier';
  final d = DateTime.now().difference(at);
  if (d.inMinutes < 2) return 'just now';
  if (d.inHours < 1) return '${d.inMinutes} min ago';
  if (d.inDays < 1) return '${d.inHours} h ago';
  return d.inDays == 1 ? 'yesterday' : '${d.inDays} days ago';
}
