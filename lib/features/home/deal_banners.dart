import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:simple_icons/simple_icons.dart';

import '../../design/neon_tokens.dart';
import '../../core/log.dart';
import '../pricecompare/shop_browser.dart';

/// ORDER AND SHOP, SLIDING (owner, 2026-11-01: "before Open a tool we need
/// Swiggy and other similar platforms or e-commerce platforms and their
/// offers and suggestions for users, sliding banner card").
///
/// HONEST BY DESIGN: there is no offers feed from these platforms, so no
/// banner invents a discount. Each one is a real suggestion — the meal
/// time, the user's own shopping list — and opens the real app, or the
/// platform's own offers page where its deals actually are.
class DealBanner {
  const DealBanner({
    required this.brand,
    required this.title,
    required this.body,
    required this.action,
    required this.color,
    required this.icon,
    this.pkg = '',
    this.url = '',
    this.iconPkg = '',
    this.mark,
  });

  final String brand;
  final String title;
  final String body;
  final String action;
  final Color color;
  final IconData icon;

  /// Opened when installed; otherwise [url].
  final String pkg;
  final String url;

  /// Whose installed icon to show (defaults to [pkg]): Amazon's and
  /// Flipkart's banners open their offers pages but show their app's logo.
  final String iconPkg;

  /// The brand's mark when the app is not installed (simple_icons has
  /// Swiggy and Zomato).
  final IconData? mark;

  String get logoPkg => iconPkg.isNotEmpty ? iconPkg : pkg;
}

/// The banners for [now], with the user's shopping list in mind.
List<DealBanner> dealBannersFor(DateTime now, {List<String> toBuy = const []}) {
  final h = now.hour;
  final meal = h >= 6 && h < 11
      ? 'Breakfast'
      : h >= 11 && h < 16
          ? 'Lunch'
          : h >= 16 && h < 19
              ? 'Snacks'
              : 'Dinner';
  final food = [
    DealBanner(
      brand: 'Swiggy',
      title: '$meal time',
      body: 'See what restaurants near you are serving, and today\'s offers.',
      action: 'Open Swiggy',
      color: const Color(0xFFFC8019),
      icon: Icons.delivery_dining_rounded,
      pkg: 'in.swiggy.android',
      url: 'https://www.swiggy.com/',
      mark: SimpleIcons.swiggy,
    ),
    const DealBanner(
      brand: 'Zomato',
      title: 'Something different?',
      body: 'Browse restaurants and their deals on Zomato.',
      action: 'Open Zomato',
      color: Color(0xFFE23744),
      icon: Icons.restaurant_rounded,
      pkg: 'com.application.zomato',
      url: 'https://www.zomato.com/',
      mark: SimpleIcons.zomato,
    ),
  ];
  final list = toBuy.where((s) => s.trim().isNotEmpty).toList();
  final groceries = [
    DealBanner(
      brand: 'Blinkit',
      title: list.isEmpty
          ? 'Groceries in minutes'
          : '${list.length} ${list.length == 1 ? 'thing' : 'things'} on your list',
      body: list.isEmpty
          ? 'Milk, fruit, snacks and more, delivered fast.'
          : '${list.take(3).join(', ')}${list.length > 3 ? ' and more' : ''} — get them in minutes.',
      action: 'Open Blinkit',
      color: const Color(0xFF0C831F),
      icon: Icons.shopping_basket_rounded,
      pkg: 'com.grofers.customerapp',
      url: 'https://blinkit.com/',
    ),
    const DealBanner(
      brand: 'Zepto',
      title: 'Daily needs, fast',
      body: 'Groceries and essentials at your door.',
      action: 'Open Zepto',
      color: Color(0xFF7B2FF7),
      icon: Icons.bolt_rounded,
      pkg: 'com.zeptoconsumerapp',
      url: 'https://www.zeptonow.com/',
    ),
  ];
  const shop = [
    DealBanner(
      brand: 'Amazon',
      title: "Today's deals",
      body: 'The deals Amazon is running today, on one page.',
      action: 'See deals',
      color: Color(0xFFFF9900),
      icon: Icons.local_offer_rounded,
      url: 'https://www.amazon.in/deals',
      iconPkg: 'in.amazon.mShop.android.shopping',
    ),
    DealBanner(
      brand: 'Flipkart',
      title: 'Offers on Flipkart',
      body: 'Phones, fashion and home — the current offers.',
      action: 'See offers',
      color: Color(0xFF2874F0),
      icon: Icons.shopping_bag_rounded,
      url: 'https://www.flipkart.com/offers-store',
      iconPkg: 'com.flipkart.android',
    ),
  ];
  // Meal times lead with food; a list to buy leads with groceries.
  final mealTime = (h >= 7 && h < 10) || (h >= 12 && h < 15) || (h >= 19 && h < 23);
  if (list.isNotEmpty && !mealTime) return [...groceries, ...food, ...shop];
  if (mealTime) return [...food, ...groceries, ...shop];
  return [...shop, ...groceries, ...food];
}

/// The sliding card: one banner at a time, swiping or every 6 seconds.
class DealBanners extends StatefulWidget {
  const DealBanners({super.key, required this.banners});
  final List<DealBanner> banners;

  @override
  State<DealBanners> createState() => _DealBannersState();
}

class _DealBannersState extends State<DealBanners> {
  final _page = PageController(viewportFraction: 0.9);
  int _at = 0;
  Timer? _auto;
  bool _held = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _arm();
  }

  void _arm() {
    _auto?.cancel();
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (still || widget.banners.length < 2) return;
    _auto = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted || _held || !_page.hasClients) return;
      final next = (_at + 1) % widget.banners.length;
      _page.animateToPage(next, duration: const Duration(milliseconds: 520), curve: Curves.easeOutCubic);
    });
  }

  @override
  void dispose() {
    _auto?.cancel();
    _page.dispose();
    super.dispose();
  }

  Future<void> _open(DealBanner b) async {
    HapticFeedback.selectionClick();
    AppLog.add('home', 'banner ${b.brand}');
    // 2026-11-07 (Manish): the store's site opens inside the app (the shop
    // browser, with Compare and Ask AI) instead of handing off to its app.
    if (b.url.isNotEmpty) {
      openInShopBrowser(context, b.url);
      return;
    }
    if (b.pkg.isNotEmpty) {
      try {
        await const MethodChannel('hari/intent').invokeMethod<String>('launchApp', {'name': b.brand, 'pkg': b.pkg});
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final banners = widget.banners;
    if (banners.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text('Order and shop', style: NeonType.eyebrow.copyWith(color: Neon.textLo)),
        ),
        Listener(
          onPointerDown: (_) => _held = true,
          onPointerUp: (_) => _held = false,
          onPointerCancel: (_) => _held = false,
          child: SizedBox(
            height: 164,
            // The next banner peeks in on the right (viewportFraction).
            child: PageView.builder(
              controller: _page,
              // Lined up with the page's left edge; the next one peeks on the right.
              padEnds: false,
              itemCount: banners.length,
              onPageChanged: (i) => setState(() => _at = i),
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.only(right: 10),
                child: _BannerCard(banner: banners[i], onTap: () => _open(banners[i])),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < banners.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _at ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  color: i == _at ? Neon.cyan : Neon.textDim.withValues(alpha: 0.45),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _BannerCard extends StatelessWidget {
  const _BannerCard({required this.banner, required this.onTap});
  final DealBanner banner;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = banner.color;
    final r = BorderRadius.circular(22);
    return Semantics(
      button: true,
      label: '${banner.brand}. ${banner.title}. ${banner.body}. ${banner.action}',
      excludeSemantics: true,
      child: Material(
        borderRadius: r,
        clipBehavior: Clip.antiAlias,
        // The theme's night, warmed by the brand's own colour from one side.
        color: Color.lerp(Neon.bg, Colors.black, 0.2),
        child: InkWell(
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: r,
              border: Border.all(color: c.withValues(alpha: 0.45)),
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [c.withValues(alpha: 0.30), c.withValues(alpha: 0.06)],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 14, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(banner.brand,
                            style: NeonType.manrope(13, FontWeight.w800)
                                .copyWith(color: Color.lerp(c, Colors.white, 0.35))),
                        const SizedBox(height: 4),
                        Text(banner.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: NeonType.manrope(18, FontWeight.w800)
                                .copyWith(color: Neon.textHi, letterSpacing: -0.2)),
                        const SizedBox(height: 3),
                        Expanded(
                          child: Text(banner.body,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: Neon.textLo, fontSize: 13, height: 1.3)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(20)),
                          child: Text(banner.action,
                              style: NeonType.manrope(12.5, FontWeight.w800)
                                  .copyWith(color: c.computeLuminance() > 0.5 ? Colors.black : Colors.white)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _BrandLogo(banner: banner, size: 64),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// THE BRAND'S OWN LOGO (owner, 2026-11-01: "add their original logos"):
/// the installed app's icon, from the phone itself (nothing bundled in our
/// repo); else the brand's mark from simple_icons; else its initial.
class _BrandLogo extends StatefulWidget {
  const _BrandLogo({required this.banner, required this.size});
  final DealBanner banner;
  final double size;

  /// Icons read once per run, by package (null: not installed).
  static final _icons = <String, Future<Uint8List?>>{};

  static Future<Uint8List?> iconOf(String pkg) => _icons[pkg] ??= () async {
        try {
          return await const MethodChannel('hari/intent').invokeMethod<Uint8List>('appIcon', {'pkg': pkg, 'size': 192});
        } catch (_) {
          return null;
        }
      }();

  @override
  State<_BrandLogo> createState() => _BrandLogoState();
}

class _BrandLogoState extends State<_BrandLogo> {
  Uint8List? _png;

  @override
  void initState() {
    super.initState();
    final pkg = widget.banner.logoPkg;
    if (pkg.isNotEmpty) {
      _BrandLogo.iconOf(pkg).then((png) {
        if (mounted && png != null) setState(() => _png = png);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.banner;
    final c = b.color;
    final size = widget.size;
    final png = _png;
    if (png != null) {
      // The app's real icon, as on the home screen, with a soft lift.
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * 0.26),
          boxShadow: [BoxShadow(color: c.withValues(alpha: 0.45), blurRadius: 16, spreadRadius: -2)],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(size * 0.26),
          child: Image.memory(png, width: size, height: size, fit: BoxFit.cover, gaplessPlayback: true),
        ),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.26),
        color: c,
        boxShadow: [BoxShadow(color: c.withValues(alpha: 0.45), blurRadius: 16, spreadRadius: -2)],
      ),
      alignment: Alignment.center,
      child: b.mark != null
          ? Icon(b.mark, color: Colors.white, size: size * 0.56)
          : Text(b.brand.characters.first,
              style: NeonType.manrope(size * 0.48, FontWeight.w800)
                  .copyWith(color: c.computeLuminance() > 0.5 ? Colors.black : Colors.white)),
    );
  }
}
