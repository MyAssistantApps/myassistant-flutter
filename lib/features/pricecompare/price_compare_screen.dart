import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../ai/assistant_role.dart';
import '../../design/motion.dart';
import '../../design/neon_tokens.dart';
import '../../services/app_feedback.dart';
import '../../widgets/role_mic_orb.dart';
import 'flight_search_screen.dart';
import 'hotel_search_screen.dart';
import 'price_models.dart';
import 'price_result_screen.dart';
import 'product_snap_search.dart';
import 'price_service.dart';
import 'price_widgets.dart';
import 'product_screens.dart';
import 'shop_browser.dart';

/// THE PRICE COMPARE MIC (2026-11-24): the page's own assistant, like the
/// Jyotish and Documents pages — finds current prices by voice.
const priceCompareRole = AssistantRole(
  'the Price Compare Assistant',
  'You help shoppers in India compare prices before they pay, on the Price '
      'Compare screen. Ask which product they want (brand, model and variant), '
      'then use web_search for its CURRENT price on the big Indian stores '
      '(Amazon, Flipkart, Croma, Reliance Digital and the brand store). Say '
      'the lowest price and the store first, then two or three others. Speak '
      'only of prices you found today — never invent a price, a coupon or a '
      'discount. Reply in the language they speak.',
  tools: ['web_search'],
);

const priceMicNote = "[SYSTEM] I tapped the mic on the Price Compare screen. "
    "Greet me in one short sentence and ask which product I want to compare.";

/// ─────────────────────────────────────────────────────────────────────────
///  PRICE COMPARE, REDESIGNED (2026-11-24, Manish: "completely redesign the
///  price comparison page"). One lit card on top: the title, the search,
///  and three ways in — a photo, the voice, a copied link — then popular
///  searches, the stores it checks (each opens in the app), your price
///  alerts and what you compared lately. A product search opens
///  ProductSearchScreen; a link opens its product page at once.
/// ─────────────────────────────────────────────────────────────────────────
class PriceCompareScreen extends StatefulWidget {
  const PriceCompareScreen({
    super.key,
    this.category = PriceCategory.shopping,
    this.focus = false,
    this.paste = false,
    this.camera = false,
    this.voice = false,
  });
  final PriceCategory category;

  /// Open with the keyboard up (Home's search box).
  final bool focus;

  /// Open by comparing the link on the clipboard (Home's paste button).
  final bool paste;

  /// Open by searching from a photo (Home's camera button).
  final bool camera;

  /// Open by searching from what is said (Home's microphone button).
  final bool voice;

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
    } else if (widget.camera || widget.voice) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _snap(voice: widget.voice));
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
        if (mounted) AppFeedback.show('Copy a product link from Amazon or Flipkart first.', context: context);
        return;
      }
      _query.text = t;
      _go();
    } catch (_) {}
  }

  /// SEARCH BY CAMERA OR VOICE: the product found becomes the search.
  Future<void> _snap({required bool voice}) async {
    final q = voice ? await ProductSnapSearch.byVoice(context) : await ProductSnapSearch.byPhoto(context);
    if (!mounted) return;
    if (q == null) {
      _focus.requestFocus();
      return;
    }
    _query.text = q;
    _go();
  }

  void _flights() {
    FocusScope.of(context).unfocus();
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FlightSearchScreen()));
  }

  /// Hotels have their own page (owner, 2026-11-09); what was typed here
  /// goes along as the place.
  void _hotels() {
    final place = _query.text.trim();
    FocusScope.of(context).unfocus();
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => HotelSearchScreen(place: place)));
  }

  void _go([String? query, PriceCategory? cat]) {
    if (query == null && _cat == PriceCategory.flights) return _flights();
    if (query == null && _cat == PriceCategory.hotels) return _hotels();
    final q = (query ?? _query.text).trim();
    if (q.isEmpty) {
      _focus.requestFocus();
      return;
    }
    FocusScope.of(context).unfocus();
    HapticFeedback.mediumImpact();
    final budget = double.tryParse(_budget.text.replaceAll(RegExp(r'[^\d.]'), ''));
    final c = cat ?? _cat;
    // Products: a results list to pick from (a pasted link goes straight
    // to its product page); the rest compare at once.
    final link = q.startsWith('http://') || q.startsWith('https://');
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => c == PriceCategory.shopping && budget == null
          ? (link ? ProductDetailScreen(query: q) : ProductSearchScreen(query: q))
          : PriceResultScreen(category: c, query: q, budget: budget),
    ));
  }

  Future<void> _askBudget() async {
    final c = TextEditingController(text: _budget.text);
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Your Budget'),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(prefixText: '₹ ', hintText: 'Factored into the AI recommendation'),
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

  // ── the page ─────────────────────────────────────────────────────────

  /// What was searched lately, newest first, for the chips.
  List<String> get _recentQueries {
    final seen = <String>{};
    return [
      for (final r in svc.recent)
        if (!r.query.startsWith('http') && seen.add(r.query.toLowerCase())) r.query,
    ].take(6).toList();
  }

  String get _examplesText => _cat.example.replaceFirst(RegExp(r'^e\.g\.\s*'), '');

  @override
  Widget build(BuildContext context) {
    final recentQ = _recentQueries;
    final examples = _examplesText.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).take(3);
    var i = 0;
    Widget reveal(Widget w) => Reveal(delayMs: 50 * i++, child: w);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (Neon.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
          .copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: Neon.bg,
        body: SafeArea(
          bottom: false,
          child: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: ListView(
              padding: EdgeInsets.fromLTRB(16, 10, 16, 32 + MediaQuery.paddingOf(context).bottom),
              children: [
                // The search: back, the field, the camera and the mic.
                PriceSearchPill(
                  controller: _query,
                  focus: _focus,
                  onSubmit: _go,
                  hint: 'Search or paste a link',
                  trailing: [
                    // Allen's search by photo (camera or gallery), 2026-11-24.
                    IconButton(
                      tooltip: 'Compare a product from a photo',
                      onPressed: () => _snap(voice: false),
                      icon: Icon(Icons.photo_camera_outlined, color: Neon.violet, size: 23),
                    ),
                    RoleMicOrb(
                      role: priceCompareRole,
                      tint: Neon.violet,
                      size: 34,
                      showLabel: false,
                      topic: 'prices',
                      openingNote: () => priceMicNote,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Recent searches, then ways in and suggestions.
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    clipBehavior: Clip.none,
                    children: [
                      for (final q in recentQ)
                        PriceChip(icon: Icons.history_rounded, label: q, onTap: () => _go(q, PriceCategory.shopping)),
                      PriceChip(icon: Icons.content_paste_rounded, label: 'Paste Link', onTap: _paste),
                      if (_cat != PriceCategory.flights)
                        PriceChip(
                          icon: Icons.account_balance_wallet_outlined,
                          label: _budget.text.isEmpty ? 'Add Budget' : 'Budget ₹${_budget.text}',
                          on: _budget.text.isNotEmpty,
                          onTap: _askBudget,
                        ),
                      for (final e in examples)
                        if (!recentQ.any((q) => q.toLowerCase() == e.toLowerCase()))
                          PriceChip(icon: Icons.search_rounded, label: e, onTap: () => _go(e, PriceCategory.shopping)),
                    ],
                  ),
                ),
                if (PriceCategory.shown.length > 1) ...[
                  const SizedBox(height: 28),
                  _sectionTitle('Select a Category'),
                  PriceCategoryShowcase(
                    selected: _cat,
                    onTap: (c) {
                      setState(() => _cat = c);
                      if (c == PriceCategory.flights) {
                        _flights();
                      } else if (c == PriceCategory.hotels) {
                        _hotels();
                      } else {
                        _focus.requestFocus();
                      }
                    },
                  ),
                ],
                if (svc.recent.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  reveal(_sectionTitle('Recently Viewed',
                      action: _pillButton('Clear', Icons.delete_outline_rounded, svc.clearRecent))),
                  productGrid(context, rating: svc.recent.take(6).any((r) => r.facts.num('rating') != null), [
                    for (final r in svc.recent.take(6))
                      ProductCard(
                        name: r.product,
                        store: r.lowest?.store ?? '',
                        image: _imageOf(r),
                        price: r.lowest?.price,
                        mrp: r.lowest?.mrp,
                        rating: r.facts.num('rating'),
                        reviews: r.facts.num('reviews'),
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => r.category == PriceCategory.shopping
                              ? ProductDetailScreen(query: r.query, earlier: r)
                              : PriceResultScreen(category: r.category, query: r.query, earlier: r),
                        )),
                      ),
                  ]),
                ],
                if (svc.watches.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  reveal(_sectionTitle('Your Price Alerts')),
                  for (final w in svc.watches)
                    reveal(Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _alertRow(w),
                    )),
                ],
                const SizedBox(height: 28),
                reveal(_sectionTitle('Stores We Compare', sub: 'Tap a store to shop in the app. On any product page, tap Compare.')),
                reveal(_stores()),
                if (svc.recent.isEmpty && svc.watches.isEmpty) ...[
                  const SizedBox(height: 28),
                  reveal(_howItWorks()),
                ],
                const SizedBox(height: 24),
                Text(
                  'Prices are sourced from the web via Google Search and may change at any time — the store '
                  'shows the final price at checkout. Price alerts are checked each time you open Price Compare.',
                  style: TextStyle(color: Neon.textDim, fontSize: NeonType.caption, height: 1.4),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(onPressed: () => showPhotoCredits(context), child: const Text('Photo Credits')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _imageOf(PriceResult r) {
    final i = r.facts.str('image');
    if (i.isNotEmpty) return i;
    for (final o in r.offers) {
      if (o.info.str('image').isNotEmpty) return o.info.str('image');
    }
    return '';
  }

  Widget _pillButton(String label, IconData icon, VoidCallback onTap) => Tappable(
        onTap: onTap,
        semanticLabel: label,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 7, 12, 7),
          decoration: BoxDecoration(
            color: Neon.violet.withValues(alpha: Neon.isDark ? 0.16 : 0.09),
            borderRadius: BorderRadius.circular(Neon.rPill),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(label, style: TextStyle(color: Neon.violet, fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(width: 6),
            Icon(icon, color: Neon.violet, size: 18),
          ]),
        ),
      );

  Widget _sectionTitle(String t, {String? sub, Widget? action}) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 0, 0, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(t,
                        style: NeonType.manrope(21, FontWeight.w800).copyWith(color: Neon.textHi, letterSpacing: -0.4)),
                  ),
                  if (sub != null) ...[
                    const SizedBox(height: 3),
                    Text(sub, style: TextStyle(color: Neon.textLo, fontSize: 13, height: 1.35)),
                  ],
                ],
              ),
            ),
            if (action != null) action,
          ],
        ),
      );

  /// THE STORES THAT RUN IN THE APP: each opens its site in
  /// [ShopBrowserScreen], where a product page brings up Compare.
  Widget _stores() {
    final stores = [
      for (final s in PriceStores.shopping) (s, PriceCategory.shopping),
      for (final s in PriceStores.grocery) (s, PriceCategory.grocery),
    ];
    return SizedBox(
      // Padding 20 + logo 44 + gap 7 + one line of 11.5 pt text, and a
      // little room so the row never clips the tile (it once did by 8 dp).
      height: 76 + MediaQuery.textScalerOf(context).scale(20),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: stores.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final (s, cat) = stores[i];
          final logo = brandLogoFor(store: s);
          return Tappable(
            semanticLabel: 'Open ${s.name} in the app',
            onTap: () => openInShopBrowser(
                context,
                s == PriceStores.instamart ? 'https://www.swiggy.com/instamart' : 'https://www.${s.domains.first}/',
                cat),
            child: Container(
              width: 78,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: Neon.surface,
                borderRadius: BorderRadius.circular(Neon.rMd),
                border: Border.all(color: Neon.hairline),
              ),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: logo == null ? StoreMark(s, size: 44) : Image.asset(logo, width: 44, height: 44, fit: BoxFit.cover),
                  ),
                  const SizedBox(height: 7),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(s.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Neon.textHi, fontSize: 11.5, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _alertRow(PriceWatch w) {
    final tint = w.reached ? Neon.success : Neon.violet;
    return Tappable(
      onTap: () => _go(w.query, w.category),
      scale: 0.985,
      semanticLabel: '${w.product}, alert at ${rupees(w.target)}${w.reached ? ', price reached' : ''}',
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Neon.surface,
          borderRadius: BorderRadius.circular(Neon.rLg),
          border: Border.all(color: Neon.hairline),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: tint.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
              child: Icon(w.reached ? Icons.trending_down_rounded : Icons.notifications_active_outlined, color: tint, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(w.product,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Neon.textHi, fontSize: 14.5, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text('Alert at ${rupees(w.target)}${w.store.isEmpty ? '' : ' · ${w.store}'}',
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Neon.textLo, fontSize: 12.5)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (w.last != null)
                  Text(rupees(w.last!), style: NeonType.manrope(15, FontWeight.w800).copyWith(color: Neon.textHi)),
                if (w.reached)
                  Text('Price reached', style: TextStyle(color: Neon.success, fontSize: 11.5, fontWeight: FontWeight.w700)),
              ],
            ),
            Icon(Icons.chevron_right_rounded, color: Neon.textDim, size: 20),
          ],
        ),
      ),
    );
  }

  /// Shown until there is history of one's own: what the feature does.
  Widget _howItWorks() {
    Widget step(IconData icon, String title, String text, Color c) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: c.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: c, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(color: Neon.textHi, fontSize: 14.5, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(text, style: TextStyle(color: Neon.textLo, fontSize: 13, height: 1.35)),
                  ],
                ),
              ),
            ],
          ),
        );
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 2),
      decoration: BoxDecoration(
        color: Neon.surface,
        borderRadius: BorderRadius.circular(Neon.rCard),
        border: Border.all(color: Neon.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Text('How It Works', style: NeonType.manrope(17, FontWeight.w800).copyWith(color: Neon.textHi)),
          ),
          step(Icons.search_rounded, 'Search, Scan or Paste',
              'Type a product, photograph it with the camera, ask by voice, or paste a link.', Neon.violet),
          step(Icons.compare_arrows_rounded, 'Compare Every Store',
              'See the price at each store side by side, cheapest first.', Neon.cyan),
          step(Icons.notifications_active_outlined, 'Buy or Set an Alert',
              'Buy at the lowest price, or be told when it drops to your target.', Neon.success),
        ],
      ),
    );
  }
}
