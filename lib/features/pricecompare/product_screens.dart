import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../ai/types.dart';
import '../../design/motion.dart';
import '../../design/neon_tokens.dart';
import 'price_models.dart';
import 'price_service.dart';
import 'price_widgets.dart';
import 'shop_browser.dart';

/// ─────────────────────────────────────────────────────────────────────────
///  PRODUCT COMPARE, CLEAN (2026-11-24, Manish, with a shopping app as the
///  reference: "clean UI and good animation").
///
///  Results: a two-column grid of product cards — the photo large on white
///  with the store's logo on it, the name, rating, price and discount —
///  with sort and a chip per store under the search. Cards ease in one
///  after another, dip under the finger, and the photo flies into the
///  product page.
///
///  Product page: the photo, the name, then the best price (counting up to
///  its value), every store ranked with a bar that fills to show how far
///  above the lowest it is, the AI verdict, price history, an alert,
///  offers, specifications and similar products, each easing in. The best
///  price and Buy stay fixed at the bottom.
///
///  In the app's own colours, dark or light; product photos sit on white.
///  Everything shown comes from the web answer; the deal score is worked
///  out here from the real numbers and says so.
/// ─────────────────────────────────────────────────────────────────────────

Color get _bg => Neon.bg;
Color get _card => Neon.surface;
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

/// A store's logo, or its initial on its colour.
class StoreLogo extends StatelessWidget {
  const StoreLogo(this.store, {super.key, this.size = 24});
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

/// A product photo that always shows: [url], else a real photo of [name]
/// found on the server (Allen's ProductPhoto, price_widgets.dart), fading in.
class _Photo extends StatelessWidget {
  const _Photo(this.url, {required this.name, this.pick = 0, this.icon = Icons.shopping_bag_outlined});
  final String url;
  final String name;
  final int pick;
  final IconData icon;

  @override
  Widget build(BuildContext context) =>
      ProductPhoto(url, name: name, pick: pick, icon: icon, iconColor: Colors.black26);
}

Widget _ratingChip(double rating, double? reviews) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: _greenBg, borderRadius: BorderRadius.circular(7)),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star_rounded, size: 15, color: _green),
            const SizedBox(width: 3),
            Text('${rating.toStringAsFixed(1)}${reviews == null ? '' : ' (${_count(reviews)})'}',
                style: TextStyle(color: _green, fontWeight: FontWeight.w700, fontSize: 12.5)),
          ],
        ),
      ),
    );

String _count(double n) => n >= 100000
    ? '${(n / 100000).toStringAsFixed(1)}L'
    : (n >= 1000 ? '${(n / 1000).toStringAsFixed(n >= 10000 ? 1 : 2)}K' : '${n.round()}');

/// A small capital-letter badge ("LOWEST").
Widget _badge(String text, Color c, {bool solid = false}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
          color: solid ? c : c.withValues(alpha: Neon.isDark ? 0.2 : 0.12), borderRadius: BorderRadius.circular(6)),
      child: Text(text,
          style: TextStyle(
              color: solid ? Colors.white : c, fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.4)),
    );

/// A flat, theme-coloured section card.
BoxDecoration _cardBox({Color? edge}) => BoxDecoration(
      color: _card,
      borderRadius: BorderRadius.circular(Neon.rLg),
      border: Border.all(color: edge ?? _line, width: edge == null ? 1 : 1.4),
    );

Widget _sectionHead(String t, {String? trailing, IconData? icon}) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          if (icon != null) ...[Icon(icon, color: _accent, size: 20), const SizedBox(width: 8)],
          Expanded(
            child: Semantics(
              header: true,
              child: Text(t, style: NeonType.manrope(19, FontWeight.w800).copyWith(color: _ink, letterSpacing: -0.3)),
            ),
          ),
          if (trailing != null) Text(trailing, style: TextStyle(color: _inkDim, fontSize: 13)),
        ],
      ),
    );

SystemUiOverlayStyle get _overlay =>
    (Neon.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark).copyWith(statusBarColor: Colors.transparent);

/// Counts up to [value] (from 85% of it) the first time it is shown.
class _CountUp extends StatelessWidget {
  const _CountUp(this.value, {required this.style});
  final double value;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    if (Motion.reduced(context)) return Text(rupees(value), style: style);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: value * 0.85, end: value),
      duration: const Duration(milliseconds: 750),
      curve: Curves.easeOutCubic,
      builder: (_, v, __) => Text(rupees(v == value ? value : v.roundToDouble()), style: style),
    );
  }
}

/// A light sweep across the skeletons while results load.
class _Shimmer extends StatefulWidget {
  const _Shimmer({required this.child});
  final Widget child;

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduced(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        child: widget.child,
        builder: (_, child) => ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (r) {
            final x = -1.0 + 3.0 * _c.value;
            return LinearGradient(
              begin: Alignment(x - 1, -0.3),
              end: Alignment(x, 0.3),
              colors: [Colors.transparent, Neon.textHi.withValues(alpha: 0.08), Colors.transparent],
            ).createShader(r);
          },
          child: child,
        ),
      );
}

// ═════════════════════════════════════════════════════════════════════════
//  THE PRODUCT CARD (results, recently viewed, similar products)
// ═════════════════════════════════════════════════════════════════════════

/// The height a [ProductCard] needs below its square photo.
double productCardText(BuildContext context, {bool rating = true, bool note = false}) =>
    MediaQuery.textScalerOf(context).scale(62 + (rating ? 26 : 0) + (note ? 16 : 0)) + 14;

/// A product: its photo large on white with the store's logo on it, then
/// the name, rating, price and discount. Dips under the finger; the photo
/// flies into the product page when [heroTag] matches there.
class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.name,
    required this.store,
    required this.image,
    required this.onTap,
    this.price,
    this.mrp,
    this.rating,
    this.reviews,
    this.badge,
    this.note,
    this.heroTag,
  });

  final String name;
  final String store;
  final String image;
  final double? price;
  final double? mrp;
  final double? rating;
  final double? reviews;

  /// A word on the photo ("LOWEST PRICE").
  final String? badge;

  /// A line under the price ("Alert at ₹60,000").
  final String? note;
  final Object? heroTag;
  final VoidCallback onTap;

  int? get _off {
    final p = price, m = mrp;
    if (p == null || m == null || m <= p || p <= 0) return null;
    final o = ((m - p) / m * 100).round();
    return o >= 1 ? o : null;
  }

  @override
  Widget build(BuildContext context) {
    final photo = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(Neon.rMd)),
      child: _Photo(image, name: name),
    );
    final off = _off;
    return Tappable(
      onTap: onTap,
      semanticLabel: [name, if (price != null) '${rupees(price!)} on $store', if (badge != null) badge!].join(', '),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: _cardBox(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Stack(
                children: [
                  Positioned.fill(child: heroTag == null ? photo : Hero(tag: heroTag!, child: photo)),
                  Positioned(left: 8, bottom: 8, child: StoreLogo(store, size: 26)),
                  if (badge != null) Positioned(left: 8, top: 8, child: _badge(badge!, _green, solid: true)),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 9, 4, 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: _ink, fontSize: 13, height: 1.3)),
                    const SizedBox(height: 6),
                    if (rating != null) ...[_ratingChip(rating!, reviews), const SizedBox(height: 5)],
                    if (price != null)
                      Row(children: [
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(rupees(price!), style: NeonType.manrope(16.5, FontWeight.w800).copyWith(color: _ink)),
                          ),
                        ),
                        if (off != null) ...[
                          const SizedBox(width: 6),
                          Text('$off% off', style: TextStyle(color: _green, fontSize: 12, fontWeight: FontWeight.w700)),
                        ],
                      ]),
                    if (note != null)
                      Text(note!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _inkLo, fontSize: 11.5)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// [children] as a two-column grid of [ProductCard]s, easing in one
/// after another.
Widget productGrid(BuildContext context, List<Widget> children,
        {bool stagger = true, bool rating = true, bool note = false}) =>
    LayoutBuilder(
      builder: (context, c) {
        final w = (c.maxWidth - 12) / 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            mainAxisExtent: w + productCardText(context, rating: rating, note: note),
          ),
          itemCount: children.length,
          itemBuilder: (_, i) => stagger ? Reveal(delayMs: 40 * i, child: children[i]) : children[i],
        );
      },
    );

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    Widget bar(double w, double h) =>
        Container(width: w, height: h, decoration: BoxDecoration(color: _line, borderRadius: BorderRadius.circular(6)));
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: _cardBox(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Container(decoration: BoxDecoration(color: _line, borderRadius: BorderRadius.circular(Neon.rMd))),
          ),
          const SizedBox(height: 10),
          bar(double.infinity, 12),
          const SizedBox(height: 6),
          bar(90, 12),
          const Spacer(),
          bar(80, 18),
        ],
      ),
    );
  }
}

/// The search pill used on Price Compare's pages: back, the field, and
/// whatever [trailing] brings (clear, camera, mic).
class PriceSearchPill extends StatelessWidget {
  const PriceSearchPill({
    super.key,
    required this.controller,
    required this.onSubmit,
    this.focus,
    this.hint = 'Search for a product',
    this.trailing = const [],
    this.onBack,
  });

  final TextEditingController controller;
  final FocusNode? focus;
  final VoidCallback onSubmit;
  final String hint;
  final List<Widget> trailing;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final on = focus?.hasFocus ?? false;
    return AnimatedContainer(
      duration: Motion.short,
      height: 54,
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: on ? _accent : _line, width: 1.5),
        boxShadow: on ? Neon.halo(_accent, strength: 0.2) : null,
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            onPressed: onBack ?? () => Navigator.of(context).maybePop(),
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: _accent, size: 19),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focus,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => onSubmit(),
              style: TextStyle(color: _ink, fontSize: 15.5),
              decoration: InputDecoration(
                filled: false,
                isDense: true,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                border: InputBorder.none,
                hintText: hint,
                hintMaxLines: 1,
                hintStyle: TextStyle(color: _inkDim, fontSize: 15),
              ),
            ),
          ),
          if (trailing.isNotEmpty) ...[
            Container(width: 1, height: 26, color: _line),
            const SizedBox(width: 4),
            ...trailing,
            const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}

/// A rounded chip: a recent search, a suggestion, a store, the sort.
class PriceChip extends StatelessWidget {
  const PriceChip({super.key, required this.label, required this.onTap, this.icon, this.avatar, this.on = false});
  final String label;
  final IconData? icon;
  final Widget? avatar;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Tappable(
          onTap: onTap,
          semanticLabel: label,
          child: AnimatedContainer(
            duration: Motion.short,
            curve: Motion.easeMove,
            padding: EdgeInsets.fromLTRB(avatar != null ? 6 : 12, 8, 14, 8),
            decoration: BoxDecoration(
              color: on ? _accent.withValues(alpha: Neon.isDark ? 0.24 : 0.12) : Neon.surfaceHigh.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(Neon.rPill),
              border: Border.all(color: on ? _accent : Colors.transparent, width: 1.3),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (avatar != null) ...[avatar!, const SizedBox(width: 7)],
              if (icon != null) ...[Icon(icon, size: 17, color: on ? _accent : _inkLo), const SizedBox(width: 6)],
              Text(label, style: TextStyle(color: _ink, fontSize: 13.5, fontWeight: FontWeight.w500)),
            ]),
          ),
        ),
      );
}

// ═════════════════════════════════════════════════════════════════════════
//  THE RESULTS
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
  final _focus = FocusNode();
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
    _focus.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _search();
    });
  }

  @override
  void dispose() {
    _q.dispose();
    _focus.dispose();
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
          _error = e is PriceCompareException ? e.message : 'An unexpected error has occurred. Please try again.';
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
        _Sort.low => 'Lowest Price',
        _Sort.high => 'Highest Price',
        _Sort.rating => 'Top Rated',
      };

  @override
  Widget build(BuildContext context) {
    final list = _list;
    final prices = list.map((h) => h.price).where((p) => p > 0);
    final lowest = prices.isEmpty ? null : prices.reduce(math.min);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _overlay,
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                child: PriceSearchPill(
                  controller: _q,
                  focus: _focus,
                  onSubmit: _search,
                  trailing: [
                    IconButton(
                      tooltip: 'Clear',
                      onPressed: () {
                        _q.clear();
                        _focus.requestFocus();
                      },
                      icon: Icon(Icons.close_rounded, color: _inkDim, size: 20),
                    ),
                    IconButton(
                      tooltip: 'Search',
                      onPressed: _search,
                      icon: Icon(Icons.search_rounded, color: _accent),
                    ),
                  ],
                ),
              ),
              _chips(),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _search,
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(16, 4, 16, 28 + MediaQuery.paddingOf(context).bottom),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(2, 6, 2, 14),
                        child: AnimatedSwitcher(
                          duration: Motion.short,
                          child: Text.rich(
                            key: ValueKey('$_busy${list.length}$_shown'),
                            TextSpan(children: [
                              TextSpan(text: _busy ? 'Searching stores for “$_shown”…' : 'Results for “$_shown”'),
                              if (!_busy && _error.isEmpty)
                                TextSpan(
                                    text: '  ·  ${list.length} ${list.length == 1 ? 'product' : 'products'}',
                                    style: TextStyle(color: _inkDim, fontWeight: FontWeight.w500)),
                            ]),
                            style: NeonType.manrope(17, FontWeight.w700).copyWith(color: _ink),
                          ),
                        ),
                      ),
                      if (_error.isNotEmpty)
                        _empty(Icons.search_off_rounded, _error)
                      else if (_busy)
                        _Shimmer(child: productGrid(context, [for (var i = 0; i < 6; i++) const _SkeletonCard()], stagger: false))
                      else if (list.isEmpty)
                        _empty(Icons.filter_alt_off_rounded,
                            _hits.isEmpty ? 'No products were found. Please try another name.' : 'No products match these filters.')
                      else
                        productGrid(context, rating: list.any((h) => h.rating != null), [
                          for (final (i, h) in list.indexed)
                            ProductCard(
                              key: ValueKey('${h.store}|${h.name}|$i'),
                              name: h.name,
                              store: h.store,
                              image: h.image,
                              price: h.price,
                              mrp: h.mrp,
                              rating: h.rating,
                              reviews: h.reviews,
                              badge: list.length > 1 && h.price == lowest ? 'LOWEST PRICE' : null,
                              heroTag: _heroTag(h, i),
                              onTap: () => _open(h, i),
                            ),
                        ]),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Object _heroTag(ProductHit h, int i) => 'pc-photo|$_run|$i|${h.store}|${h.name}';

  Widget _empty(IconData icon, String text) => EnterOnce(
        rise: 12,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
          child: Column(
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(color: _accent.withValues(alpha: 0.12), shape: BoxShape.circle),
                child: Icon(icon, size: 34, color: _accent),
              ),
              const SizedBox(height: 14),
              Text(text, textAlign: TextAlign.center, style: TextStyle(color: _inkLo, fontSize: 14, height: 1.4)),
              const SizedBox(height: 14),
              FilledButton.tonal(onPressed: _search, child: const Text('Try Again')),
            ],
          ),
        ),
      );

  void _open(ProductHit h, int i) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => ProductDetailScreen(query: h.name, hit: h, heroTag: _heroTag(h, i))));
  }

  /// Sort, then a chip per store (tap to hide its products), in one row.
  Widget _chips() {
    final stores = {for (final h in _hits) h.store}.toList();
    return SizedBox(
      height: 54,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 6),
        children: [
          PopupMenuButton<_Sort>(
            initialValue: _sort,
            onSelected: (s) => setState(() => _sort = s),
            color: Neon.surface,
            itemBuilder: (_) => [
              for (final s in _Sort.values) PopupMenuItem(value: s, child: Text(_sortLabel(s), style: TextStyle(color: _ink))),
            ],
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
                decoration: BoxDecoration(
                  color: Neon.surfaceHigh.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(Neon.rPill),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.swap_vert_rounded, size: 17, color: _accent),
                  const SizedBox(width: 5),
                  Text(_sortLabel(_sort), style: TextStyle(color: _ink, fontSize: 13.5, fontWeight: FontWeight.w600)),
                  Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: _inkLo),
                ]),
              ),
            ),
          ),
          if (stores.length > 1)
            for (final s in stores)
              PriceChip(
                avatar: StoreLogo(s, size: 22),
                label: s,
                on: !_storesOff.contains(s),
                onTap: () => setState(() => _storesOff.contains(s) ? _storesOff.remove(s) : _storesOff.add(s)),
              ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════
//  THE PRODUCT PAGE
// ═════════════════════════════════════════════════════════════════════════

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({super.key, required this.query, this.hit, this.earlier, this.heroTag});

  /// What to compare (the product's name, or a link).
  final String query;

  /// The result it was opened from: shown at once while comparing.
  final ProductHit? hit;

  /// A comparison from before (Recently compared).
  final PriceResult? earlier;

  /// The card's photo flies into the first photo here.
  final Object? heroTag;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final svc = PriceService.instance;
  PriceResult? _r;
  List<SourceLink> _sources = const [];
  bool _busy = false;
  String _error = '';
  int _photo = 0;
  int _elapsed = 0;
  bool _allSpecs = false;
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
      });
    } catch (e) {
      if (!mounted) return;
      // Nothing found on the web, but the store page the user came from
      // showed its price (often a brand sold on one store only): show that
      // store's price rather than an error (2026-11-08).
      final h = widget.hit;
      if (h != null && h.price > 0) {
        setState(() {
          _r = PriceResult(
            category: PriceCategory.shopping,
            query: widget.query,
            product: h.name,
            offers: [PriceOffer(store: h.store, price: h.price, title: h.name, url: h.url)],
            bestPick: h.store,
            advice: "This product could not be found on other stores at present. The price shown is from ${h.store}.",
            at: DateTime.now(),
            facts: {if (h.image.isNotEmpty) 'image': h.image},
          );
        });
      } else {
        setState(() => _error = e is PriceCompareException ? e.message : 'An unexpected error has occurred.');
      }
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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _overlay,
      child: Scaffold(
        backgroundColor: _bg,
        body: Stack(
          children: [
            RefreshIndicator(
              onRefresh: _run,
              child: ListView(
                padding: EdgeInsets.only(bottom: 120 + MediaQuery.paddingOf(context).bottom),
                children: [
                  _gallery(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _titleRow(),
                        AnimatedSize(
                          duration: Motion.enter,
                          curve: Motion.easeMove,
                          alignment: Alignment.topCenter,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (_busy) _loading(),
                              if (_error.isNotEmpty) _errorBox(),
                              if (r != null && !_busy)
                                for (final (i, w) in _body(r).indexed) i < 8 ? Reveal(delayMs: 50 * i, child: w) : w,
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _topButtons(),
            // No prices and a failed look-up: nothing to alert on or buy,
            // so no bar of two dead buttons (the error box says Retry).
            if (r != null || _error.isEmpty)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: EnterOnce(rise: 40, fade: false, duration: Motion.enter, child: _bottomBar(r)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _topButtons() => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
          child: Row(
            children: [
              _circle(Icons.arrow_back_ios_new_rounded, 'Back', () => Navigator.of(context).pop()),
              const Spacer(),
              _circle(Icons.ios_share_rounded, 'Share', () {
                final low = _r?.lowest;
                Share.share(low == null ? _name : '$_name: ${rupees(low.price)} on ${low.store} (compared in MyAssistant)');
              }),
              const SizedBox(width: 8),
              _circle(Icons.search_rounded, 'Search', () {
                Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => ProductSearchScreen(query: widget.hit?.name ?? widget.query)));
              }),
            ],
          ),
        ),
      );

  // Dark ink on the white photo panel behind, whatever the theme.
  Widget _circle(IconData icon, String tip, VoidCallback onTap) => Material(
        color: Colors.white,
        shape: const CircleBorder(side: BorderSide(color: Colors.black12)),
        child: IconButton(tooltip: tip, onPressed: onTap, icon: Icon(icon, color: Colors.black87, size: 19)),
      );

  /// The photos on a white panel with rounded lower corners.
  Widget _gallery() {
    final photos = _photos;
    final top = MediaQuery.paddingOf(context).top;
    Widget page(int i) {
      final p = Padding(padding: const EdgeInsets.symmetric(horizontal: 36), child: _Photo(photos[i], name: _name, pick: i));
      return i == 0 && widget.heroTag != null ? Hero(tag: widget.heroTag!, child: p) : p;
    }

    return Container(
      height: 330 + top,
      padding: EdgeInsets.only(top: top + 58, bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: photos.isEmpty
          ? (widget.heroTag != null
              ? Hero(tag: widget.heroTag!, child: _Photo('', name: _name, icon: Icons.shopping_bag_outlined))
              : _Photo('', name: _name, icon: Icons.image_outlined))
          : Column(
              children: [
                Expanded(
                  child: PageView.builder(
                    itemCount: photos.length,
                    onPageChanged: (i) => setState(() => _photo = i),
                    itemBuilder: (_, i) => page(i),
                  ),
                ),
                if (photos.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < photos.length; i++)
                          AnimatedContainer(
                            duration: Motion.short,
                            curve: Motion.easeMove,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: i == _photo ? 20 : 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: i == _photo ? _accent : Colors.black12,
                              borderRadius: BorderRadius.circular(4),
                            ),
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
    final brand = r?.facts.str('brand') ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (brand.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(brand.toUpperCase(),
                style: TextStyle(color: _accent, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
          ),
        AnimatedSwitcher(
          duration: Motion.short,
          child: Text(_name,
              key: ValueKey(_name), style: NeonType.manrope(19, FontWeight.w700).copyWith(color: _ink, height: 1.3)),
        ),
        if (rating != null || (r != null && r.offers.length > 1)) ...[
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
            if (rating != null) _ratingChip(rating, reviews),
            if (r != null && r.offers.length > 1)
              Text('Compared across ${r.offers.length} stores', style: TextStyle(color: _inkLo, fontSize: 12.5)),
          ]),
        ],
      ],
    );
  }

  Widget _loading() {
    final h = widget.hit;
    const steps = ['Checking Amazon, Flipkart and Croma…', 'Comparing prices across all stores…', 'Retrieving price history…'];
    final stores = PriceStores.shopping.take(5).toList();
    final lit = (_elapsed ~/ 2) % (stores.length + 1);
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (h != null)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: _cardBox(),
              child: Row(
                children: [
                  StoreLogo(h.store, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Seen on ${h.store}', style: TextStyle(color: _inkLo, fontSize: 12.5)),
                      Text(rupees(h.price), style: NeonType.manrope(22, FontWeight.w800).copyWith(color: _ink)),
                    ]),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          _Shimmer(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: _cardBox(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: _accent)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: Motion.short,
                          child: Text(steps[(_elapsed ~/ 6) % steps.length],
                              key: ValueKey(_elapsed ~/ 6), style: TextStyle(color: _ink, fontWeight: FontWeight.w600)),
                        ),
                      ),
                      Text('${_elapsed}s', style: TextStyle(color: _inkDim, fontSize: 12.5)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      for (final (i, s) in stores.indexed)
                        Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: AnimatedScale(
                            duration: Motion.enter,
                            curve: Curves.easeOutBack,
                            scale: i < lit ? 1 : 0.85,
                            child: AnimatedOpacity(
                              duration: Motion.enter,
                              opacity: i < lit ? 1 : 0.3,
                              child: StoreLogo(s.name, size: 30),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorBox() => Padding(
        padding: const EdgeInsets.only(top: 18),
        child: EnterOnce(
          rise: 10,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _red.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(Neon.rLg),
              border: Border.all(color: _red.withValues(alpha: 0.35)),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline_rounded, color: _red),
                const SizedBox(width: 10),
                Expanded(child: Text(_error, style: TextStyle(color: _ink))),
                TextButton(onPressed: _run, child: const Text('Retry')),
              ],
            ),
          ),
        ),
      );

  List<Widget> _body(PriceResult r) => [
        Padding(padding: const EdgeInsets.only(top: 18), child: _bestPrice(r)),
        Padding(
          padding: const EdgeInsets.only(top: 26),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _sectionHead('Price at Every Store',
                trailing: '${r.offers.length} ${r.offers.length == 1 ? 'store' : 'stores'}'),
            _comparison(r),
          ]),
        ),
        if (r.advice.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 22), child: _verdict(r)),
        Padding(padding: const EdgeInsets.only(top: 26), child: _historyChart(r)),
        Padding(padding: const EdgeInsets.only(top: 16), child: _alertBanner(r)),
        if (r.deals.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 26),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _sectionHead('Bank Offers & Coupons', icon: Icons.local_offer_rounded),
              for (final d in r.deals) _deal(d),
            ]),
          ),
        if (r.facts.pairs('specs').isNotEmpty || r.facts.strs('highlights').isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 26),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _sectionHead('Highlights & Specifications'),
              _specs(r),
            ]),
          ),
        ..._similar(r),
        if (_sources.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 26),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _sectionHead('Sources of These Prices'),
              for (final s in _sources.take(6))
                InkWell(
                  onTap: () => openPriceLink(s.uri),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(children: [
                      Icon(Icons.link_rounded, color: _accent, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text((s.title?.isNotEmpty ?? false) ? s.title! : s.uri,
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _accent, fontSize: 13)),
                      ),
                    ]),
                  ),
                ),
            ]),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Text('Prices as retrieved from the web; the store displays the final price before payment.',
              style: TextStyle(color: _inkDim, fontSize: 11.5)),
        ),
      ];

  /// THE BEST PRICE: the store, the price (counting up), what it saves
  /// against the dearest store and the usual price, the deal score.
  Widget _bestPrice(PriceResult r) {
    final low = r.lowest!;
    final avg = r.history.average;
    final score = dealScore(r);
    final saving = r.saving;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardBox(edge: _accent.withValues(alpha: 0.5)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('BEST PRICE TODAY',
                        style: TextStyle(color: _accent, fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
                    const SizedBox(height: 6),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: _CountUp(low.price,
                          style: NeonType.manrope(34, FontWeight.w800).copyWith(color: _ink, letterSpacing: -1)),
                    ),
                    const SizedBox(height: 6),
                    Row(children: [
                      StoreLogo(low.store, size: 22),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text.rich(
                          TextSpan(children: [
                            const TextSpan(text: 'Lowest on '),
                            TextSpan(text: low.store, style: TextStyle(fontWeight: FontWeight.w800, color: _ink)),
                          ]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: _inkLo, fontSize: 13.5),
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
              if (score != null) ...[
                const SizedBox(width: 10),
                Tooltip(
                  message: r.history.lowest != null
                      ? 'Deal score: the position of the current price between the lowest and highest reported'
                      : 'Deal score: based on the discount on MRP',
                  child: _ScoreGauge(score: score),
                ),
              ],
            ],
          ),
          if (saving > 0 || avg != null || low.offPercent != null) ...[
            const SizedBox(height: 14),
            Divider(height: 1, color: _line),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (saving > 0) _fact(Icons.savings_rounded, '${rupees(saving)} less than the highest store', _green),
                if (avg != null)
                  _fact(
                    low.price <= avg ? Icons.trending_down_rounded : Icons.trending_up_rounded,
                    '${rupees((avg - low.price).abs())} ${low.price <= avg ? 'below' : 'above'} the average price',
                    low.price <= avg ? _green : _red,
                  ),
                if (low.offPercent != null) _fact(Icons.sell_rounded, '${low.offPercent}% off MRP', _accent),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _fact(IconData icon, String text, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: c.withValues(alpha: Neon.isDark ? 0.12 : 0.08),
          borderRadius: BorderRadius.circular(Neon.rPill),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15, color: c),
          const SizedBox(width: 5),
          Flexible(child: Text(text, style: TextStyle(color: _ink, fontSize: 12.5, fontWeight: FontWeight.w600))),
        ]),
      );

  /// THE COMPARISON: every store, cheapest first, each with a bar that
  /// fills to show how much more it asks than the lowest.
  Widget _comparison(PriceResult r) {
    final lo = r.lowest!.price;
    final hi = r.highest!.price;
    return Container(
      decoration: _cardBox(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final (i, o) in r.offers.indexed) ...[
            if (i > 0) Divider(height: 1, thickness: 1, color: _line),
            _storeRow(o, rank: i + 1, lo: lo, hi: hi),
          ],
        ],
      ),
    );
  }

  Widget _storeRow(PriceOffer o, {required int rank, required double lo, required double hi}) {
    final cheapest = rank == 1;
    final link = _link(o);
    final more = o.price - lo;
    final t = hi > lo ? (o.price - lo) / (hi - lo) : 0.0;
    final delivery = o.info.str('delivery');
    final sub = [
      if (!o.inStock) 'Out of stock' else if (delivery.isNotEmpty) 'Delivery: $delivery',
      if (o.offPercent != null) '${o.offPercent}% off',
    ].join('  ·  ');
    final still = Motion.reduced(context);
    return Semantics(
      button: link.isNotEmpty,
      label: '${o.store}, ${rupees(o.price)}${cheapest ? ', lowest' : ''}',
      excludeSemantics: true,
      child: InkWell(
        onTap: link.isEmpty ? null : () => openInShopBrowser(context, link, PriceCategory.shopping),
        child: Container(
          color: cheapest ? _green.withValues(alpha: Neon.isDark ? 0.08 : 0.05) : null,
          padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
          child: Row(
            children: [
              SizedBox(
                width: 20,
                child: Text('$rank',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: cheapest ? _green : _inkDim, fontWeight: FontWeight.w800, fontSize: 13)),
              ),
              const SizedBox(width: 8),
              StoreLogo(o.store, size: 34),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(o.store,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: _ink, fontSize: 15, fontWeight: FontWeight.w700)),
                    if (sub.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(sub,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: o.inStock ? _inkLo : _red, fontSize: 12)),
                    ],
                    const SizedBox(height: 7),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: still ? 0.12 + 0.88 * t : 0, end: 0.12 + 0.88 * t),
                      duration: Duration(milliseconds: still ? 0 : 600 + 90 * rank),
                      curve: Curves.easeOutCubic,
                      builder: (_, v, __) => ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: v,
                          minHeight: 5,
                          backgroundColor: _line,
                          color: cheapest ? _green : Color.lerp(Neon.warning, _red, t),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(rupees(o.price), style: NeonType.manrope(16, FontWeight.w800).copyWith(color: _ink)),
                  const SizedBox(height: 3),
                  if (cheapest)
                    _badge('LOWEST', _green)
                  else
                    Text('+${rupees(more)} more',
                        style: TextStyle(color: _inkLo, fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
              Icon(Icons.chevron_right_rounded, color: link.isEmpty ? Colors.transparent : _inkDim, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _verdict(PriceResult r) {
    final (c, word, icon) = switch (r.verdict) {
      PriceVerdict.buy => (_green, 'Good Time to Buy', Icons.thumb_up_alt_rounded),
      PriceVerdict.wait => (Neon.warning, 'Better to Wait', Icons.schedule_rounded),
      PriceVerdict.okay => (_accent, 'Fair Price', Icons.balance_rounded),
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.withValues(alpha: Neon.isDark ? 0.10 : 0.07),
        borderRadius: BorderRadius.circular(Neon.rLg),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: c.withValues(alpha: 0.18), shape: BoxShape.circle),
            child: Icon(icon, color: c, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(child: Text(word, style: TextStyle(color: c, fontWeight: FontWeight.w800, fontSize: 15.5))),
                  Icon(Icons.auto_awesome_rounded, color: _inkDim, size: 14),
                  const SizedBox(width: 3),
                  Text('AI advice', style: TextStyle(color: _inkDim, fontWeight: FontWeight.w700, fontSize: 11.5)),
                ]),
                const SizedBox(height: 4),
                Text(r.advice, style: TextStyle(color: _ink, fontSize: 13.5, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
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
        _sectionHead('Price History', icon: Icons.show_chart_rounded),
        Container(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
          decoration: _cardBox(),
          child: points.length >= 2
              ? SizedBox(height: 170, child: CustomPaint(painter: _LinePainter(points)))
              : h.isEmpty
                  ? Row(children: [
                      Icon(Icons.insights_rounded, color: _inkDim),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                            'No price history is available for this product yet. Once an alert is set, the chart is updated '
                            'with every check.',
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
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: _cardBox(),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: _accent.withValues(alpha: 0.14), shape: BoxShape.circle),
            child: Icon(w == null ? Icons.notifications_rounded : Icons.notifications_active_rounded,
                color: _accent, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(w == null ? 'Price Drop Alert' : 'Alert at ${rupees(w.target)}',
                    style: TextStyle(color: _ink, fontSize: 15.5, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                    w == null
                        ? 'Receive a notification when the price falls to your target'
                        : 'Checked on each day Price Compare is opened',
                    style: TextStyle(color: _inkLo, fontSize: 12.5)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: () => _setAlert(r),
            style: FilledButton.styleFrom(
                backgroundColor: Neon.accentFill, foregroundColor: Neon.onAccent, shape: const StadiumBorder()),
            child: Text(w == null ? 'Enable' : 'Edit'),
          ),
        ],
      ),
    );
  }

  Widget _deal(PriceDeal d) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
        decoration: _cardBox(),
        child: Row(
          children: [
            if (d.store.isNotEmpty) StoreLogo(d.store, size: 26) else Icon(Icons.local_offer_rounded, color: Neon.pink, size: 22),
            const SizedBox(width: 10),
            Expanded(child: Text(d.text, style: TextStyle(color: _ink, fontSize: 13.5, height: 1.35))),
            if (d.code.isNotEmpty)
              OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: d.code));
                  HapticFeedback.selectionClick();
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Code ${d.code} copied.')));
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: _accent,
                  side: BorderSide(color: _accent.withValues(alpha: 0.6)),
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.copy_rounded, size: 15),
                label: Text(d.code),
              ),
          ],
        ),
      );

  Widget _specs(PriceResult r) {
    final specs = r.facts.pairs('specs');
    final hl = r.facts.strs('highlights', max: 4);
    final shown = _allSpecs ? specs : specs.take(6).toList();
    return Container(
      decoration: _cardBox(),
      clipBehavior: Clip.antiAlias,
      child: AnimatedSize(
        duration: Motion.enter,
        curve: Motion.easeMove,
        alignment: Alignment.topCenter,
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
            for (final (i, (k, v)) in shown.indexed)
              Container(
                color: i.isEven ? _line.withValues(alpha: 0.35) : null,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 110, child: Text(k, style: TextStyle(color: _inkLo, fontSize: 13))),
                    Expanded(child: Text(v, style: TextStyle(color: _ink, fontSize: 13, fontWeight: FontWeight.w600))),
                  ],
                ),
              ),
            if (specs.length > 6)
              TextButton(
                onPressed: () => setState(() => _allSpecs = !_allSpecs),
                child: Text(_allSpecs ? 'Show Less' : 'Show All ${specs.length} Specifications'),
              ),
          ],
        ),
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
      Padding(
        padding: const EdgeInsets.only(top: 26),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _sectionHead('Deals in This Category'),
          SizedBox(
            height: 160 + productCardText(context, rating: hits.any((h) => h.rating != null)),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              itemCount: hits.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) => SizedBox(
                width: 160,
                child: ProductCard(
                  name: hits[i].name,
                  store: hits[i].store,
                  image: hits[i].image,
                  price: hits[i].price,
                  mrp: hits[i].mrp,
                  rating: hits[i].rating,
                  reviews: hits[i].reviews,
                  onTap: () => Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => ProductDetailScreen(query: hits[i].name, hit: hits[i]))),
                ),
              ),
            ),
          ),
        ]),
      ),
    ];
  }

  /// Fixed at the bottom: Set Alert and Buy at the best price.
  Widget _bottomBar(PriceResult? r) {
    final low = r?.lowest;
    final link = low == null ? '' : _link(low);
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.paddingOf(context).bottom),
      decoration: BoxDecoration(
        color: Neon.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: _line)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 20, offset: const Offset(0, -4))],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 54,
            height: 54,
            child: Tooltip(
              message: 'Set Alert',
              child: OutlinedButton(
                onPressed: r == null ? null : () => _setAlert(r),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  foregroundColor: _accent,
                  side: BorderSide(color: r == null ? _line : _accent.withValues(alpha: 0.6)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Semantics(label: 'Set Alert', child: const Icon(Icons.notifications_none_rounded)),
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
                  backgroundColor: Neon.accentFill,
                  foregroundColor: Neon.onAccent,
                  // While prices load: a plain, legible "not yet", not a
                  // faded violet that looks broken.
                  disabledBackgroundColor: Neon.surfaceHigh,
                  disabledForegroundColor: Neon.textLo,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: AnimatedSwitcher(
                  duration: Motion.short,
                  child: FittedBox(
                    key: ValueKey(low?.store),
                    fit: BoxFit.scaleDown,
                    child: Text(low == null ? 'Buy Now' : 'Buy Now on ${low.store} · ${rupees(low.price)}',
                        maxLines: 1, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
                  ),
                ),
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
      backgroundColor: Neon.surface,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(ctx).bottom),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Notify When the Price Falls To', style: NeonType.manrope(19, FontWeight.w800).copyWith(color: _ink)),
              const SizedBox(height: 4),
              Text('Currently ${rupees(now)} on ${r.lowest!.store}', style: TextStyle(color: _inkLo)),
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
                  fillColor: Neon.surfaceHigh,
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
                  style: FilledButton.styleFrom(backgroundColor: Neon.accentFill, foregroundColor: Neon.onAccent),
                  child: const Text('Set Alert'),
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
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Alert set for ${rupees(target)} or less.')));
    }
  }
}

/// The deal score, 0–100, on a half-ring from red to green that sweeps to
/// its value.
class _ScoreGauge extends StatelessWidget {
  const _ScoreGauge({required this.score});
  final int score;

  @override
  Widget build(BuildContext context) {
    final still = Motion.reduced(context);
    return Semantics(
      label: 'Deal score $score out of 100',
      excludeSemantics: true,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: still ? score / 100 : 0, end: score / 100),
        duration: Duration(milliseconds: still ? 0 : 900),
        curve: Curves.easeOutCubic,
        builder: (_, t, __) => SizedBox(
          width: 86,
          height: 70,
          child: CustomPaint(
            painter: _GaugePainter(t),
            child: Padding(
              padding: const EdgeInsets.only(top: 22),
              child: Column(
                children: [
                  Text('${(t * 100).round()}',
                      style: TextStyle(color: _ink, fontSize: 24, fontWeight: FontWeight.w800, height: 1)),
                  Text('SCORE',
                      style: TextStyle(color: _inkLo, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
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
      ..shader = SweepGradient(
        startAngle: math.pi * 0.9,
        endAngle: math.pi * 2.1,
        colors: [Neon.error, Neon.warning, Neon.success],
      ).createShader(rect);
    canvas.drawArc(rect, math.pi * 0.9, math.pi * 1.2 * t.clamp(0.02, 1.0), false, fill);
  }

  @override
  bool shouldRepaint(_GaugePainter old) => old.t != t;
}

/// Lowest, usual and highest reported, with today's price marked; the
/// bars grow in.
class _RangeChart extends StatelessWidget {
  const _RangeChart({required this.low, required this.avg, required this.high, required this.now});
  final double? low, avg, high;
  final double now;

  @override
  Widget build(BuildContext context) {
    final vals = [low, avg, high, now].whereType<double>().toList();
    final lo = vals.reduce(math.min), hi = vals.reduce(math.max);
    final still = Motion.reduced(context);
    double y(double v) => hi <= lo ? 0.5 : (v - lo) / (hi - lo);
    Widget bar(int i, String label, double? v, Color c, {bool today = false}) => Expanded(
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
              TweenAnimationBuilder<double>(
                tween: Tween(begin: still ? 1 : 0, end: 1),
                duration: Duration(milliseconds: still ? 0 : 550 + 90 * i),
                curve: Curves.easeOutCubic,
                builder: (_, k, __) => Container(
                  height: (v == null ? 4 : 24 + 70 * y(v)) * k,
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: c.withValues(alpha: today ? 1 : 0.35),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(label,
                  style: TextStyle(
                      color: today ? _ink : _inkLo, fontSize: 12, fontWeight: today ? FontWeight.w800 : FontWeight.w500)),
            ],
          ),
        );
    return SizedBox(
      height: 110 + MediaQuery.textScalerOf(context).scale(44),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          bar(0, 'Lowest', low, _green),
          bar(1, 'Usual', avg, _accent),
          bar(2, 'Highest', high, _red),
          bar(3, 'Today', now, Neon.cyan, today: true),
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
    final c = Neon.success;
    canvas.drawPath(
        area,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [c.withValues(alpha: 0.35), c.withValues(alpha: 0.03)],
          ).createShader(Offset.zero & size));
    canvas.drawPath(
        line,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = c);
    final tp = TextPainter(
      text: TextSpan(
          text: 'Lowest: ${rupees(lo)}',
          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
      textDirection: TextDirection.ltr,
    )..layout();
    final box = Rect.fromLTWH(0, size.height - tp.height - 8, tp.width + 12, tp.height + 6);
    canvas.drawRRect(RRect.fromRectAndRadius(box, const Radius.circular(5)), Paint()..color = c);
    tp.paint(canvas, Offset(6, box.top + 3));
  }

  @override
  bool shouldRepaint(_LinePainter old) => old.points != points;
}

/// The deal score, for tests and other pages.
abstract final class ProductDetailScreenScore {
  static int? of(PriceResult r) => _ProductDetailScreenState.dealScore(r);
}
