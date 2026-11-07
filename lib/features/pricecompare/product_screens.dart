import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../ai/search_suggestions.dart';
import '../../ai/types.dart';
import '../../design/motion.dart';
import '../../design/neon_tokens.dart';
import '../assistant/widgets/action_cards.dart' show SearchSuggestionChips;
import 'price_models.dart';
import 'price_service.dart';
import 'price_widgets.dart';
import 'shop_browser.dart';

/// ─────────────────────────────────────────────────────────────────────────
///  PRODUCT COMPARE, AS THE SHOPPING APPS LAY IT OUT (2026-11-07, Manish,
///  with screenshots: a light results grid, then a product page with its
///  photos, rating, the best price and how it sits against the usual
///  price, a deal score, the price history, "Never miss a price drop",
///  More store prices, Deals in this category, and Set Alert / Buy Now
///  fixed at the bottom).
///
///  In the app's own colours (dark or light, as the app is); photos sit on white. Everything shown comes
///  from the web answer; the deal score is worked out here from the real
///  numbers (where today's price sits between the lowest and highest
///  reported, else its discount) and says so.
/// ─────────────────────────────────────────────────────────────────────────

// The app's own colours (owner, 2026-11-07: "should be in app theme
// colour"), so the pages follow the theme, dark or light.
Color get _bg => Neon.bg;
Color get _card => Color.alphaBlend(Neon.glassFill.colors.first, Neon.surface);
Color get _ink => Neon.textHi;
Color get _inkLo => Neon.textLo;
Color get _inkDim => Neon.textDim;
Color get _line => Neon.hairline;
Color get _accent => Neon.violet;
Color get _green => Neon.success;
Color get _greenBg => Neon.success.withValues(alpha: Neon.isDark ? 0.18 : 0.12);
Color get _red => Neon.error;

PriceStore? _storeNamed(String name) =>
    PriceStores.named(name, [...PriceStores.shopping, ...PriceStores.grocery, ...PriceStores.hotels]);

/// The store's own page for [name]: [url] when it is really the store's,
/// else the store's search for it; '' for an unknown store with no link.
String _storeLink(String store, String url, String name) {
  final s = _storeNamed(store);
  if (s == null) return url.startsWith('https://') ? url : '';
  if (url.isNotEmpty && s.owns(url)) return url;
  return s.urlFor(name);
}

class _Logo extends StatelessWidget {
  const _Logo(this.store, {this.size = 24});
  final String store;
  final double size;

  @override
  Widget build(BuildContext context) {
    final s = _storeNamed(store);
    final logo = brandLogoFor(store: s, host: s == null ? '${store.toLowerCase().replaceAll(' ', '')}.com' : '');
    final r = BorderRadius.circular(size * 0.26);
    if (logo == null) {
      final c = s?.color ?? Neon.textDim;
      return Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: c, borderRadius: r),
        child: Text(store.isEmpty ? '?' : store.characters.first.toUpperCase(),
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: size * 0.5, height: 1)),
      );
    }
    return ClipRRect(
      borderRadius: r,
      child: Image.asset(logo, width: size, height: size, fit: BoxFit.cover),
    );
  }
}

class _Photo extends StatelessWidget {
  const _Photo(this.url, {this.icon = Icons.shopping_bag_outlined});
  final String url;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final ph = Center(child: Icon(icon, color: _inkDim, size: 40));
    if (!url.startsWith('https://')) return ph;
    return Image.network(url,
        fit: BoxFit.contain, errorBuilder: (_, __, ___) => ph, loadingBuilder: (_, child, p) => p == null ? child : ph);
  }
}

Widget _ratingChip(double rating, double? reviews) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: _greenBg, borderRadius: BorderRadius.circular(8)),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star_rounded, size: 16, color: _green),
            const SizedBox(width: 3),
            Text('${rating.toStringAsFixed(1)}${reviews == null ? '' : ' (${_count(reviews)})'}',
                style: TextStyle(color: _green, fontWeight: FontWeight.w700, fontSize: 13)),
          ],
        ),
      ),
    );

String _count(double n) => n >= 100000
    ? '${(n / 100000).toStringAsFixed(1)}L'
    : (n >= 1000 ? '${(n / 1000).toStringAsFixed(n >= 10000 ? 1 : 2)}K' : '${n.round()}');

/// The app's theme as it is (the store-like layout, the app's colours).
ThemeData _light(BuildContext context) => Theme.of(context);

// ═════════════════════════════════════════════════════════════════════════
//  THE RESULTS GRID
// ═════════════════════════════════════════════════════════════════════════

enum _Sort { popular, low, high, rating }

class ProductSearchScreen extends StatefulWidget {
  const ProductSearchScreen({super.key, required this.query});
  final String query;

  @override
  State<ProductSearchScreen> createState() => _ProductSearchScreenState();
}

class _ProductSearchScreenState extends State<ProductSearchScreen> {
  late final TextEditingController _q = TextEditingController(text: widget.query);
  late String _shown = widget.query;
  List<ProductHit> _hits = const [];
  bool _busy = false;
  String _error = '';
  _Sort _sort = _Sort.popular;
  final Set<String> _storesOff = {};
  int _run = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _search();
    });
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _q.text.trim();
    if (q.isEmpty) return;
    FocusScope.of(context).unfocus();
    final run = ++_run;
    setState(() {
      _busy = true;
      _error = '';
      _shown = q;
      _storesOff.clear();
    });
    try {
      final h = await PriceService.instance.searchProducts(q);
      if (mounted && run == _run) setState(() => _hits = h);
    } catch (e) {
      if (mounted && run == _run) {
        setState(() {
          _hits = const [];
          _error = e is PriceCompareException ? e.message : 'Something went wrong. Try again.';
        });
      }
    } finally {
      if (mounted && run == _run) setState(() => _busy = false);
    }
  }

  List<ProductHit> get _list {
    final l = _hits.where((h) => !_storesOff.contains(h.store)).toList();
    switch (_sort) {
      case _Sort.popular:
        break;
      case _Sort.low:
        l.sort((a, b) => a.price.compareTo(b.price));
      case _Sort.high:
        l.sort((a, b) => b.price.compareTo(a.price));
      case _Sort.rating:
        l.sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
    }
    return l;
  }

  static String _sortLabel(_Sort s) => switch (s) {
        _Sort.popular => 'Popularity',
        _Sort.low => 'Price: low to high',
        _Sort.high => 'Price: high to low',
        _Sort.rating => 'Rating',
      };

  @override
  Widget build(BuildContext context) {
    final list = _list;
    return Theme(
      data: _light(context),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: (Neon.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
            .copyWith(statusBarColor: Colors.transparent),
        child: Scaffold(
          backgroundColor: _bg,
          body: SafeArea(
            child: Column(
              children: [
                _searchBar(),
                Align(alignment: Alignment.centerLeft, child: _filters()),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _search,
                    child: CustomScrollView(
                      slivers: [
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                          sliver: SliverToBoxAdapter(
                            child: Text(
                              _busy ? 'Searching the stores for “$_shown”…' : 'Showing results for “$_shown”',
                              style: TextStyle(color: _ink, fontSize: 19, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                        if (_error.isNotEmpty)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                children: [
                                  Icon(Icons.search_off_rounded, size: 48, color: _inkDim),
                                  const SizedBox(height: 10),
                                  Text(_error, textAlign: TextAlign.center, style: TextStyle(color: _inkLo)),
                                  const SizedBox(height: 12),
                                  OutlinedButton(onPressed: _search, child: const Text('Try again')),
                                ],
                              ),
                            ),
                          )
                        else
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                            sliver: SliverGrid(
                              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 240,
                                mainAxisSpacing: 14,
                                crossAxisSpacing: 12,
                                mainAxisExtent: 140 + MediaQuery.textScalerOf(context).scale(118),
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (_, i) =>
                                    _busy ? const _SkeletonCard() : _HitCard(hit: list[i], onTap: () => _open(list[i])),
                                childCount: _busy ? 6 : list.length,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _open(ProductHit h) {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProductDetailScreen(query: h.name, hit: h)));
  }

  Widget _searchBar() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _line, width: 1.5),
          ),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Back',
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(Icons.arrow_back_ios_new_rounded, color: _accent, size: 20),
              ),
              Expanded(
                child: TextField(
                  controller: _q,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _search(),
                  style: TextStyle(color: _ink, fontSize: 16.5),
                  decoration: InputDecoration(
                    filled: false,
                    isDense: true,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    border: InputBorder.none,
                    hintText: 'Search a product',
                    hintStyle: TextStyle(color: _inkDim),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Clear',
                onPressed: () => _q.clear(),
                icon: Icon(Icons.close_rounded, color: _inkDim),
              ),
              Container(width: 1, height: 26, color: _line),
              IconButton(
                tooltip: 'Search',
                onPressed: _search,
                icon: Icon(Icons.search_rounded, color: _accent),
              ),
            ],
          ),
        ),
      );

  Widget _filters() {
    final stores = {for (final h in _hits) h.store}.toList();
    Widget box(Widget child, VoidCallback onTap) => InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _line, width: 1.5),
            ),
            child: child,
          ),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Wrap(
        alignment: WrapAlignment.start,
        spacing: 10,
        runSpacing: 8,
        children: [
          box(
            Row(mainAxisSize: MainAxisSize.min, children: [
              Text(_storesOff.isEmpty ? 'Filter' : 'Filter (${_storesOff.length})',
                  style: TextStyle(color: _inkLo, fontSize: 15)),
              const SizedBox(width: 8),
              Icon(Icons.tune_rounded, size: 18, color: _inkLo),
            ]),
            stores.isEmpty
                ? () {}
                : () => showModalBottomSheet<void>(
                      context: context,
                      backgroundColor: _bg,
                      showDragHandle: true,
                      builder: (ctx) => StatefulBuilder(
                        builder: (ctx, set) => SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Stores',
                                    style: TextStyle(color: _ink, fontSize: 18, fontWeight: FontWeight.w800)),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    for (final s in stores)
                                      FilterChip(
                                        avatar: _Logo(s, size: 20),
                                        label: Text(s),
                                        selected: !_storesOff.contains(s),
                                        onSelected: (v) {
                                          set(() => v ? _storesOff.remove(s) : _storesOff.add(s));
                                          setState(() {});
                                        },
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
          ),
          PopupMenuButton<_Sort>(
            initialValue: _sort,
            onSelected: (s) => setState(() => _sort = s),
            color: _bg,
            itemBuilder: (_) => [
              for (final s in _Sort.values)
                PopupMenuItem(value: s, child: Text(_sortLabel(s), style: TextStyle(color: _ink))),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _line, width: 1.5),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(_sortLabel(_sort), style: TextStyle(color: _inkLo, fontSize: 15)),
                const SizedBox(width: 6),
                Icon(Icons.keyboard_arrow_down_rounded, color: _inkLo),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _HitCard extends StatelessWidget {
  const _HitCard({required this.hit, required this.onTap, this.width});
  final ProductHit hit;
  final VoidCallback onTap;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final h = hit;
    return Semantics(
      button: true,
      label: '${h.name}, ${rupees(h.price)} on ${h.store}',
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          width: width,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(22)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.all(10),
                  child: Stack(
                    children: [
                      Positioned.fill(child: _Photo(h.image)),
                      Positioned(left: 0, bottom: 0, child: _Logo(h.store, size: 24)),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 10, 6, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (h.rating != null) ...[_ratingChip(h.rating!, h.reviews), const SizedBox(height: 8)],
                    Text(h.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: _inkLo, fontSize: 13.5, height: 1.3)),
                    const SizedBox(height: 6),
                    Text(rupees(h.price), style: TextStyle(color: _ink, fontSize: 18, fontWeight: FontWeight.w800)),
                    if (h.offPercent != null)
                      Text.rich(
                        TextSpan(children: [
                          TextSpan(
                              text: rupees(h.mrp!),
                              style: TextStyle(decoration: TextDecoration.lineThrough, color: _inkDim)),
                          TextSpan(text: '  ${h.offPercent}% Off', style: TextStyle(color: _green)),
                        ]),
                        maxLines: 1,
                        style: const TextStyle(fontSize: 12.5),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    Widget bar(double w, double h) =>
        Container(width: w, height: h, decoration: BoxDecoration(color: _line, borderRadius: BorderRadius.circular(6)));
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(22)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            ),
          ),
          const SizedBox(height: 12),
          bar(70, 18),
          const SizedBox(height: 10),
          bar(double.infinity, 12),
          const SizedBox(height: 6),
          bar(100, 12),
          const SizedBox(height: 10),
          bar(80, 18),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════
//  THE PRODUCT PAGE
// ═════════════════════════════════════════════════════════════════════════

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({super.key, required this.query, this.hit, this.earlier});

  /// What to compare (the product's name, or a link).
  final String query;

  /// The grid card it was opened from: shown at once while comparing.
  final ProductHit? hit;

  /// A comparison from before (Recently compared).
  final PriceResult? earlier;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final svc = PriceService.instance;
  PriceResult? _r;
  List<SourceLink> _sources = const [];
  List<SearchSuggestion> _suggestions = const [];
  bool _busy = false;
  String _error = '';
  int _photo = 0;
  int _elapsed = 0;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    svc.addListener(_changed);
    _r = widget.earlier;
    if (_r == null) _run();
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
      final a = await svc.compare(PriceCategory.shopping, widget.query);
      if (!mounted) return;
      HapticFeedback.lightImpact();
      setState(() {
        _r = a.result;
        _sources = a.sources;
        _suggestions = a.suggestions;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e is PriceCompareException ? e.message : 'Something went wrong.');
    } finally {
      _tick?.cancel();
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── what is known ────────────────────────────────────────────────────

  String get _name => _r?.product ?? widget.hit?.name ?? widget.query;

  List<String> get _photos {
    final r = _r;
    final seen = <String>{};
    return [
      if (widget.hit != null) widget.hit!.image,
      if (r != null) ...[
        r.facts.str('image'),
        ...r.facts.strs('images', max: 4),
        for (final o in r.offers) o.info.str('image'),
      ],
    ].where((u) => u.startsWith('https://') && seen.add(u)).take(8).toList();
  }

  /// 0–100: where today's best price sits between the lowest and highest
  /// reported (lower is better), else from its discount. Null with neither.
  static int? dealScore(PriceResult r) {
    final now = r.lowest?.price;
    if (now == null) return null;
    final lo = r.history.lowest, hi = r.history.highest;
    if (lo != null && hi != null && hi > lo) {
      return (100 - ((now - lo) / (hi - lo)).clamp(0.0, 1.0) * 100).round().clamp(1, 99);
    }
    final off = r.lowest!.offPercent;
    if (off != null) return (off * 2.5).round().clamp(5, 95);
    return null;
  }

  String _link(PriceOffer o) => _storeLink(o.store, o.url, _name);

  // ── the page ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final r = _r;
    return Theme(
      data: _light(context),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: (Neon.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
            .copyWith(statusBarColor: Colors.transparent),
        child: Scaffold(
          backgroundColor: _bg,
          body: Stack(
            children: [
              RefreshIndicator(
                onRefresh: _run,
                child: ListView(
                  padding: EdgeInsets.only(bottom: 110 + MediaQuery.paddingOf(context).bottom),
                  children: [
                    _gallery(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _titleRow(),
                          if (_busy) _loading(),
                          if (_error.isNotEmpty) _errorBox(),
                          if (r != null && !_busy) ..._body(r),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              _topButtons(),
              Positioned(left: 0, right: 0, bottom: 0, child: _bottomBar(r)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topButtons() => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
          child: Row(
            children: [
              _circle(Icons.arrow_back_ios_new_rounded, 'Back', () => Navigator.of(context).pop()),
              const Spacer(),
              _circle(Icons.search_rounded, 'Search', () {
                Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => ProductSearchScreen(query: widget.hit?.name ?? widget.query)));
              }),
            ],
          ),
        ),
      );

  Widget _circle(IconData icon, String tip, VoidCallback onTap) => Material(
        color: Neon.surfaceHigh,
        shape: const CircleBorder(),
        child: IconButton(tooltip: tip, onPressed: onTap, icon: Icon(icon, color: _accent, size: 22)),
      );

  Widget _gallery() {
    final photos = _photos;
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      height: 330 + top,
      padding: EdgeInsets.only(top: top + 56),
      color: _bg,
      child: photos.isEmpty
          ? const _Photo('', icon: Icons.image_outlined)
          : Column(
              children: [
                Expanded(
                  child: PageView.builder(
                    itemCount: photos.length,
                    onPageChanged: (i) => setState(() => _photo = i),
                    itemBuilder: (_, i) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: _Photo(photos[i]),
                    ),
                  ),
                ),
                if (photos.length > 1)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
                    child: Row(
                      children: [
                        const Spacer(),
                        for (var i = 0; i < photos.length; i++)
                          AnimatedContainer(
                            duration: Motion.short,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: i == _photo ? 18 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: i == _photo ? _inkLo : _line,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(10)),
                          child: Text('${_photo + 1}/${photos.length}', style: TextStyle(color: _inkLo, fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _titleRow() {
    final r = _r;
    final rating = r?.facts.num('rating') ?? widget.hit?.rating;
    final reviews = r?.facts.num('reviews') ?? widget.hit?.reviews;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child:
                  Text(_name, style: TextStyle(color: _ink, fontSize: 18.5, fontWeight: FontWeight.w500, height: 1.3)),
            ),
            IconButton(
              tooltip: 'Share',
              onPressed: () {
                final low = r?.lowest;
                Share.share(
                    low == null ? _name : '$_name — ${rupees(low.price)} on ${low.store} (compared in MyAssistant)');
              },
              icon: Icon(Icons.ios_share_rounded, color: _ink),
            ),
          ],
        ),
        if (rating != null) ...[const SizedBox(height: 4), _ratingChip(rating, reviews)],
      ],
    );
  }

  Widget _loading() {
    final h = widget.hit;
    const steps = ['Checking Amazon, Flipkart, Croma…', 'Comparing every store\'s price…', 'Reading price history…'];
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (h != null)
            Row(
              children: [
                _Logo(h.store, size: 30),
                const SizedBox(width: 10),
                Text(rupees(h.price), style: TextStyle(color: _ink, fontSize: 26, fontWeight: FontWeight.w800)),
                const SizedBox(width: 8),
                Text('on ${h.store}', style: TextStyle(color: _inkLo)),
              ],
            ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: Neon.violet.withValues(alpha: Neon.isDark ? 0.14 : 0.08),
                borderRadius: BorderRadius.circular(16)),
            child: Row(
              children: [
                SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.6, color: _accent)),
                const SizedBox(width: 14),
                Expanded(
                  child: Text('${steps[(_elapsed ~/ 6) % steps.length]}  ${_elapsed}s',
                      style: TextStyle(color: _ink, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorBox() => Padding(
        padding: const EdgeInsets.only(top: 18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Neon.error.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
          child: Row(
            children: [
              Icon(Icons.error_outline_rounded, color: _red),
              const SizedBox(width: 10),
              Expanded(child: Text(_error, style: TextStyle(color: _ink))),
              TextButton(onPressed: _run, child: const Text('Retry')),
            ],
          ),
        ),
      );

  List<Widget> _body(PriceResult r) => [
        const SizedBox(height: 18),
        _priceRow(r),
        const SizedBox(height: 22),
        _historyChart(r),
        const SizedBox(height: 22),
        _alertBanner(r),
        if (r.advice.isNotEmpty) ...[const SizedBox(height: 22), _verdict(r)],
        const SizedBox(height: 28),
        _h('More Store Prices', trailing: '${r.offers.length} stores'),
        const SizedBox(height: 12),
        for (final (i, o) in r.offers.indexed) ...[_storeCard(r, o, cheapest: i == 0), const SizedBox(height: 12)],
        if (r.deals.isNotEmpty) ...[
          const SizedBox(height: 16),
          _h('Bank offers & coupons'),
          const SizedBox(height: 10),
          for (final d in r.deals) _deal(d),
        ],
        if (r.facts.pairs('specs').isNotEmpty || r.facts.strs('highlights').isNotEmpty) ...[
          const SizedBox(height: 26),
          _h('Highlights & specs'),
          const SizedBox(height: 10),
          _specs(r),
        ],
        ..._similar(r),
        if (_sources.isNotEmpty) ...[
          const SizedBox(height: 26),
          _h('Where these prices came from'),
          const SizedBox(height: 6),
          for (final s in _sources.take(6))
            InkWell(
              onTap: () => openPriceLink(s.uri),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Text((s.title?.isNotEmpty ?? false) ? s.title! : s.uri,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _accent, fontSize: 13)),
              ),
            ),
        ],
        if (_suggestions.isNotEmpty) ...[const SizedBox(height: 8), SearchSuggestionChips(suggestions: _suggestions)],
        const SizedBox(height: 14),
        Text('Prices as found on the web just now; the store shows the final price before you pay.',
            style: TextStyle(color: _inkDim, fontSize: 11.5)),
      ];

  Widget _h(String t, {String? trailing}) => Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(t, style: TextStyle(color: _ink, fontSize: 21, fontWeight: FontWeight.w700)),
            ),
          ),
          if (trailing != null) Text(trailing, style: TextStyle(color: _inkDim, fontSize: 13)),
        ],
      );

  Widget _priceRow(PriceResult r) {
    final low = r.lowest!;
    final avg = r.history.average;
    final score = dealScore(r);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _Logo(low.store, size: 34),
                  const SizedBox(width: 12),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(rupees(low.price),
                          style: TextStyle(color: _ink, fontSize: 32, fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text.rich(
                TextSpan(children: [
                  const TextSpan(text: 'Lowest on '),
                  TextSpan(text: low.store, style: TextStyle(fontWeight: FontWeight.w700, color: _ink)),
                  if (low.offPercent != null)
                    TextSpan(text: '  ·  ${low.offPercent}% off', style: TextStyle(color: _green)),
                ]),
                style: TextStyle(color: _inkLo, fontSize: 13.5),
              ),
              if (avg != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(low.price <= avg ? Icons.arrow_circle_down_rounded : Icons.arrow_circle_up_rounded,
                        size: 20, color: low.price <= avg ? _green : _red),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text.rich(
                        TextSpan(children: [
                          TextSpan(
                              text: rupees((avg - low.price).abs()),
                              style: TextStyle(fontWeight: FontWeight.w800, color: _ink)),
                          TextSpan(text: low.price <= avg ? ' lower than average price' : ' higher than average price'),
                        ]),
                        style: TextStyle(color: _inkLo, fontSize: 13.5),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        if (score != null) ...[
          const SizedBox(width: 12),
          Tooltip(
            message: r.history.lowest != null
                ? 'Deal score: where today\'s price sits between the lowest and highest reported'
                : 'Deal score: from the discount on MRP',
            child: _ScoreGauge(score: score),
          ),
        ],
      ],
    );
  }

  Widget _historyChart(PriceResult r) {
    final w = svc.watchFor(r.category, r.query);
    final points = w?.points ?? const <PricePoint>[];
    final h = r.history;
    final now = r.lowest!.price;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _h('Price history'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: _line)),
          child: points.length >= 2
              ? SizedBox(height: 170, child: CustomPaint(painter: _LinePainter(points)))
              : h.isEmpty
                  ? Row(children: [
                      Icon(Icons.show_chart_rounded, color: _inkDim),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                            'No price history was found for this one yet. Set an alert and the chart fills '
                            'in with every check.',
                            style: TextStyle(color: _inkLo, fontSize: 13)),
                      ),
                    ])
                  : _RangeChart(low: h.lowest, avg: h.average, high: h.highest, now: now),
        ),
        if (h.note.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(h.note, style: TextStyle(color: _inkDim, fontSize: 11.5)),
          ),
      ],
    );
  }

  Widget _alertBanner(PriceResult r) {
    final w = svc.watchFor(r.category, r.query);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
      decoration: BoxDecoration(
          color: Neon.violet.withValues(alpha: Neon.isDark ? 0.16 : 0.10), borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Icon(w == null ? Icons.notifications_rounded : Icons.notifications_active_rounded, color: _ink, size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(w == null ? 'Never miss a price drop' : 'Alert at ${rupees(w.target)}',
                    style: TextStyle(color: _ink, fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                    w == null
                        ? 'Get a notification when it drops to your price'
                        : 'Checked each day you open Price compare',
                    style: TextStyle(color: _inkLo, fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: () => _setAlert(r),
            style: FilledButton.styleFrom(backgroundColor: _accent, shape: const StadiumBorder()),
            child: Text(w == null ? 'Turn on' : 'Edit'),
          ),
        ],
      ),
    );
  }

  Widget _verdict(PriceResult r) {
    final (c, word) = switch (r.verdict) {
      PriceVerdict.buy => (_green, 'Good time to buy'),
      PriceVerdict.wait => (Neon.warning, 'Better to wait'),
      PriceVerdict.okay => (_accent, 'Fair price'),
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.auto_awesome_rounded, color: c, size: 18),
            const SizedBox(width: 6),
            Expanded(child: Text(word, style: TextStyle(color: c, fontWeight: FontWeight.w800, fontSize: 15))),
            Text('AI', style: TextStyle(color: _inkDim, fontWeight: FontWeight.w800, fontSize: 12)),
          ]),
          const SizedBox(height: 6),
          Text(r.advice, style: TextStyle(color: _ink, fontSize: 14, height: 1.4)),
        ],
      ),
    );
  }

  Widget _storeCard(PriceResult r, PriceOffer o, {required bool cheapest}) {
    final link = _link(o);
    final photo = o.info.str('image').isNotEmpty ? o.info.str('image') : (_photos.isNotEmpty ? _photos.first : '');
    final save = o.mrp != null ? o.mrp! - o.price : null;
    final delivery = o.info.str('delivery');
    return Semantics(
      button: link.isNotEmpty,
      label: '${o.store}, ${rupees(o.price)}',
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: link.isEmpty ? null : () => openInShopBrowser(context, link, PriceCategory.shopping),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(18),
            border: cheapest ? Border.all(color: _green.withValues(alpha: 0.6), width: 1.4) : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 92,
                height: 92,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                child: _Photo(photo),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _Logo(o.store, size: 22),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(o.store,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: _ink, fontSize: 16, fontWeight: FontWeight.w600)),
                        ),
                        if (cheapest)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(color: _greenBg, borderRadius: BorderRadius.circular(6)),
                            child: Text('LOWEST',
                                style: TextStyle(color: _green, fontSize: 10.5, fontWeight: FontWeight.w800)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(o.title.isNotEmpty ? o.title : _name,
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _inkLo, fontSize: 13)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(rupees(o.price), style: TextStyle(color: _ink, fontSize: 17, fontWeight: FontWeight.w800)),
                        if (o.offPercent != null)
                          Text('${o.offPercent}% Off', style: TextStyle(color: _ink, fontSize: 13)),
                        if (save != null && save > 0)
                          Text.rich(
                              TextSpan(children: [
                                TextSpan(text: 'Save ', style: TextStyle(color: _inkLo)),
                                TextSpan(
                                    text: rupees(save), style: TextStyle(color: _green, fontWeight: FontWeight.w700)),
                              ]),
                              style: const TextStyle(fontSize: 13)),
                      ],
                    ),
                    if (delivery.isNotEmpty || !o.inStock) ...[
                      const SizedBox(height: 4),
                      Text(!o.inStock ? 'Out of stock' : 'Delivery: $delivery',
                          style: TextStyle(color: o.inStock ? _inkLo : _red, fontSize: 12)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _deal(PriceDeal d) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _line),
        ),
        child: Row(
          children: [
            const Icon(Icons.local_offer_rounded, color: Color(0xFFDB2777), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text('${d.store.isEmpty ? '' : '${d.store}: '}${d.text}',
                  style: TextStyle(color: _ink, fontSize: 13.5)),
            ),
            if (d.code.isNotEmpty)
              TextButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: d.code));
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Copied ${d.code}')));
                },
                child: Text(d.code),
              ),
          ],
        ),
      );

  Widget _specs(PriceResult r) {
    final specs = r.facts.pairs('specs');
    final hl = r.facts.strs('highlights', max: 4);
    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: _line)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final h in hl)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.check_circle_rounded, color: _green, size: 17),
                const SizedBox(width: 8),
                Expanded(child: Text(h, style: TextStyle(color: _ink, fontSize: 13.5))),
              ]),
            ),
          if (hl.isNotEmpty) const SizedBox(height: 10),
          for (final (i, (k, v)) in specs.indexed)
            Container(
              color: i.isEven ? _card : null,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 110, child: Text(k, style: TextStyle(color: _inkLo, fontSize: 13))),
                  Expanded(
                    child: Text(v, style: TextStyle(color: _ink, fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _similar(PriceResult r) {
    final raw = r.facts['similar'];
    final hits = [
      if (raw is List)
        for (final x in raw)
          if (ProductHit.fromJson(x) case final h?) h,
    ].take(6).toList();
    if (hits.isEmpty) return const [];
    return [
      const SizedBox(height: 28),
      _h('Deals in this category'),
      const SizedBox(height: 12),
      SizedBox(
        height: 140 + MediaQuery.textScalerOf(context).scale(118),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          itemCount: hits.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (_, i) => _HitCard(
            hit: hits[i],
            width: 180,
            onTap: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => ProductDetailScreen(query: hits[i].name, hit: hits[i]))),
          ),
        ),
      ),
    ];
  }

  Widget _bottomBar(PriceResult? r) {
    final low = r?.lowest;
    final link = low == null ? '' : _link(low);
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.paddingOf(context).bottom),
      decoration: BoxDecoration(
        color: _bg,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, -4))
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 54,
              child: FilledButton(
                onPressed: r == null ? null : () => _setAlert(r),
                style: FilledButton.styleFrom(
                  backgroundColor: Neon.violet.withValues(alpha: Neon.isDark ? 0.18 : 0.10),
                  foregroundColor: _accent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Set Alert', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 54,
              child: FilledButton(
                onPressed: link.isEmpty ? null : () => openInShopBrowser(context, link, PriceCategory.shopping),
                style: FilledButton.styleFrom(
                  backgroundColor: _accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(low == null ? 'Buy Now' : 'Buy Now · ${rupees(low.price)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _setAlert(PriceResult r) async {
    final now = r.lowest!.price;
    final w = svc.watchFor(r.category, r.query);
    final c = TextEditingController(text: (w?.target ?? (now * 0.9)).round().toString());
    final target = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _bg,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(ctx).bottom),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Tell me when it drops to',
                  style: TextStyle(color: _ink, fontSize: 19, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('Now ${rupees(now)} on ${r.lowest!.store}', style: TextStyle(color: _inkLo)),
              const SizedBox(height: 14),
              Wrap(spacing: 8, children: [
                for (final pct in [5, 10, 15, 20])
                  ActionChip(
                    label: Text('$pct% less'),
                    onPressed: () => c.text = (now * (100 - pct) / 100).round().toString(),
                  ),
              ]),
              const SizedBox(height: 12),
              TextField(
                controller: c,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: TextStyle(color: _ink, fontSize: 22, fontWeight: FontWeight.w800),
                decoration: InputDecoration(
                  prefixText: '₹ ',
                  filled: true,
                  fillColor: _card,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: () {
                    final v = double.tryParse(c.text);
                    if (v != null && v > 0) Navigator.pop(ctx, v);
                  },
                  style: FilledButton.styleFrom(backgroundColor: _accent),
                  child: const Text('Set alert'),
                ),
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
}

/// The deal score, 0–100, on a half-ring from red to green.
class _ScoreGauge extends StatelessWidget {
  const _ScoreGauge({required this.score});
  final int score;

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Deal score $score out of 100',
        child: SizedBox(
          width: 86,
          height: 70,
          child: CustomPaint(
            painter: _GaugePainter(score / 100),
            child: Padding(
              padding: const EdgeInsets.only(top: 22),
              child: Column(
                children: [
                  Text('$score', style: TextStyle(color: _ink, fontSize: 24, fontWeight: FontWeight.w800, height: 1)),
                  Text('SCORE',
                      style: TextStyle(color: _ink, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
                ],
              ),
            ),
          ),
        ),
      );
}

class _GaugePainter extends CustomPainter {
  _GaugePainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCircle(center: Offset(size.width / 2, size.height * 0.62), radius: size.width / 2 - 6);
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round
      ..color = Neon.hairline;
    canvas.drawArc(rect, math.pi * 0.9, math.pi * 1.2, false, track);
    final fill = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round
      ..shader = const SweepGradient(
        startAngle: math.pi * 0.9,
        endAngle: math.pi * 2.1,
        colors: [Color(0xFFEF4444), Color(0xFFF59E0B), Color(0xFFFACC15), Color(0xFF22C55E)],
      ).createShader(rect);
    canvas.drawArc(rect, math.pi * 0.9, math.pi * 1.2 * t.clamp(0.02, 1.0), false, fill);
  }

  @override
  bool shouldRepaint(_GaugePainter old) => old.t != t;
}

/// Lowest, usual and highest reported, with today's price marked.
class _RangeChart extends StatelessWidget {
  const _RangeChart({required this.low, required this.avg, required this.high, required this.now});
  final double? low, avg, high;
  final double now;

  @override
  Widget build(BuildContext context) {
    final vals = [low, avg, high, now].whereType<double>().toList();
    final lo = vals.reduce(math.min), hi = vals.reduce(math.max);
    double y(double v) => hi <= lo ? 0.5 : (v - lo) / (hi - lo);
    Widget bar(String label, double? v, Color c, {bool today = false}) => Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(v == null ? '—' : rupees(v),
                    maxLines: 1,
                    style: TextStyle(color: today ? _ink : _inkLo, fontWeight: FontWeight.w700, fontSize: 12.5)),
              ),
              const SizedBox(height: 4),
              AnimatedContainer(
                duration: Motion.short,
                height: v == null ? 4 : 24 + 70 * y(v),
                margin: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: c.withValues(alpha: today ? 1 : 0.35),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                ),
              ),
              const SizedBox(height: 6),
              Text(label,
                  style: TextStyle(
                      color: today ? _ink : _inkLo,
                      fontSize: 12,
                      fontWeight: today ? FontWeight.w800 : FontWeight.w500)),
            ],
          ),
        );
    return SizedBox(
      height: 110 + MediaQuery.textScalerOf(context).scale(44),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          bar('Lowest', low, _green),
          bar('Usual', avg, _accent),
          bar('Highest', high, _red),
          bar('Today', now, Neon.cyan, today: true),
        ],
      ),
    );
  }
}

/// What this phone saw on its own checks, as a filled line.
class _LinePainter extends CustomPainter {
  _LinePainter(this.points);
  final List<PricePoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    final ps = [...points]..sort((a, b) => a.at.compareTo(b.at));
    final lo = ps.map((p) => p.price).reduce(math.min), hi = ps.map((p) => p.price).reduce(math.max);
    final span = hi - lo <= 0 ? 1 : hi - lo;
    Offset at(int i) => Offset(
          ps.length == 1 ? 0 : size.width * i / (ps.length - 1),
          size.height - 18 - (size.height - 36) * ((ps[i].price - lo) / span),
        );
    final line = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < ps.length; i++) {
      line.lineTo(at(i).dx, at(i).dy);
    }
    final area = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
        area,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [const Color(0xFF22C55E).withValues(alpha: 0.35), const Color(0xFF22C55E).withValues(alpha: 0.03)],
          ).createShader(Offset.zero & size));
    canvas.drawPath(
        line,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = const Color(0xFF22C55E));
    final tp = TextPainter(
      text: TextSpan(
          text: 'Lowest: ${rupees(lo)}',
          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
      textDirection: TextDirection.ltr,
    )..layout();
    final box = Rect.fromLTWH(0, size.height - tp.height - 8, tp.width + 12, tp.height + 6);
    canvas.drawRRect(RRect.fromRectAndRadius(box, const Radius.circular(5)), Paint()..color = _green);
    tp.paint(canvas, Offset(6, box.top + 3));
  }

  @override
  bool shouldRepaint(_LinePainter old) => old.points != points;
}

/// The deal score, for tests and other pages.
abstract final class ProductDetailScreenScore {
  static int? of(PriceResult r) => _ProductDetailScreenState.dealScore(r);
}
