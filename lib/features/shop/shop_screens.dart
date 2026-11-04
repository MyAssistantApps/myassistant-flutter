import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../design/apple_kit.dart';
import '../../design/motion.dart';
import '../../design/neon_tokens.dart';
import '../../design/neon_widgets.dart';
import 'shop_api.dart';

/// ─────────────────────────────────────────────────────────────────────────
///  ORDER INSIDE THE APP (owner, 2026-11-04: "place the order in our app
///  itself via API instead of opening the other app"). Groceries and Food
///  over ONDC: home → stores & items → cart → quote → address → pay →
///  order → tracking, and My orders. Until ONDC is connected the home says
///  "launching soon" — never a fake store, item or price.
/// ─────────────────────────────────────────────────────────────────────────
extension ShopDomainText on ShopDomain {
  String get title => this == ShopDomain.grocery ? 'Groceries' : 'Food';
  String get headline =>
      this == ShopDomain.grocery ? 'Fresh to your door' : 'Hungry? Order in';
  String get hint => this == ShopDomain.grocery
      ? 'Search milk, atta, vegetables…'
      : 'Search biryani, pizza, dosa…';
  String get photo => this == ShopDomain.grocery
      ? 'assets/quick/groceries.jpg'
      : 'assets/quick/food.jpg';
  List<(IconData, String)> get categories => this == ShopDomain.grocery
      ? const [
          (Icons.eco_rounded, 'Vegetables'),
          (Icons.apple_rounded, 'Fruits'),
          (Icons.egg_rounded, 'Dairy & eggs'),
          (Icons.bakery_dining_rounded, 'Bakery'),
          (Icons.rice_bowl_rounded, 'Atta, rice & dal'),
          (Icons.cookie_rounded, 'Snacks'),
          (Icons.local_drink_rounded, 'Beverages'),
          (Icons.spa_rounded, 'Personal care'),
          (Icons.cleaning_services_rounded, 'Household'),
        ]
      : const [
          (Icons.rice_bowl_rounded, 'Biryani'),
          (Icons.local_pizza_rounded, 'Pizza'),
          (Icons.breakfast_dining_rounded, 'South Indian'),
          (Icons.dinner_dining_rounded, 'North Indian'),
          (Icons.ramen_dining_rounded, 'Chinese'),
          (Icons.lunch_dining_rounded, 'Burgers'),
          (Icons.icecream_rounded, 'Desserts'),
          (Icons.local_cafe_rounded, 'Beverages'),
          (Icons.eco_rounded, 'Healthy'),
        ];
}

Widget _primaryButton(String label, IconData icon, VoidCallback? onTap,
        {bool busy = false}) =>
    Opacity(
      opacity: onTap == null && !busy ? 0.5 : 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(colors: [
            Color.lerp(Neon.accentFill, Colors.white, 0.12)!,
            Neon.accentFill,
          ]),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: busy ? null : onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (busy)
                    const NeonLoader.inline(size: 18, semanticLabel: 'Working')
                  else
                    Icon(icon, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(label,
                        overflow: TextOverflow.ellipsis,
                        style: NeonType.manrope(16, FontWeight.w800)
                            .copyWith(color: Colors.white)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

void _snack(BuildContext context, String m) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

/* ------------------------------------------------------------------ */
/* HOME                                                                */
/* ------------------------------------------------------------------ */

class ShopHomeScreen extends StatefulWidget {
  const ShopHomeScreen({super.key, required this.domain});
  final ShopDomain domain;

  @override
  State<ShopHomeScreen> createState() => _ShopHomeScreenState();
}

class _ShopHomeScreenState extends State<ShopHomeScreen> {
  final _q = TextEditingController();
  bool? _live;

  @override
  void initState() {
    super.initState();
    ShopApi.status().then((s) {
      if (mounted) setState(() => _live = s.configured);
    });
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  void _search(String q) {
    FocusScope.of(context).unfocus();
    if (_live != true) {
      _snack(context, 'In-app ordering is launching soon.');
      return;
    }
    Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => ShopResultsScreen(domain: widget.domain, query: q)));
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.domain;
    return NeonScaffold(
      appBar: appleAppBar(context, d.title),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: ListView(
          padding: EdgeInsets.fromLTRB(
              16, 8, 16, 28 + MediaQuery.paddingOf(context).bottom),
          children: [
            _hero(d),
            const SizedBox(height: 16),
            if (_live == false) ...[_launching(), const SizedBox(height: 16)],
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 10),
              child: Text('SHOP BY CATEGORY',
                  style: NeonType.eyebrow.copyWith(color: Neon.textLo)),
            ),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.05,
              children: [
                for (final (icon, name) in d.categories)
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(Neon.rLg),
                      onTap: () => _search(name),
                      child: Ink(
                        decoration: Neon.glassBox(Neon.rLg),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Neon.violet.withValues(alpha: 0.16),
                              ),
                              child: Icon(icon, color: Neon.violet),
                            ),
                            const SizedBox(height: 8),
                            Text(name,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                style: TextStyle(
                                    color: Neon.textHi,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(Neon.rCard),
                onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => const ShopOrdersScreen())),
                child: Ink(
                  padding: const EdgeInsets.all(16),
                  decoration: Neon.glassBox(Neon.rCard),
                  child: Row(
                    children: [
                      Icon(Icons.receipt_long_rounded, color: Neon.violet),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text('My orders',
                            style: NeonType.manrope(16, FontWeight.w800)
                                .copyWith(color: Neon.textHi)),
                      ),
                      Icon(Icons.chevron_right_rounded, color: Neon.textDim),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hero(ShopDomain d) => ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: SizedBox(
          height: 220,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(d.photo, fit: BoxFit.cover),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0, 0.45, 1],
                    colors: [
                      Colors.black.withValues(alpha: 0.1),
                      Colors.black.withValues(alpha: 0.25),
                      Colors.black.withValues(alpha: 0.85),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d.headline,
                        style: NeonType.manrope(28, FontWeight.w800).copyWith(
                            color: Colors.white, letterSpacing: -0.6)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.near_me_rounded,
                            size: 14, color: Colors.white70),
                        const SizedBox(width: 4),
                        Text('Stores near your location',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // A WHITE PILL (owner, 2026-11-04: the theme's dark,
                    // outlined field clashed with the photo). Every part of
                    // the decoration is set here so the app theme cannot
                    // repaint it.
                    Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(26),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 16,
                              offset: const Offset(0, 6)),
                        ],
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 16),
                          const Icon(Icons.search_rounded,
                              color: Colors.black54, size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _q,
                              textInputAction: TextInputAction.search,
                              onSubmitted: (v) =>
                                  v.trim().isEmpty ? null : _search(v),
                              cursorColor: Neon.accentFill,
                              style: const TextStyle(
                                  color: Color(0xFF14121C),
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w600),
                              decoration: InputDecoration(
                                isCollapsed: true,
                                hintText: d.hint,
                                hintStyle: const TextStyle(
                                    color: Color(0xFF8A8796),
                                    fontWeight: FontWeight.w500),
                                filled: false,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                disabledBorder: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(5),
                            child: Material(
                              color: Neon.accentFill,
                              shape: const CircleBorder(),
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: () => _q.text.trim().isEmpty
                                    ? null
                                    : _search(_q.text),
                                child: const SizedBox(
                                  width: 42,
                                  height: 42,
                                  child: Icon(Icons.arrow_forward_rounded,
                                      color: Colors.white, size: 20),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  Widget _launching() => Container(
        padding: const EdgeInsets.all(16),
        decoration: Neon.glassBox(Neon.rCard).copyWith(
            border: Border.all(color: Neon.violet.withValues(alpha: 0.45))),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.rocket_launch_rounded, color: Neon.violet),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('In-app ordering is launching soon',
                      style: NeonType.manrope(15.5, FontWeight.w800)
                          .copyWith(color: Neon.textHi)),
                  const SizedBox(height: 4),
                  Text(
                      "We're connecting to ONDC, India's open shopping "
                      'network, so you can order from stores near you and '
                      'pay right here.',
                      style: TextStyle(
                          color: Neon.textLo, fontSize: 13, height: 1.4)),
                ],
              ),
            ),
          ],
        ),
      );
}

/* ------------------------------------------------------------------ */
/* STORES & ITEMS                                                      */
/* ------------------------------------------------------------------ */

class ShopResultsScreen extends StatefulWidget {
  const ShopResultsScreen(
      {super.key, required this.domain, required this.query});
  final ShopDomain domain;
  final String query;

  @override
  State<ShopResultsScreen> createState() => _ShopResultsScreenState();
}

class _ShopResultsScreenState extends State<ShopResultsScreen> {
  final _cart = ShopCart();
  String? _txn;
  List<ShopStore> _stores = const [];
  bool _searching = true;
  String _error = '';
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    try {
      _txn = await ShopApi.search(widget.domain, widget.query);
      // Stores answer one by one: keep reading for ~20 s.
      var n = 0;
      _poll = Timer.periodic(const Duration(milliseconds: 1500), (t) async {
        n++;
        try {
          final s = await ShopApi.results(_txn!);
          if (mounted) setState(() => _stores = s);
        } catch (_) {}
        if (n >= 14) {
          t.cancel();
          if (mounted) setState(() => _searching = false);
        }
      });
    } on ShopError catch (e) {
      setState(() {
        _searching = false;
        _error = e.message;
      });
    } catch (_) {
      setState(() {
        _searching = false;
        _error = "Couldn't reach the server.";
      });
    }
  }

  Future<void> _add(ShopStore s, ShopItem i) async {
    if (_cart.store != null && _cart.store!.key != s.key) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Start a new cart?'),
          content: Text(
              'Your cart has items from ${_cart.store!.name}. One order is '
              'from one store.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Keep')),
            TextButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('New cart')),
          ],
        ),
      );
      if (ok != true) return;
    }
    HapticFeedback.selectionClick();
    setState(() => _cart.add(s, i));
  }

  @override
  Widget build(BuildContext context) {
    return NeonScaffold(
      appBar: appleAppBar(context, widget.query),
      body: Stack(
        children: [
          _body(),
          if (!_cart.isEmpty)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16 + MediaQuery.paddingOf(context).bottom,
              child: _primaryButton(
                  '${_cart.count} item${_cart.count == 1 ? '' : 's'} · '
                  '${rupees(_cart.total)} · View cart',
                  Icons.shopping_bag_rounded, () async {
                await Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => ShopCheckoutScreen(
                        domain: widget.domain, txn: _txn!, cart: _cart)));
                if (mounted) setState(() {});
              }),
            ),
        ],
      ),
    );
  }

  Widget _body() {
    if (_error.isNotEmpty) {
      return _center(Icons.error_outline_rounded, "Couldn't search", _error);
    }
    if (_stores.isEmpty) {
      return _searching
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const NeonLoader.inline(
                      size: 28, semanticLabel: 'Finding stores'),
                  const SizedBox(height: 12),
                  Text('Finding stores near you…',
                      style: TextStyle(color: Neon.textLo)),
                ],
              ),
            )
          : _center(Icons.storefront_rounded, 'No stores found',
              'Try another search, or check back soon.');
    }
    return ListView(
      padding: EdgeInsets.fromLTRB(
          16, 8, 16, 96 + MediaQuery.paddingOf(context).bottom),
      children: [
        if (_searching)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(children: [
              const NeonLoader.inline(size: 14, semanticLabel: 'More'),
              const SizedBox(width: 8),
              Text('More stores are answering…',
                  style: TextStyle(color: Neon.textDim, fontSize: 12.5)),
            ]),
          ),
        for (final s in _stores) ...[
          Reveal(child: _store(s)),
          const SizedBox(height: 14),
        ],
      ],
    );
  }

  Widget _store(ShopStore s) => Container(
        decoration: Neon.glassBox(Neon.rCard),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 44,
                    height: 44,
                    color: Neon.violet.withValues(alpha: 0.14),
                    child: s.image == null
                        ? Icon(Icons.storefront_rounded, color: Neon.violet)
                        : Image.network(s.image!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Icon(
                                Icons.storefront_rounded,
                                color: Neon.violet)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.name,
                          style: NeonType.manrope(16, FontWeight.w800)
                              .copyWith(color: Neon.textHi)),
                      Text(
                          [s.locality, if (s.sellerApp != null) s.sellerApp!]
                              .where((x) => x.isNotEmpty)
                              .join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              TextStyle(color: Neon.textDim, fontSize: 12.5)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            for (final i in s.items.take(12)) _item(s, i),
          ],
        ),
      );

  Widget _item(ShopStore s, ShopItem i) {
    final q = _cart.store?.key == s.key ? _cart.qty(i) : 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 56,
              height: 56,
              color: Colors.white,
              child: i.image == null
                  ? Icon(Icons.shopping_basket_rounded,
                      color: Neon.textDim)
                  : Image.network(i.image!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(
                          Icons.shopping_basket_rounded,
                          color: Neon.textDim)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(i.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: Neon.textHi,
                        fontWeight: FontWeight.w700,
                        fontSize: 14)),
                if (i.unit.isNotEmpty)
                  Text(i.unit,
                      style: TextStyle(color: Neon.textDim, fontSize: 12)),
                Row(children: [
                  Text(rupees(i.price),
                      style: NeonType.manrope(14.5, FontWeight.w800)
                          .copyWith(color: Neon.textHi)),
                  if (i.mrp != null && i.mrp! > i.price) ...[
                    const SizedBox(width: 6),
                    Text(rupees(i.mrp!),
                        style: TextStyle(
                            color: Neon.textDim,
                            fontSize: 12,
                            decoration: TextDecoration.lineThrough)),
                  ],
                ]),
              ],
            ),
          ),
          if (i.outOfStock)
            Text('Out of stock',
                style: TextStyle(color: Neon.textDim, fontSize: 12))
          else if (q == 0)
            OutlinedButton(
              onPressed: () => _add(s, i),
              style: OutlinedButton.styleFrom(
                  foregroundColor: Neon.violet,
                  side: BorderSide(color: Neon.violet)),
              child: const Text('ADD'),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: Neon.accentFill,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.remove_rounded,
                        color: Colors.white, size: 18),
                    onPressed: () => setState(() => _cart.remove(i)),
                  ),
                  Text('$q',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w800)),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.add_rounded,
                        color: Colors.white, size: 18),
                    onPressed: () => _add(s, i),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

Widget _center(IconData icon, String title, String body) => Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Neon.violet),
            const SizedBox(height: 12),
            Text(title,
                textAlign: TextAlign.center,
                style: NeonType.manrope(18, FontWeight.w800)
                    .copyWith(color: Neon.textHi)),
            const SizedBox(height: 6),
            Text(body,
                textAlign: TextAlign.center,
                style: TextStyle(color: Neon.textLo, height: 1.4)),
          ],
        ),
      ),
    );

/* ------------------------------------------------------------------ */
/* CHECKOUT: quote → address → pay → order                              */
/* ------------------------------------------------------------------ */

class ShopCheckoutScreen extends StatefulWidget {
  const ShopCheckoutScreen(
      {super.key, required this.domain, required this.txn, required this.cart});
  final ShopDomain domain;
  final String txn;
  final ShopCart cart;

  @override
  State<ShopCheckoutScreen> createState() => _ShopCheckoutScreenState();
}

class _ShopCheckoutScreenState extends State<ShopCheckoutScreen>
    with WidgetsBindingObserver {
  ShopQuote? _quote;
  bool _quoting = true;
  bool _working = false;
  String _step = '';
  int? _orderId;
  final _f = <String, TextEditingController>{
    for (final k in [
      'name', 'phone', 'building', 'locality', 'city', 'state', 'areaCode'
    ])
      k: TextEditingController(),
  };
  final _form = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _getQuote();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final c in _f.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// Back from Razorpay's page: has it been paid?
  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed && _orderId != null && !_working) {
      _confirm();
    }
  }

  Future<void> _getQuote() async {
    setState(() {
      _quoting = true;
      _quote = null;
    });
    try {
      await ShopApi.select(widget.domain, widget.txn, widget.cart);
      final q = await ShopApi.poll(() => ShopApi.quote(widget.txn));
      if (mounted) setState(() => _quote = q);
    } on ShopError catch (e) {
      if (mounted) _snack(context, e.message);
    } catch (_) {}
    if (mounted) setState(() => _quoting = false);
  }

  Future<void> _payNow() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _working = true;
      _step = 'Confirming with the store…';
    });
    try {
      final address = {
        'name': _f['name']!.text.trim(),
        'phone': _f['phone']!.text.trim(),
        'building': _f['building']!.text.trim(),
        'locality': _f['locality']!.text.trim(),
        'city': _f['city']!.text.trim(),
        'state': _f['state']!.text.trim(),
        'areaCode': _f['areaCode']!.text.trim(),
      };
      await ShopApi.init(widget.domain, widget.txn, widget.cart, address,
          _quote?.fulfillmentId);
      final r = await ShopApi.poll(() => ShopApi.initResult(widget.txn));
      if (r == null || r.error != null || r.total == null) {
        throw ShopError(r?.error ?? 'The store did not confirm. Try again.');
      }
      setState(() => _step = 'Opening secure payment…');
      final p = await ShopApi.pay(widget.txn);
      _orderId = p.orderId;
      final ok = await launchUrl(Uri.parse(p.url),
          mode: LaunchMode.externalApplication);
      if (!ok) throw ShopError("Couldn't open the payment page.");
      setState(() => _step = 'Waiting for payment…');
    } on ShopError catch (e) {
      if (mounted) {
        _snack(context, e.message);
        setState(() => _working = false);
      }
      return;
    } catch (_) {
      if (mounted) {
        _snack(context, 'Something went wrong. Try again.');
        setState(() => _working = false);
      }
      return;
    }
    if (mounted) setState(() => _working = false);
  }

  Future<void> _confirm() async {
    final id = _orderId;
    if (id == null) return;
    setState(() {
      _working = true;
      _step = 'Checking payment…';
    });
    try {
      final r = await ShopApi.poll(() => ShopApi.confirm(id),
          done: (v) => v.paid, within: const Duration(seconds: 12));
      if (!mounted) return;
      if (r != null && r.paid) {
        widget.cart.clear();
        Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute<void>(
                builder: (_) => ShopOrderScreen(orderId: id, justPlaced: true)),
            (route) => route.isFirst);
        return;
      }
      _snack(context, 'Payment not received yet. Finish paying, then come back.');
    } on ShopError catch (e) {
      if (mounted) _snack(context, e.message);
    } catch (_) {}
    if (mounted) setState(() => _working = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.cart;
    final q = _quote;
    return NeonScaffold(
      appBar: appleAppBar(context, 'Checkout'),
      body: Form(
        key: _form,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
              16, 8, 16, 28 + MediaQuery.paddingOf(context).bottom),
          children: [
            Text(c.store?.name ?? '',
                style: NeonType.manrope(20, FontWeight.w800)
                    .copyWith(color: Neon.textHi)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: Neon.glassBox(Neon.rCard),
              child: Column(
                children: [
                  for (final l in c.lines.values)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(children: [
                        Expanded(
                          child: Text('${l.quantity} × ${l.item.name}',
                              style: TextStyle(color: Neon.textHi)),
                        ),
                        Text(rupees(l.item.price * l.quantity),
                            style: TextStyle(color: Neon.textHi)),
                      ]),
                    ),
                  Divider(color: Neon.hairline),
                  if (_quoting)
                    Row(children: [
                      const NeonLoader.inline(
                          size: 14, semanticLabel: 'Getting the bill'),
                      const SizedBox(width: 8),
                      Text('Getting the final bill from the store…',
                          style: TextStyle(color: Neon.textLo)),
                    ])
                  else if (q == null)
                    Row(children: [
                      Expanded(
                        child: Text("The store didn't answer.",
                            style: TextStyle(color: Neon.textLo)),
                      ),
                      TextButton(
                          onPressed: _getQuote, child: const Text('Retry')),
                    ])
                  else ...[
                    for (final l in q.lines.where((l) => l.type != 'item'))
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(children: [
                          Expanded(
                              child: Text(l.title,
                                  style: TextStyle(
                                      color: Neon.textLo, fontSize: 13))),
                          Text(rupees(l.price),
                              style: TextStyle(
                                  color: Neon.textLo, fontSize: 13)),
                        ]),
                      ),
                    const SizedBox(height: 4),
                    Row(children: [
                      Expanded(
                        child: Text('Total',
                            style: NeonType.manrope(16, FontWeight.w800)
                                .copyWith(color: Neon.textHi)),
                      ),
                      Text(rupees(q.total ?? c.total),
                          style: NeonType.manrope(18, FontWeight.w800)
                              .copyWith(color: Neon.textHi)),
                    ]),
                    if (q.deliveryTime != null)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Delivery in ${_tat(q.deliveryTime!)}',
                            style: TextStyle(
                                color: Neon.success, fontSize: 12.5)),
                      ),
                    if (!q.serviceable || q.error != null)
                      Text(q.error ?? "The store doesn't deliver here.",
                          style: TextStyle(color: Neon.error, fontSize: 12.5)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text('DELIVERY ADDRESS',
                  style: NeonType.eyebrow.copyWith(color: Neon.textLo)),
            ),
            _field('name', 'Full name'),
            _field('phone', 'Phone number',
                keyboard: TextInputType.phone,
                check: (v) => RegExp(r'^\d{10}$').hasMatch(v)
                    ? null
                    : 'Enter a 10-digit number'),
            _field('building', 'House / flat / building'),
            _field('locality', 'Street & area'),
            Row(children: [
              Expanded(child: _field('city', 'City')),
              const SizedBox(width: 10),
              Expanded(
                  child: _field('areaCode', 'Pincode',
                      keyboard: TextInputType.number,
                      check: (v) => RegExp(r'^\d{6}$').hasMatch(v)
                          ? null
                          : '6 digits')),
            ]),
            _field('state', 'State'),
            const SizedBox(height: 14),
            if (_working || _step.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(_step,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Neon.textLo)),
              ),
            _primaryButton(
                _orderId != null
                    ? "I've paid — place my order"
                    : q?.total != null
                        ? 'Pay ${rupees(q!.total!)}'
                        : 'Pay',
                Icons.lock_rounded,
                _orderId != null
                    ? _confirm
                    : (q != null && q.serviceable && q.error == null)
                        ? _payNow
                        : null,
                busy: _working),
            const SizedBox(height: 8),
            Text('Secure payment by Razorpay. Your order is placed with the '
                'store only after the payment is confirmed.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Neon.textDim, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _field(String key, String label,
          {TextInputType? keyboard, String? Function(String v)? check}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextFormField(
          controller: _f[key],
          keyboardType: keyboard,
          style: TextStyle(color: Neon.textHi),
          validator: (v) {
            final t = (v ?? '').trim();
            if (t.isEmpty) return 'Required';
            return check?.call(t);
          },
          decoration: InputDecoration(
            labelText: label,
            filled: true,
            fillColor: Neon.glassFill.colors.first,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none),
          ),
        ),
      );
}

/// "PT45M" → "45 min", "PT1H30M" → "1 h 30 min".
String _tat(String iso) {
  final m = RegExp(r'PT(?:(\d+)H)?(?:(\d+)M)?').firstMatch(iso);
  if (m == null) return iso;
  final h = int.tryParse(m.group(1) ?? '') ?? 0;
  final mi = int.tryParse(m.group(2) ?? '') ?? 0;
  return [if (h > 0) '$h h', if (mi > 0) '$mi min'].join(' ');
}

/* ------------------------------------------------------------------ */
/* ORDERS                                                              */
/* ------------------------------------------------------------------ */

class ShopOrdersScreen extends StatefulWidget {
  const ShopOrdersScreen({super.key});

  @override
  State<ShopOrdersScreen> createState() => _ShopOrdersScreenState();
}

class _ShopOrdersScreenState extends State<ShopOrdersScreen> {
  List<ShopOrder>? _orders;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final o = await ShopApi.orders();
      if (mounted) setState(() => _orders = o);
    } on ShopError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = "Couldn't load your orders.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = _orders;
    return NeonScaffold(
      appBar: appleAppBar(context, 'My orders'),
      body: _error.isNotEmpty
          ? _center(Icons.receipt_long_rounded, 'No orders yet',
              _error.contains('not connected')
                  ? 'In-app ordering is launching soon.'
                  : _error)
          : o == null
              ? const Center(
                  child: NeonLoader.inline(size: 28, semanticLabel: 'Loading'))
              : o.isEmpty
                  ? _center(Icons.receipt_long_rounded, 'No orders yet',
                      'Your grocery and food orders will show here.')
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: o.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(Neon.rCard),
                            onTap: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                    builder: (_) =>
                                        ShopOrderScreen(orderId: o[i].id))),
                            child: Ink(
                              padding: const EdgeInsets.all(14),
                              decoration: Neon.glassBox(Neon.rCard),
                              child: Row(
                                children: [
                                  Icon(
                                      o[i].domain.endsWith('11')
                                          ? Icons.restaurant_rounded
                                          : Icons.shopping_basket_rounded,
                                      color: Neon.violet),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(o[i].store,
                                            style: TextStyle(
                                                color: Neon.textHi,
                                                fontWeight: FontWeight.w700)),
                                        Text(o[i].label,
                                            style: TextStyle(
                                                color: Neon.textLo,
                                                fontSize: 12.5)),
                                      ],
                                    ),
                                  ),
                                  if (o[i].total != null)
                                    Text(rupees(o[i].total!),
                                        style: NeonType.manrope(
                                                15, FontWeight.w800)
                                            .copyWith(color: Neon.textHi)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
    );
  }
}

class ShopOrderScreen extends StatefulWidget {
  const ShopOrderScreen(
      {super.key, required this.orderId, this.justPlaced = false});
  final int orderId;
  final bool justPlaced;

  @override
  State<ShopOrderScreen> createState() => _ShopOrderScreenState();
}

class _ShopOrderScreenState extends State<ShopOrderScreen> {
  ShopOrder? _o;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _load(refresh: false);
    // While the order is live, ask the store every 30 s.
    _tick = Timer.periodic(const Duration(seconds: 30), (_) => _load());
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _load({bool refresh = true}) async {
    try {
      final o = await ShopApi.order(widget.orderId, refresh: refresh);
      if (mounted) setState(() => _o = o);
    } catch (_) {}
  }

  Future<void> _cancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Cancel this order?'),
        content: const Text(
            'The store decides whether it can still be cancelled. Any '
            'refund follows the store\'s policy.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Keep order')),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Cancel order')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ShopApi.cancel(widget.orderId);
      await _load();
    } on ShopError catch (e) {
      if (mounted) _snack(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = _o;
    return NeonScaffold(
      appBar: appleAppBar(context, 'Order'),
      body: o == null
          ? const Center(
              child: NeonLoader.inline(size: 28, semanticLabel: 'Loading'))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (widget.justPlaced)
                    Container(
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: Neon.glassBox(Neon.rCard).copyWith(
                          border: Border.all(
                              color: Neon.success.withValues(alpha: 0.5))),
                      child: Row(children: [
                        Icon(Icons.check_circle_rounded,
                            color: Neon.success, size: 32),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text('Order placed! The store is on it.',
                              style: NeonType.manrope(16, FontWeight.w800)
                                  .copyWith(color: Neon.textHi)),
                        ),
                      ]),
                    ),
                  Text(o.store,
                      style: NeonType.manrope(22, FontWeight.w800)
                          .copyWith(color: Neon.textHi)),
                  const SizedBox(height: 4),
                  Text(o.label,
                      style: TextStyle(
                          color: Neon.violet, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: Neon.glassBox(Neon.rCard),
                    child: Column(children: [
                      for (final l in o.items)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(children: [
                            Expanded(
                                child: Text('${l.quantity} × ${l.name}',
                                    style: TextStyle(color: Neon.textHi))),
                            Text(rupees(l.price),
                                style: TextStyle(color: Neon.textHi)),
                          ]),
                        ),
                      if (o.total != null) ...[
                        Divider(color: Neon.hairline),
                        Row(children: [
                          Expanded(
                              child: Text(o.paid ? 'Paid' : 'Total',
                                  style: TextStyle(
                                      color: Neon.textHi,
                                      fontWeight: FontWeight.w800))),
                          Text(rupees(o.total!),
                              style: NeonType.manrope(17, FontWeight.w800)
                                  .copyWith(color: Neon.textHi)),
                        ]),
                      ],
                    ]),
                  ),
                  if (o.agentName != null || o.agentPhone != null) ...[
                    const SizedBox(height: 12),
                    ListTile(
                      tileColor: Neon.glassFill.colors.first,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(Neon.rLg)),
                      leading: Icon(Icons.delivery_dining_rounded,
                          color: Neon.violet),
                      title: Text(o.agentName ?? 'Delivery partner',
                          style: TextStyle(color: Neon.textHi)),
                      subtitle: o.agentPhone == null
                          ? null
                          : Text(o.agentPhone!,
                              style: TextStyle(color: Neon.textLo)),
                      trailing: o.agentPhone == null
                          ? null
                          : IconButton(
                              icon: Icon(Icons.call_rounded,
                                  color: Neon.violet),
                              onPressed: () =>
                                  launchUrl(Uri.parse('tel:${o.agentPhone}')),
                            ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (o.trackingUrl != null)
                    _primaryButton('Track delivery', Icons.map_rounded, () {
                      launchUrl(Uri.parse(o.trackingUrl!),
                          mode: LaunchMode.externalApplication);
                    }),
                  if (o.paymentUrl != null) ...[
                    const SizedBox(height: 10),
                    _primaryButton('Finish payment', Icons.lock_rounded, () {
                      launchUrl(Uri.parse(o.paymentUrl!),
                          mode: LaunchMode.externalApplication);
                    }),
                  ],
                  if (!{'cancelled', 'cancelling', 'completed'}
                          .contains(o.state.toLowerCase()) &&
                      o.paid) ...[
                    const SizedBox(height: 10),
                    TextButton(
                        onPressed: _cancel,
                        child: Text('Cancel order',
                            style: TextStyle(color: Neon.errorInk))),
                  ],
                ],
              ),
            ),
    );
  }
}
