import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/log.dart';
import '../../design/motion.dart';
import '../../design/neon_tokens.dart';
import '../assistant/widgets/action_cards.dart' show SearchSuggestionChips;
import 'price_models.dart';
import 'price_result_screen.dart';
import 'product_screens.dart';
import 'price_service.dart';
import 'price_widgets.dart';

/// ─────────────────────────────────────────────────────────────────────────
///  SHOP IN THE APP (2026-11-07, Manish: "an in-app browser so the other
///  services' websites run in our app; when they open a product, a Compare
///  button pops up at the bottom"; then "like this [a tabbed browser]: open
///  many websites, and compare with my assistant's AI to recommend a
///  product").
///
///  Tabs along a dark top bar (store mark, name, ✕, and + for another
///  store); a white page with "Opening Amazon" while it loads; Back,
///  Forward, Refresh, Share and More along the bottom. On every page the
///  product is read from what the page itself publishes (schema.org
///  Product data, Open Graph tags, and the title/price on Amazon and
///  Flipkart). When one is found, a bar rises with it: Compare runs the
///  usual price comparison; Ask AI weighs every product open in the tabs
///  and says which to buy, with alternatives.
///
///  Nothing is filled in on the user's behalf and nothing is read from
///  forms: only the product's name, price and photo.
/// ─────────────────────────────────────────────────────────────────────────
class ShopBrowserScreen extends StatefulWidget {
  const ShopBrowserScreen({super.key, required this.url, this.category = PriceCategory.shopping});

  final String url;

  /// What a found product is compared as (shopping or grocery).
  final PriceCategory category;

  @override
  State<ShopBrowserScreen> createState() => _ShopBrowserScreenState();
}

/// The stores a new tab can open, with their home pages.
List<(PriceStore, PriceCategory, String)> get shopStores => [
      for (final s in PriceStores.shopping) (s, PriceCategory.shopping, 'https://www.${s.domains.first}/'),
      for (final s in PriceStores.grocery)
        (
          s,
          PriceCategory.grocery,
          s == PriceStores.instamart ? 'https://www.swiggy.com/instamart' : 'https://www.${s.domains.first}/',
        ),
    ];

/// One open site.
class _Tab {
  _Tab(this.url, this.category) : id = _next++;
  static int _next = 0;
  final int id;
  final PriceCategory category;
  late final WebViewController web;
  String url;
  String title = '';
  int progress = 0;
  bool loaded = false;
  bool canBack = false, canForward = false;
  PageProduct? product;
  String dismissed = '';
  Timer? probe;

  String get host => Uri.tryParse(url)?.host.replaceFirst('www.', '') ?? '';
  PriceStore? get store {
    final h = host;
    for (final (s, _, _) in shopStores) {
      if (s.domains.any((d) => h == d || h.endsWith('.$d'))) return s;
    }
    return null;
  }

  /// The store's name; for other sites, the brand from the logo list
  /// ("Rapido", "Zomato"), else the site's own short name.
  String get name {
    final st = store;
    if (st != null) return st.name;
    final logo = brandLogoFor(host: host);
    final id = logo == null ? '' : logo.split('/').last.replaceAll('.png', '');
    final known = _brandNames[id];
    if (known != null) return known;
    final parts = host.split('.');
    final label = parts.length >= 2 ? parts[parts.length - 2] : host;
    return label.isEmpty ? title : '${label[0].toUpperCase()}${label.substring(1)}';
  }
}

class _ShopBrowserScreenState extends State<ShopBrowserScreen> {
  // ONE BROWSER (2026-11-08): every store tap used to push a new browser
  // screen with one tab, and Back threw its tabs away. The tabs now live
  // here, outside any one screen: opening a store again comes back to its
  // tab, a new store is a new tab, and leaving the browser keeps them.
  static final List<_Tab> _session = [];
  static int _sessionI = 0;

  /// The browser screen on show, if any; page events report to it.
  static _ShopBrowserScreenState? _live;

  /// Most tabs kept open at once; the oldest goes first.
  static const _maxTabs = 6;

  List<_Tab> get _tabs => _session;
  int get _i => _sessionI.clamp(0, _session.isEmpty ? 0 : _session.length - 1);
  set _i(int v) => _sessionI = v;

  _Tab get _tab => _tabs[_i];

  @override
  void initState() {
    super.initState();
    _live = this;
    _openOrSelect(widget.url, widget.category);
  }

  @override
  void dispose() {
    if (identical(_live, this)) _live = null;
    for (final t in _tabs) {
      t.probe?.cancel();
    }
    super.dispose();
  }

  /// Shows [url]: the tab already on it, or on that store's home page
  /// when [url] is the store's home too; otherwise a new tab.
  void _openOrSelect(String url, PriceCategory category) {
    final host = Uri.tryParse(url)?.host.replaceFirst('www.', '') ?? '';
    final path = Uri.tryParse(url)?.path ?? '';
    final home = path.isEmpty || path == '/' || path == '/instamart';
    for (var k = 0; k < _tabs.length; k++) {
      final t = _tabs[k];
      if (t.url == url || (home && t.host == host)) {
        if (mounted) {
          setState(() => _i = k);
        } else {
          _i = k;
        }
        return;
      }
    }
    _open(url, category);
  }

  /// A page event: redraw the browser on show (none: nothing to draw).
  static void _changed(VoidCallback f) {
    final s = _live;
    if (s != null && s.mounted) {
      // ignore: invalid_use_of_protected_member
      s.setState(f);
    } else {
      f();
    }
  }

  // ── tabs ─────────────────────────────────────────────────────────────

  void _open(String url, PriceCategory category, {bool select = true}) {
    final t = _Tab(url, category);
    t.web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (p) => _changed(() {
          t.progress = p;
          if (p >= 60) t.loaded = true;
        }),
        onPageStarted: (u) => _changed(() {
          t.url = u;
          t.product = null;
        }),
        onPageFinished: (_) {
          _changed(() => t.loaded = true);
          _live?._afterChange(t);
        },
        // Amazon and Flipkart change pages without loading a new one.
        onUrlChange: (c) {
          final u = c.url;
          if (u == null || u == t.url) return;
          _changed(() {
            t.url = u;
            t.product = null;
          });
          _live?._afterChange(t);
        },
        onNavigationRequest: (r) {
          final u = Uri.tryParse(r.url);
          if (u == null) return NavigationDecision.prevent;
          if (u.scheme == 'http' || u.scheme == 'https') return NavigationDecision.navigate;
          // "Open in app" links (intent://, market://): stay here — the
          // compare bar only works in this browser. An intent link often
          // carries the web page to use instead; load that.
          final fallback = webFallbackOf(r.url);
          AppLog.add('shop', 'kept in browser: ${u.scheme}${fallback == null ? '' : ' -> $fallback'}');
          if (fallback != null) t.web.loadRequest(Uri.parse(fallback));
          return NavigationDecision.prevent;
        },
      ))
      ..loadRequest(Uri.parse(url));
    void add() {
      _tabs.add(t);
      while (_tabs.length > _maxTabs) {
        _tabs.removeAt(0).probe?.cancel();
      }
      if (select) _i = _tabs.length - 1;
    }

    mounted ? setState(add) : add();
  }

  void _close(int i) {
    HapticFeedback.selectionClick();
    if (_tabs.length == 1) {
      // The last tab closed: the browser goes, and starts afresh next time.
      _tabs.removeAt(0).probe?.cancel();
      _i = 0;
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _tabs.removeAt(i).probe?.cancel();
      if (_i >= _tabs.length) _i = _tabs.length - 1;
      if (i < _i) _i--;
    });
  }

  Future<void> _newTab() async {
    final pick = await showModalBottomSheet<(PriceStore, PriceCategory, String)>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Open another store', style: NeonType.manrope(18, FontWeight.w800).copyWith(color: _ink)),
              const SizedBox(height: 4),
              const Text('Open the same product on two sites, then Ask AI which to buy.',
                  style: TextStyle(color: _inkLo, fontSize: 13)),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 4,
                shrinkWrap: true,
                mainAxisSpacing: 14,
                crossAxisSpacing: 8,
                childAspectRatio: 0.82,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (final s in shopStores)
                    InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => Navigator.pop(ctx, s),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _StoreIcon(store: s.$1, size: 54),
                          const SizedBox(height: 6),
                          Text(s.$1.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: _ink, fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (pick != null) _openOrSelect(pick.$3, pick.$2);
  }

  // ── reading the page ─────────────────────────────────────────────────

  /// Reads the page a few times as it settles (prices often load late).
  void _afterChange(_Tab t) {
    t.probe?.cancel();
    _refreshNav(t);
    var tries = 0;
    _read(t);
    t.probe = Timer.periodic(const Duration(milliseconds: 1200), (timer) {
      // Product pages often fill in a few seconds after loading: ~12 s.
      // Not stopping at the first name found: the first read after a tap
      // can still see the page being left (Flipkart's "For You"), so the
      // name keeps being read while the page settles (2026-11-08).
      if (++tries >= 10) {
        timer.cancel();
        return;
      }
      _read(t);
    });
  }

  Future<void> _refreshNav(_Tab t) async {
    try {
      final back = await t.web.canGoBack();
      final fwd = await t.web.canGoForward();
      final title = await t.web.getTitle() ?? '';
      if (!mounted) return;
      setState(() {
        t.canBack = back;
        t.canForward = fwd;
        t.title = title;
      });
    } catch (_) {}
  }

  Future<void> _read(_Tab t) async {
    try {
      final raw = await t.web.runJavaScriptReturningResult(_readProduct);
      final p = PageProduct.read(raw);
      if (p != null && t.product?.name != p.name) AppLog.add('shop', 'product on ${t.host}: ${p.name}');
      if (!mounted) return;
      // A read that finds nothing keeps what an earlier one found (a page
      // mid-render); a new page clears it in onPageStarted / onUrlChange.
      if (p == null || (p.name == t.product?.name && p.price == t.product?.price)) return;
      if (t.product == null && identical(t, _tab)) HapticFeedback.selectionClick();
      setState(() => t.product = p);
    } catch (e) {
      // A page mid-navigation refuses scripts; the next try will do.
      AppLog.add('shop', 'read failed on ${t.host}: $e');
    }
  }

  // ── actions ──────────────────────────────────────────────────────────

  Future<void> _compare(_Tab t, PageProduct shown) async {
    HapticFeedback.mediumImpact();
    // Compare what the page says NOW, not what an early read saw.
    await _read(t);
    if (!mounted) return;
    final p = t.product ?? shown;
    final seen = p.price == null ? '' : ' (seen at ${rupees(p.price!)} on ${t.name})';
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => t.category == PriceCategory.shopping
          ? ProductDetailScreen(
              query: '${p.name}$seen',
              hit: p.price == null
                  ? null
                  : ProductHit(name: p.name, price: p.price!, store: t.name, image: p.image, url: p.url),
            )
          : PriceResultScreen(category: t.category, query: '${p.name}$seen'),
    ));
  }

  void _askAi() {
    HapticFeedback.mediumImpact();
    final open = [
      for (final t in _tabs)
        if (t.product case final p?) (name: p.name, price: p.price, store: t.name),
    ];
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _AdviceSheet(
          products: open,
          onAddStore: () {
            Navigator.of(context).pop();
            _newTab();
          }),
    );
  }

  void _more() async {
    final t = _tab;
    final v = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (k, icon, label) in [
              ('tab', Icons.add_box_outlined, 'New tab'),
              ('open', Icons.open_in_browser_rounded, 'Open in browser'),
              ('copy', Icons.link_rounded, 'Copy link'),
              ('close', Icons.tab_unselected_rounded, 'Close all tabs'),
            ])
              ListTile(
                leading: Icon(icon, color: _ink),
                title: Text(label, style: const TextStyle(color: _ink, fontWeight: FontWeight.w600)),
                onTap: () => Navigator.pop(ctx, k),
              ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    switch (v) {
      case 'tab':
        _newTab();
      case 'open':
        launchUrl(Uri.parse(t.url), mode: LaunchMode.externalApplication);
      case 'copy':
        Clipboard.setData(ClipboardData(text: t.url));
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link copied')));
      case 'close':
        Navigator.of(context).pop();
    }
  }

  // ── the screen ───────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final t = _tab;
    final p = t.product;
    final showBar = p != null && p.url != t.dismissed;
    final products = _tabs.where((x) => x.product != null).length;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await t.web.canGoBack()) {
          await t.web.goBack();
        } else if (context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: _bar,
          systemNavigationBarColor: Colors.white,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
        child: Scaffold(
          backgroundColor: Colors.white,
          body: Column(
            children: [
              _tabStrip(),
              SizedBox(
                height: 3,
                child: t.progress < 100
                    ? LinearProgressIndicator(
                        value: t.progress / 100,
                        color: const Color(0xFF5B5BF0),
                        backgroundColor: const Color(0xFFEDEDF5),
                      )
                    : const ColoredBox(color: Color(0xFFEDEDF5)),
              ),
              Expanded(
                child: Stack(
                  children: [
                    IndexedStack(
                      index: _i,
                      children: [
                        for (final x in _tabs) WebViewWidget(key: ValueKey(x.id), controller: x.web),
                      ],
                    ),
                    if (!t.loaded) Positioned.fill(child: _Opening(tab: t)),
                    AnimatedPositioned(
                      duration: Motion.short,
                      curve: Curves.easeOutCubic,
                      left: 10,
                      right: 10,
                      bottom: showBar ? 10 : -220,
                      child: p == null
                          ? const SizedBox.shrink()
                          : _CompareBar(
                              product: p,
                              others: products - 1,
                              onCompare: () => _compare(t, p),
                              onAsk: _askAi,
                              onClose: () => setState(() => t.dismissed = p.url),
                            ),
                    ),
                  ],
                ),
              ),
              _toolbar(t),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tabStrip() => Container(
        color: _bar,
        padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
        child: SizedBox(
          height: 58,
          child: Row(
            children: [
              IconButton(
                tooltip: 'Close browser',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 22),
              ),
              Expanded(
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _tabs.length,
                  itemBuilder: (_, i) => _tabChip(i),
                ),
              ),
              IconButton(
                tooltip: 'New tab',
                onPressed: _newTab,
                icon: const Icon(Icons.add_rounded, color: Colors.white, size: 26),
              ),
            ],
          ),
        ),
      );

  Widget _tabChip(int i) {
    final t = _tabs[i];
    final on = i == _i;
    return Padding(
      padding: const EdgeInsets.only(top: 8, right: 6),
      child: Semantics(
        button: true,
        selected: on,
        label: '${t.name} tab',
        child: GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _i = i);
          },
          child: AnimatedContainer(
            duration: Motion.short,
            constraints: const BoxConstraints(maxWidth: 168),
            padding: const EdgeInsets.fromLTRB(10, 0, 4, 0),
            decoration: BoxDecoration(
              color: on ? Colors.white : Colors.white.withValues(alpha: 0.10),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _StoreIcon(store: t.store, name: t.name, host: t.host, size: 26),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(t.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: on ? _ink : Colors.white.withValues(alpha: 0.8),
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                ),
                if (t.product != null) ...[
                  const SizedBox(width: 4),
                  Icon(Icons.sell_rounded, size: 13, color: on ? const Color(0xFF5B5BF0) : Colors.white70),
                ],
                IconButton(
                  tooltip: 'Close ${t.name}',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _close(i),
                  icon: Icon(Icons.close_rounded, size: 20, color: on ? _ink : Colors.white70),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _toolbar(_Tab t) {
    Widget item(IconData icon, String label, VoidCallback? onTap, {bool filled = false}) {
      final c = onTap == null ? const Color(0xFFBDBDC7) : _ink;
      return Expanded(
        child: InkWell(
          onTap: onTap == null
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  onTap();
                },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                filled
                    ? Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                        child: Icon(icon, color: Colors.white, size: 19),
                      )
                    : SizedBox(height: 30, child: Icon(icon, color: c, size: 26)),
                const SizedBox(height: 4),
                Text(label, style: TextStyle(color: c, fontSize: 12.5, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFEDEDF2))),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
      child: Row(
        children: [
          item(Icons.arrow_back_rounded, 'Back', t.canBack ? () => t.web.goBack() : null, filled: true),
          item(Icons.arrow_forward_rounded, 'Forward', t.canForward ? () => t.web.goForward() : null, filled: true),
          item(Icons.refresh_rounded, 'Refresh', () => t.web.reload(), filled: true),
          item(Icons.ios_share_rounded, 'Share', () => Share.share(t.url, subject: t.title)),
          item(Icons.more_vert_rounded, 'More', _more),
        ],
      ),
    );
  }
}

const _bar = Color(0xFF0F172A);
const _ink = Color(0xFF111827);
const _inkLo = Color(0xFF6B7280);

/// A site's app icon — the brand logos bundled in assets/brands/ (the
/// same ones Home's Popular apps shows) — or its initial on its colour
/// for a site without one.
class _StoreIcon extends StatelessWidget {
  const _StoreIcon({required this.store, this.name, this.host = '', this.size = 26});
  final PriceStore? store;
  final String? name;

  /// The page's host, for sites that are not one of the compare stores.
  final String host;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = store?.color ?? const Color(0xFF6B7280);
    final n = store?.name ?? name ?? '?';
    final logo = brandLogoFor(store: store, host: host);
    final r = BorderRadius.circular(size * 0.26);
    final letter = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: c, borderRadius: r),
      child: Text(n.isEmpty ? '?' : n.characters.first.toUpperCase(),
          style: NeonType.manrope(size * 0.5, FontWeight.w900)
              .copyWith(color: c.computeLuminance() > 0.55 ? _ink : Colors.white, height: 1)),
    );
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: r,
        boxShadow: size > 40
            ? [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 12, offset: const Offset(0, 4))]
            : null,
      ),
      child: ClipRRect(
        borderRadius: r,
        child: logo == null
            ? letter
            : Image.asset(logo,
                width: size,
                height: size,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.medium,
                errorBuilder: (_, __, ___) => letter),
      ),
    );
  }
}

/// The bundled logos (assets/brands/<id>.png), by the site's own name.
const _brandLogos = {
  'acko',
  'agoda',
  'ajio',
  'amazon',
  'apollo247',
  'bigbasket',
  'blinkit',
  'booking',
  'bookmyshow',
  'croma',
  'flipkart',
  'fnp',
  'goibibo',
  'igp',
  'makemytrip',
  'mamaearth',
  'myntra',
  'nammayatri',
  'netmeds',
  'nykaa',
  'ola',
  'pharmeasy',
  'policybazaar',
  'porter',
  'purplle',
  'rapido',
  'reliancedigital',
  'shiprocket',
  'swiggy',
  'tata1mg',
  'tatacliq',
  'uber',
  'urbancompany',
  'zepto',
  'zomato',
};

/// Brand names spelt as the brands do.
const _brandNames = {
  'tata1mg': 'Tata 1mg',
  'urbancompany': 'Urban Company',
  'pharmeasy': 'PharmEasy',
  'apollo247': 'Apollo 24|7',
  'nammayatri': 'Namma Yatri',
  'bookmyshow': 'BookMyShow',
  'makemytrip': 'MakeMyTrip',
  'policybazaar': 'PolicyBazaar',
  'tatacliq': 'Tata CLiQ',
  'bigbasket': 'BigBasket',
  'reliancedigital': 'Reliance Digital',
  'fnp': 'FNP',
  'igp': 'IGP',
  'ajio': 'AJIO',
};

/// Sites whose host name is not their logo's name.
const _hostLogo = {
  'zeptonow': 'zepto',
  '1mg': 'tata1mg',
  'olacabs': 'ola',
  'nykaafashion': 'nykaa',
  'amzn': 'amazon',
  'fkrt': 'flipkart',
  'oyorooms': '',
};

/// The bundled logo for [store] or [host]; null when there is none.
/// Instamart is part of Swiggy and uses its logo.
String? brandLogoFor({PriceStore? store, String host = ''}) {
  String? id;
  if (store != null) {
    id = store.name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (store == PriceStores.instamart) id = 'swiggy';
    if (!_brandLogos.contains(id) && store.domains.isNotEmpty) id = null;
  }
  if (id == null || !_brandLogos.contains(id)) {
    final h = (host.isNotEmpty ? host : (store?.domains.firstOrNull ?? '')).replaceFirst('www.', '');
    final parts = h.split('.');
    // "m.zomato.com" → zomato; "blinkit.com" → blinkit.
    final label = parts.length >= 2 ? parts[parts.length - 2] : h;
    id = _hostLogo[label] ?? label;
  }
  return id.isNotEmpty && _brandLogos.contains(id) ? 'assets/brands/$id.png' : null;
}

/// "Opening Amazon" while the first page loads.
class _Opening extends StatelessWidget {
  const _Opening({required this.tab});
  final _Tab tab;

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: Colors.white,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F8FB),
                  borderRadius: BorderRadius.circular(40),
                  border: Border.all(color: const Color(0xFFE3E7EF), width: 1.5),
                ),
                child: _StoreIcon(store: tab.store, name: tab.name, host: tab.host, size: 110),
              ),
              const SizedBox(height: 28),
              Text.rich(
                TextSpan(children: [
                  const TextSpan(text: 'Opening ', style: TextStyle(color: Color(0xFF4B5563))),
                  TextSpan(text: tab.name, style: const TextStyle(color: _ink, fontWeight: FontWeight.w800)),
                ]),
                style: const TextStyle(fontSize: 21),
              ),
              const SizedBox(height: 40),
              const SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(strokeWidth: 3, color: Color(0xFF5B5BF0)),
              ),
            ],
          ),
        ),
      );
}

class _CompareBar extends StatelessWidget {
  const _CompareBar({
    required this.product,
    required this.others,
    required this.onCompare,
    required this.onAsk,
    required this.onClose,
  });
  final PageProduct product;

  /// Products open in the other tabs (Ask AI weighs them together).
  final int others;
  final VoidCallback onCompare;
  final VoidCallback onAsk;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final p = product;
    return Semantics(
      container: true,
      label: 'Product found: ${p.name}',
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 24, offset: const Offset(0, 8)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 48,
                      height: 48,
                      color: const Color(0xFFF3F4F6),
                      child: p.image.isEmpty
                          ? const Icon(Icons.shopping_bag_rounded, color: Color(0xFF5B5BF0))
                          : Image.network(p.image,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) =>
                                  const Icon(Icons.shopping_bag_rounded, color: Color(0xFF5B5BF0))),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(p.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style:
                                const TextStyle(color: _ink, fontSize: 13, fontWeight: FontWeight.w600, height: 1.25)),
                        if (p.price != null)
                          Text('${rupees(p.price!)} here',
                              style: NeonType.manrope(14, FontWeight.w800).copyWith(color: const Color(0xFF15803D))),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Hide',
                    visualDensity: VisualDensity.compact,
                    onPressed: onClose,
                    icon: const Icon(Icons.close_rounded, size: 18, color: _inkLo),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onCompare,
                      style: FilledButton.styleFrom(
                        backgroundColor: _ink,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: const StadiumBorder(),
                      ),
                      icon: const Icon(Icons.compare_arrows_rounded, size: 18),
                      label: Text('Compare prices', style: NeonType.manrope(14, FontWeight.w800)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onAsk,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF5B5BF0),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: const StadiumBorder(),
                      ),
                      icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                      label: Text(others > 0 ? 'Ask AI (${others + 1})' : 'Ask AI',
                          style: NeonType.manrope(14, FontWeight.w800)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// THE AI'S RECOMMENDATION: which of the open products to buy, the good
/// and bad of each, alternatives, and where it read that.
class _AdviceSheet extends StatefulWidget {
  const _AdviceSheet({required this.products, required this.onAddStore});
  final List<({String name, double? price, String store})> products;
  final VoidCallback onAddStore;

  @override
  State<_AdviceSheet> createState() => _AdviceSheetState();
}

class _AdviceSheetState extends State<_AdviceSheet> {
  ProductAdvice? _a;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    setState(() {
      _a = null;
      _error = '';
    });
    try {
      final a = await PriceService.instance.recommend(widget.products);
      if (mounted) setState(() => _a = a);
    } catch (e) {
      if (mounted) setState(() => _error = e is PriceCompareException ? e.message : 'Something went wrong.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = _a;
    final ps = widget.products;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      maxChildSize: 0.94,
      builder: (_, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, color: Color(0xFF5B5BF0)),
              const SizedBox(width: 8),
              Text('MyAssistant recommends', style: NeonType.manrope(18, FontWeight.w800).copyWith(color: _ink)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
              ps.length == 1
                  ? 'Is this a good buy? Open the same kind of product on another store to compare them.'
                  : 'Weighing the ${ps.length} products open in your tabs.',
              style: const TextStyle(color: _inkLo, fontSize: 13)),
          const SizedBox(height: 16),
          if (a == null && _error.isEmpty) ...[
            const SizedBox(height: 30),
            const Center(child: CircularProgressIndicator(color: Color(0xFF5B5BF0))),
            const SizedBox(height: 14),
            const Center(
                child: Text('Reading reviews, specs and prices…', style: TextStyle(color: _inkLo, fontSize: 13))),
          ] else if (_error.isNotEmpty) ...[
            Text(_error, style: const TextStyle(color: Color(0xFFB91C1C))),
            const SizedBox(height: 10),
            Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton(onPressed: _run, child: const Text('Try again'))),
          ] else if (a != null) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFC7D2FE)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a.verdict, style: NeonType.manrope(16, FontWeight.w800).copyWith(color: _ink, height: 1.3)),
                  if (a.why.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(a.why, style: const TextStyle(color: Color(0xFF374151), fontSize: 13.5, height: 1.4)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            for (final (i, p) in ps.indexed) _item(i, p, a),
            if (a.alternatives.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('Also worth a look', style: NeonType.manrope(15, FontWeight.w800).copyWith(color: _ink)),
              const SizedBox(height: 6),
              for (final x in a.alternatives)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: const Icon(Icons.lightbulb_outline_rounded, color: Color(0xFFD97706)),
                  title: Text(x.name, style: const TextStyle(color: _ink, fontWeight: FontWeight.w700)),
                  subtitle: x.why.isEmpty ? null : Text(x.why, style: const TextStyle(color: _inkLo)),
                  trailing: x.price == null
                      ? null
                      : Text(rupees(x.price!), style: const TextStyle(color: _ink, fontWeight: FontWeight.w700)),
                ),
            ],
            if (ps.length == 1) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: widget.onAddStore,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Open another store to compare'),
              ),
            ],
            if (a.sources.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Text('Sources', style: TextStyle(color: _inkLo, fontWeight: FontWeight.w700, fontSize: 12.5)),
              for (final s in a.sources.take(5))
                InkWell(
                  onTap: () => openPriceLink(s.uri),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Text((s.title?.isNotEmpty ?? false) ? s.title! : s.uri,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Color(0xFF4F46E5), fontSize: 12.5)),
                  ),
                ),
            ],
            if (a.suggestions.isNotEmpty) ...[
              const SizedBox(height: 8),
              SearchSuggestionChips(suggestions: a.suggestions),
            ],
            const SizedBox(height: 10),
            const Text('AI advice from the web — check the final price and details on the store.',
                style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11.5)),
          ],
        ],
      ),
    );
  }

  Widget _item(int i, ({String name, double? price, String store}) p, ProductAdvice a) {
    final it = i < a.items.length ? a.items[i] : null;
    final pick = i == a.pick && widget.products.length > 1;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: pick ? const Color(0xFF16A34A) : const Color(0xFFE5E7EB), width: pick ? 1.6 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (pick)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: const Color(0xFF16A34A), borderRadius: BorderRadius.circular(20)),
                  child: const Text('BEST BUY',
                      style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800)),
                ),
              Expanded(
                child: Text(it?.name.isNotEmpty == true ? it!.name : p.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _ink, fontWeight: FontWeight.w700, fontSize: 14)),
              ),
              if (it?.score != null)
                Text('${it!.score}/10',
                    style: NeonType.manrope(15, FontWeight.w800).copyWith(color: const Color(0xFF4F46E5))),
            ],
          ),
          Text('${p.price == null ? '' : '${rupees(p.price!)} · '}${p.store}',
              style: const TextStyle(color: _inkLo, fontSize: 12.5)),
          if (it != null) ...[
            const SizedBox(height: 6),
            for (final g in it.good) _point(Icons.check_circle_rounded, const Color(0xFF16A34A), g),
            for (final b in it.bad) _point(Icons.remove_circle_rounded, const Color(0xFFDC2626), b),
          ],
        ],
      ),
    );
  }

  Widget _point(IconData icon, Color c, String t) => Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 15, color: c),
            const SizedBox(width: 6),
            Expanded(child: Text(t, style: const TextStyle(color: Color(0xFF374151), fontSize: 13))),
          ],
        ),
      );
}

/// What the page says it is selling.
class PageProduct {
  const PageProduct({required this.name, this.price, this.image = '', required this.url});
  final String name;
  final double? price;
  final String image;
  final String url;

  /// From the page script's answer; null when the page is not a product.
  static PageProduct? read(Object? raw) {
    Object? v = raw;
    // Android hands back the JSON string JSON-encoded once more.
    for (var i = 0; i < 2 && v is String; i++) {
      try {
        v = jsonDecode(v);
      } catch (_) {
        break;
      }
    }
    if (v is! Map) return null;
    var name = '${v['name'] ?? ''}'.replaceAll(RegExp(r'\s+'), ' ').trim();
    final url = '${v['url'] ?? ''}';
    final price = moneyOf('${v['price'] ?? ''}');
    final looksLikeProduct = v['product'] == true || _productUrl.hasMatch(url);
    // Only a real product page: one that says so (schema.org Product, an
    // Open Graph product, Amazon's product title) or a store's product URL.
    // A price alone is not enough — home and deal pages show many.
    if (name.isEmpty || !looksLikeProduct) return null;
    // A store's own slogan is never a product (a page read before its
    // product had shown); null keeps the page being read until it has.
    if (_storeSlogan.hasMatch(name)) return null;
    // Drop the shop's name tacked on the title ("… : Amazon.in", "| Flipkart").
    name = name.replaceAll(RegExp(r'\s*[:|\-–]\s*(Buy .*|Amazon\.in.*|Flipkart.*|Croma.*|Reliance Digital.*)$'), '');
    if (name.length > 140) name = '${name.substring(0, 140).trim()}…';
    final image = '${v['image'] ?? ''}';
    return PageProduct(
      name: name,
      price: price != null && price > 0 ? price : null,
      image: image.startsWith('https://') ? image : '',
      url: url,
    );
  }

  /// The titles of the stores' home, search and category pages.
  static final _storeSlogan = RegExp(
    r'^online shopping|online shopping (site|india)|buy products online at best price|'
    r'^amazon\.in\s*[:|]|shop online for|best offers!?$',
    caseSensitive: false,
  );

  /// Product pages on the stores we cover.
  static final _productUrl = RegExp(
    r'/dp/|/gp/product/|/gp/aw/d/|flipkart\.com/.+/p/|croma\.com/.+/p/|reliancedigital\.in/.+/p/'
    r'|blinkit\.com/prn/|zeptonow\.com/pn/|bigbasket\.com/pd/|swiggy\.com/instamart/item',
  );
}

/// Opens [url] in the in-app browser, so the site runs inside the app
/// (with Compare and Ask AI) rather than in the store's own app. Flights
/// and hotels keep the usual way: their sites need the full browser.
void openInShopBrowser(BuildContext context, String url, [PriceCategory? category]) {
  final u = Uri.tryParse(url);
  if (u == null || (u.scheme != 'https' && u.scheme != 'http')) return;
  if (category == PriceCategory.flights || category == PriceCategory.hotels) {
    openPriceLink(url);
    return;
  }
  HapticFeedback.selectionClick();
  final cat = category ?? categoryForUrl(url);
  // A browser already open under this screen: go back to it and show the
  // site there, rather than stacking a second browser on top.
  final live = _ShopBrowserScreenState._live;
  final route = live != null && live.mounted ? ModalRoute.of(live.context) : null;
  if (live != null && route != null && route.isActive) {
    Navigator.of(context).popUntil((r) => r == route);
    live._openOrSelect(url, cat);
    return;
  }
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => ShopBrowserScreen(url: url, category: cat)));
}

/// The web page an Android `intent://` link names for browsers
/// (`S.browser_fallback_url=`), or the https page it wraps; null if none.
String? webFallbackOf(String link) {
  if (!link.startsWith('intent:')) return null;
  final m = RegExp(r'S\.browser_fallback_url=([^;]+)').firstMatch(link);
  if (m != null) {
    final f = Uri.decodeComponent(m.group(1)!);
    if (f.startsWith('https://') || f.startsWith('http://')) return f;
  }
  final scheme = RegExp(r';scheme=(https?);').firstMatch(link)?.group(1);
  if (scheme != null) {
    final rest = link.substring('intent://'.length).split('#Intent').first;
    return '$scheme://$rest';
  }
  return null;
}

/// Grocery for the quick-commerce sites, shopping for everything else.
PriceCategory categoryForUrl(String url) {
  final h = Uri.tryParse(url)?.host ?? '';
  final grocery = PriceStores.grocery.any((s) => s.domains.any((d) => h == d || h.endsWith('.$d')));
  return grocery ? PriceCategory.grocery : PriceCategory.shopping;
}

/// The script run on each page: what the page says it is selling.
const _readProduct = r'''
(function () {
  function meta(k) {
    var e = document.querySelector('meta[property="' + k + '"],meta[name="' + k + '"],meta[itemprop="' + k + '"]');
    return e ? (e.getAttribute('content') || '') : '';
  }
  function text(sel) {
    var e = document.querySelector(sel);
    return e ? (e.textContent || '').trim() : '';
  }
  // THE PRICE AS A PERSON SEES IT (2026-11-08): Flipkart's class names
  // change all the time; its selling price is the biggest "₹12,446" near
  // the top of the page that is not struck through (that one is the MRP).
  function mainPrice() {
    var best = '', size = 0, all = document.querySelectorAll('div,span');
    var top = 2 * (window.innerHeight || 800);
    for (var i = 0; i < all.length; i++) {
      var e = all[i];
      if (e.children.length) continue;
      var t = (e.textContent || '').trim();
      if (!/^₹\s?[\d,]+(\.\d+)?$/.test(t)) continue;
      var r = e.getBoundingClientRect();
      if (r.width < 1 || r.top + window.scrollY > top) continue;
      var st = getComputedStyle(e);
      if (st.textDecorationLine.indexOf('line-through') >= 0) continue;
      var fs = parseFloat(st.fontSize) || 0;
      if (fs > size) { size = fs; best = t; }
    }
    return best;
  }
  // The longest of [sel] that is on screen. Flipkart keeps the page it
  // came from in the document, hidden: its first <h1> was the home's
  // "For You", read as the product's name (2026-11-08).
  function shown(sel) {
    var best = '', all = document.querySelectorAll(sel);
    for (var i = 0; i < all.length; i++) {
      var e = all[i], r = e.getBoundingClientRect();
      if (r.width < 1 || r.height < 1) continue;
      var st = getComputedStyle(e);
      if (st.visibility === 'hidden' || st.display === 'none' || st.opacity === '0') continue;
      var t = (e.textContent || '').replace(/\s+/g, ' ').trim();
      if (t.length > best.length) best = t;
    }
    return best;
  }
  var name = '', price = '', image = '', product = false;
  // STALE HEAD (2026-11-08): Flipkart and Amazon change pages without
  // loading a new one, and leave the <head> (og:title, ld+json) of the
  // page they started on. Opened from Flipkart's home, a product page
  // still said "Online Shopping India Mobile, Cameras…", and that was
  // compared. The canonical link tells whose head it is: when it names
  // another page, trust only what is on screen.
  var fresh = true;
  var canon = document.querySelector('link[rel="canonical"]');
  var cu = (canon && canon.href) || meta('og:url');
  if (cu) {
    try {
      var cp = new URL(cu, location.href).pathname.replace(/\/+$/, '');
      var lp = location.pathname.replace(/\/+$/, '');
      var last = cp.split('/').pop();
      fresh = cp === lp || (last !== '' && lp.indexOf(last) >= 0);
    } catch (e) {}
  }
  var blocks = fresh ? document.querySelectorAll('script[type="application/ld+json"]') : [];
  for (var i = 0; i < blocks.length; i++) {
    try {
      var j = JSON.parse(blocks[i].textContent);
      var list = Array.isArray(j) ? j : (j['@graph'] || [j]);
      for (var k = 0; k < list.length; k++) {
        var o = list[k], t = o['@type'];
        if (t === 'Product' || (Array.isArray(t) && t.indexOf('Product') >= 0)) {
          product = true;
          name = name || o.name || '';
          var of = o.offers;
          if (Array.isArray(of)) of = of[0];
          if (of) price = price || of.price || of.lowPrice || '';
          var im = o.image;
          image = image || (Array.isArray(im) ? im[0] : (im && im.url) || im) || '';
        }
      }
    } catch (e) {}
  }
  var host = location.hostname;
  if (host.indexOf('amazon.') >= 0) {
    // Only on a product page (it has #productTitle); the home and deal
    // pages are full of other prices.
    if (text('#productTitle') || text('#title')) {
      product = true;
      name = text('#productTitle') || text('#title');
      var im = document.querySelector('#main-image, #landingImage, #imgTagWrapperId img');
      if (im && im.src) image = im.src;
      // The phone site shows the price as "79,990" in .a-price-whole; its
      // first .a-offscreen is blank and the next one is the MRP.
      price = text('#corePriceDisplay_mobile_feature_div .a-price-whole') ||
        text('#corePriceDisplay_desktop_feature_div .a-price .a-offscreen') ||
        text('#corePrice_feature_div .a-offscreen') || text('#apex_desktop .a-offscreen') ||
        text('#priceblock_ourprice') || price;
    } else {
      product = false;
      price = '';
    }
  } else if (host.indexOf('flipkart.') >= 0) {
    // The phone site cuts a long title short with "...more".
    name = name || shown('h1').replace(/\s*(\.\.\.|…)\s*more$/i, '');
    // Flipkart names the product in the tab's title once it has opened.
    if (!name || name.length < 12) {
      var dt = (document.title || '').replace(/\s+Price in India.*$/i, '').replace(/\s*[-|:]\s*Buy .*$/i, '').trim();
      if (dt.length > name.length && !/online shopping|best offers|flipkart\.com$/i.test(dt)) name = dt;
    }
    price = price || text('div.Nx9bqj') || text('div._30jeq3') || text('div._16Jk6d') || mainPrice();
  }
  if (fresh) {
    if (meta('og:type') === 'product' || meta('og:type') === 'og:product') product = true;
    name = name || meta('og:title');
    price = price || meta('product:price:amount') || meta('og:price:amount') || meta('price');
    image = image || meta('og:image');
  }
  name = name || shown('h1');
  return JSON.stringify({ name: name, price: String(price || ''), image: String(image || ''), product: product,
    url: location.href });
})();
''';
