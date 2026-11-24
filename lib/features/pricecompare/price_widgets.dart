import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../design/neon_tokens.dart';
import 'airlines.dart';
import 'price_models.dart';
import 'price_service.dart';

/// A store's mark: its initial on its own colour (no logos are bundled).
class StoreMark extends StatelessWidget {
  const StoreMark(this.store, {super.key, this.size = 36, this.name});
  final PriceStore? store;

  /// For a store not in the list (the web found another).
  final String? name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = store?.color ?? Neon.textLo;
    final label = store?.initial ?? ((name ?? '?').trim().isEmpty ? '?' : name!.trim()[0].toUpperCase());
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(size * 0.3),
        border: Border.all(color: Colors.white.withValues(alpha: Neon.isDark ? 0.14 : 0.6)),
      ),
      child: Text(label,
          style: NeonType.manrope(size * 0.46, FontWeight.w800).copyWith(color: Neon.textOn(color), height: 1)),
    );
  }
}

/// A PRODUCT PHOTO THAT ALWAYS SHOWS (2026-11-24): the [url] the search
/// gave, and when it is missing or will not load (made-up links, stores
/// that refuse apps), a real photo of [name] found on the server
/// (PriceService.photosFor) — the [pick]-th, so a gallery shows different
/// ones. The [icon] only when nothing at all can be found.
class ProductPhoto extends StatefulWidget {
  const ProductPhoto(this.url,
      {super.key, required this.name, this.pick = 0, this.icon = Icons.shopping_bag_outlined, this.iconColor});
  final String url;
  final String name;
  final int pick;
  final IconData icon;
  final Color? iconColor;

  @override
  State<ProductPhoto> createState() => _ProductPhotoState();
}

class _ProductPhotoState extends State<ProductPhoto> {
  late bool _fallback;
  Future<List<String>>? _found;
  int _skip = 0;

  @override
  void initState() {
    super.initState();
    _reset();
  }

  @override
  void didUpdateWidget(ProductPhoto old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url || old.name != widget.name || old.pick != widget.pick) _reset();
  }

  void _reset() {
    _fallback = !widget.url.startsWith('https://');
    _found = _fallback ? PriceService.instance.photosFor(widget.name) : null;
    _skip = 0;
  }

  void _later(VoidCallback f) => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(f);
      });

  Widget get _icon => Center(child: Icon(widget.icon, color: widget.iconColor ?? Neon.textDim, size: 40));

  Widget _net(String url, {required VoidCallback onError}) => Image.network(
        url,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        loadingBuilder: (_, child, p) => p == null ? child : _icon,
        errorBuilder: (_, __, ___) {
          onError();
          return _icon;
        },
      );

  @override
  Widget build(BuildContext context) {
    if (!_fallback) {
      return _net(widget.url, onError: () => _later(() {
            _fallback = true;
            _found = PriceService.instance.photosFor(widget.name);
          }));
    }
    return FutureBuilder<List<String>>(
      future: _found,
      builder: (_, snap) {
        final list = snap.data ?? const <String>[];
        if (list.isEmpty || _skip >= list.length) return _icon;
        final url = list[(widget.pick + _skip) % list.length];
        // A photo that will not load: the next one found.
        return _net(url, onError: () => _later(() => _skip++));
      },
    );
  }
}

/// THE CATEGORIES, REDONE (2026-11-08): Shopping, the one most used, as a
/// wide card on top; the other four as a 2 × 2 of full-photo cards. Five
/// tiles as 3 + 2 left a ragged, centred last row.
class PriceCategoryShowcase extends StatelessWidget {
  const PriceCategoryShowcase(
      {super.key, required this.onTap, this.selected, this.only, this.onSearch, this.onCamera, this.onMic, this.mic});
  final void Function(PriceCategory c) onTap;
  final PriceCategory? selected;

  /// A white search box along the bottom of the Product Compare card, with
  /// the camera and [mic] in it (Home, Manish, 2026-11-24). Shown when
  /// [onSearch] is; then the round buttons below are not.
  final VoidCallback? onSearch;
  final Widget? mic;

  /// Search by photo / by voice: round buttons on the Product Compare card
  /// beside Compare now (Allen, 2026-11-24, in place of the Smart Shopping
  /// hero). The camera goes in the search box when there is one.
  final VoidCallback? onCamera;
  final VoidCallback? onMic;

  /// When set, only these categories, as long bordered cards one under
  /// another (Home shows just flights and hotels, 2026-11-09).
  final List<PriceCategory>? only;

  @override
  Widget build(BuildContext context) {
    final small = only != null;
    // Owner, 2026-11-14: only what PriceCategory.shown offers (products).
    final rest = only ?? PriceCategory.shown.where((c) => c != PriceCategory.shopping).toList();
    return Column(
      children: [
        if (!small)
          _PhotoCard(
            category: PriceCategory.shopping,
            title: 'Product Compare',
            line: 'Amazon, Flipkart, Croma & more',
            wide: true,
            selected: selected == PriceCategory.shopping,
            onTap: () => onTap(PriceCategory.shopping),
            onSearch: onSearch,
            onCamera: onCamera,
            onMic: onMic,
            mic: mic,
          ),
        if (small)
          // Side by side, photo on top, name under it (Manish, 2026-11-10).
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final c in rest) ...[
                  if (c != rest.first) const SizedBox(width: 10),
                  Expanded(
                    child: _PhotoCard(
                      category: c,
                      title: c == PriceCategory.cabs ? 'Rides' : c.label,
                      line: c.line,
                      selected: selected == c,
                      small: true,
                      onTap: () => onTap(c),
                    ),
                  ),
                ],
              ],
            ),
          )
        else
          for (var i = 0; i < rest.length; i += 2) ...[
            if (!small || i > 0) const SizedBox(height: 10),
            Row(
              children: [
                for (var k = i; k < i + 2 && k < rest.length; k++) ...[
                  if (k > i) const SizedBox(width: 10),
                  Expanded(
                    child: _PhotoCard(
                      category: rest[k],
                      title: rest[k] == PriceCategory.cabs ? 'Rides' : rest[k].label,
                      line: rest[k].line,
                      selected: selected == rest[k],
                      onTap: () => onTap(rest[k]),
                    ),
                  ),
                ],
              ],
            ),
          ],
      ],
    );
  }
}

/// One category: its photo edge to edge, the name on a dark fade at the
/// bottom (always readable, whatever the photo), a ribbon when it has one.
class _PhotoCard extends StatelessWidget {
  const _PhotoCard({
    required this.category,
    required this.title,
    required this.line,
    required this.onTap,
    this.wide = false,
    this.selected = false,
    this.small = false,
    this.onSearch,
    this.onCamera,
    this.onMic,
    this.mic,
  });
  final PriceCategory category;
  final String title;
  final String line;
  final VoidCallback onTap;
  final bool wide;
  final bool selected;
  final bool small;
  final VoidCallback? onSearch;
  final VoidCallback? onCamera;
  final VoidCallback? onMic;
  final Widget? mic;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(Neon.rLg);
    final tag = category.tag;
    final tagColor = switch (tag) {
      'HOT' => const Color(0xFFFF6A3D),
      'NEW' => const Color(0xFF3D7BFF),
      _ => const Color(0xFF22B573),
    };
    if (small) return _bordered(r);
    if (wide) return _feature();
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: NeonType.manrope(wide ? 19 : 16, FontWeight.w800)
                .copyWith(color: Colors.white, letterSpacing: -0.3, height: 1.1)),
        const SizedBox(height: 2),
        Text(line,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: wide ? 13 : 11.5)),
      ],
    );
    return Semantics(
      button: true,
      selected: selected,
      label: '$title. $line',
      excludeSemantics: true,
      child: AspectRatio(
        aspectRatio: wide ? 2.6 : 1.2,
        child: Material(
          color: Colors.transparent,
          borderRadius: r,
          clipBehavior: Clip.antiAlias,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: r,
              border: selected ? Border.all(color: Neon.violet, width: 2) : null,
              image: DecorationImage(
                image: ResizeImage(AssetImage(category.photo), width: wide ? 720 : 400),
                fit: BoxFit.cover,
              ),
            ),
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                onTap();
              },
              child: Stack(
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: wide
                            ? LinearGradient(colors: [
                                Colors.black.withValues(alpha: 0.78),
                                Colors.black.withValues(alpha: 0.35),
                                Colors.transparent,
                              ], stops: const [0, 0.55, 1])
                            : LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Colors.transparent, Colors.black.withValues(alpha: 0.78)],
                                stops: const [0.35, 1],
                              ),
                      ),
                    ),
                  ),
                  if (tag.isNotEmpty)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(color: tagColor, borderRadius: BorderRadius.circular(6)),
                        child: Text(tag == 'HOT' ? '🔥 HOT' : tag,
                            style: NeonType.manrope(10, FontWeight.w800)
                                .copyWith(color: Colors.white, letterSpacing: 0.6)),
                      ),
                    ),
                  Positioned(
                    left: 12,
                    right: wide ? 64 : 10,
                    bottom: 10,
                    top: wide ? 0 : null,
                    child: wide ? Align(alignment: Alignment.centerLeft, child: text) : text,
                  ),
                  if (wide)
                    Positioned(
                      right: 12,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                          child: Icon(Icons.arrow_forward_rounded, color: Neon.accentFill, size: 22),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The wide Product compare card, redone (2026-11-21, Manish: "not looking
  /// good", then "improve more, change the image"): a glass card — eyebrow,
  /// name, one line, the stores as overlapping brand avatars, a Compare now
  /// pill — and on the right a drawn illustration (a bag with an old price
  /// struck out and the lowest price in green) instead of the mall photo.
  /// Drawn, so it needs no licence and follows the accent in both themes.
  /// Selected = accent gradient border + glow.
  Widget _feature() {
    final r = BorderRadius.circular(Neon.rCard);
    final inner = BorderRadius.circular(Neon.rCard - (selected ? 1.5 : 1));
    const stores = [PriceStores.amazon, PriceStores.flipkart, PriceStores.croma, PriceStores.reliance];
    final accent = Neon.violet;
    final body = Ink(
      padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
      decoration: BoxDecoration(
        borderRadius: inner,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(accent.withValues(alpha: Neon.isDark ? 0.20 : 0.10), Neon.surface),
            Neon.surface,
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(Neon.rPill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome_rounded, size: 11, color: accent),
                      const SizedBox(width: 4),
                      Text('MOST USED',
                          style: NeonType.manrope(9.5, FontWeight.w800).copyWith(color: accent, letterSpacing: 1)),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: NeonType.manrope(20, FontWeight.w800)
                        .copyWith(color: Neon.textHi, letterSpacing: -0.5, height: 1.1)),
                const SizedBox(height: 4),
                Text('One search. Every store. Lowest price.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Neon.textLo, fontSize: 12.5, height: 1.3)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    SizedBox(
                      width: 26.0 + (stores.length - 1) * 19,
                      height: 26,
                      child: Stack(
                        children: [
                          for (var i = 0; i < stores.length; i++)
                            Positioned(left: i * 19.0, child: _storeAvatar(stores[i])),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text('& more',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Neon.textLo, fontSize: 11.5, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Flexible(child: _compareNow(accent)),
                    if (onCamera != null && onSearch == null) ...[
                      const SizedBox(width: 8),
                      _roundAction(Icons.photo_camera_rounded, 'Search by Photo', onCamera!, accent),
                    ],
                    if (onMic != null && onSearch == null) ...[
                      const SizedBox(width: 8),
                      _roundAction(Icons.mic_rounded, 'Search by Voice', onMic!, accent),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          const _CompareArt(),
        ],
          ),
          if (onSearch != null) ...[const SizedBox(height: 14), _searchBox()],
        ],
      ),
    );
    return Semantics(
      button: true,
      selected: selected,
      label: '$title. $line',
      // The search box, camera and mic stay reachable on their own.
      excludeSemantics: onSearch == null && onCamera == null && onMic == null,
      child: DecoratedBox(
        // The border is a gradient, so it is drawn as a padded backdrop.
        decoration: BoxDecoration(
          borderRadius: r,
          gradient: selected ? Neon.gVioletPink : null,
          color: selected ? null : Neon.hairline,
          boxShadow: selected
              ? [BoxShadow(color: accent.withValues(alpha: 0.25), blurRadius: 24, offset: const Offset(0, 8))]
              : null,
        ),
        child: Padding(
          padding: EdgeInsets.all(selected ? 1.5 : 1),
          child: Material(
            color: Colors.transparent,
            borderRadius: inner,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                onTap();
              },
              child: body,
            ),
          ),
        ),
      ),
    );
  }

  /// The search box: tap to type, the camera, the mic. White in both
  /// themes (Manish, 2026-11-24), as the banner's was, so all three read.
  Widget _searchBox() {
    final r = BorderRadius.circular(Neon.rMd);
    const ink = Color(0xFF5B2EFF);
    return Material(
      color: Colors.white,
      borderRadius: r,
      elevation: 0,
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              borderRadius: r,
              onTap: () {
                HapticFeedback.selectionClick();
                onSearch!();
              },
              child: const Padding(
                padding: EdgeInsets.fromLTRB(12, 13, 8, 13),
                child: Row(children: [
                  Icon(Icons.search_rounded, color: ink, size: 21),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('Search a product',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Color(0xFF6B6880), fontSize: 14.5, fontWeight: FontWeight.w500)),
                  ),
                ]),
              ),
            ),
          ),
          if (onCamera != null || mic != null) Container(width: 1, height: 24, color: const Color(0x1A141627)),
          if (onCamera != null)
            IconButton(
              tooltip: 'Compare a product from a photo',
              onPressed: onCamera,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.photo_camera_outlined, color: ink, size: 23),
            ),
          if (mic != null) Padding(padding: const EdgeInsets.only(left: 2, right: 6), child: mic),
        ],
      ),
    );
  }

  /// A round accent-tinted button on the card (camera, mic).
  Widget _roundAction(IconData icon, String tooltip, VoidCallback onPressed, Color accent) => Tooltip(
        message: tooltip,
        child: Material(
          color: accent.withValues(alpha: 0.16),
          shape: CircleBorder(side: BorderSide(color: accent.withValues(alpha: 0.35))),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              onPressed();
            },
            child: SizedBox(width: 36, height: 36, child: Icon(icon, size: 19, color: accent)),
          ),
        ),
      );

  Widget _compareNow(Color accent) => Container(
                  padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
                  decoration: BoxDecoration(
                    color: Neon.accentFill,
                    borderRadius: BorderRadius.circular(Neon.rPill),
                    boxShadow: [
                      BoxShadow(color: accent.withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 4))
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text('Compare now',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: NeonType.manrope(13, FontWeight.w800).copyWith(color: Neon.onAccent)),
                      ),
                      const SizedBox(width: 6),
                      Icon(Icons.arrow_forward_rounded, color: Neon.onAccent, size: 16),
                    ],
                  ),
                );

  /// A store as its own app icon (the logos bundled in assets/brands/, as
  /// Popular apps and the shop browser show them), ringed in the card
  /// colour so the overlapping ones read apart; its initial if one is missing.
  Widget _storeAvatar(PriceStore s) {
    final letter = Container(
      color: s.color,
      alignment: Alignment.center,
      child: Text(s.name[0],
          style: TextStyle(color: Neon.glyphOn(s.color), fontSize: 11, fontWeight: FontWeight.w800, height: 1)),
    );
    return Container(
      width: 26,
      height: 26,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(color: Neon.surface, borderRadius: BorderRadius.circular(9)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: Image.asset(storeLogo(s),
            fit: BoxFit.cover,
            cacheWidth: 72,
            filterQuality: FilterQuality.medium,
            errorBuilder: (_, __, ___) => letter),
      ),
    );
  }

  /// Home's small tile (2026-11-09, owner: "give border to the image, not
  /// fill", then "straight instead of square, one by one"): a long bordered
  /// card. 2026-11-10 (Manish): back to side by side — the photo inset on
  /// top, the name and line under it.
  Widget _bordered(BorderRadius r) {
    final inner = BorderRadius.circular(Neon.rLg - 6);
    return Semantics(
      button: true,
      selected: selected,
      label: '$title. $line',
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        borderRadius: r,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Ink(
            padding: const EdgeInsets.fromLTRB(7, 7, 7, 12),
            decoration: BoxDecoration(
              borderRadius: r,
              color: Neon.glassFill.colors.first,
              border: Border.all(color: selected ? Neon.violet : Neon.hairline, width: selected ? 2 : 1.2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: 1.62,
                  child: ClipRRect(
                    borderRadius: inner,
                    child: Image(image: ResizeImage(AssetImage(category.photo), width: 400), fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: NeonType.manrope(17, FontWeight.w800)
                          .copyWith(color: Neon.textHi, letterSpacing: -0.4, height: 1.1)),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(line,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Neon.textLo, fontSize: 12, height: 1.25)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A store's app icon in assets/brands/.
String storeLogo(PriceStore s) => switch (s) {
      PriceStores.amazon => 'assets/brands/amazon.png',
      PriceStores.flipkart => 'assets/brands/flipkart.png',
      PriceStores.croma => 'assets/brands/croma.png',
      PriceStores.reliance => 'assets/brands/reliancedigital.png',
      _ => 'assets/brands/${s.name.toLowerCase().replaceAll(' ', '')}.png',
    };

/// One product the illustration shows: what it is, an old price and the
/// lowest one, and the store that has it. Sample numbers, for the picture.
typedef _Showcase = ({String photo, String name, String was, String now, PriceStore at});

const List<_Showcase> _showcase = [
  (
    photo: 'assets/pricecompare/product_phone.jpg',
    name: 'Phones',
    was: '₹54,999',
    now: '₹49,990',
    at: PriceStores.flipkart
  ),
  (
    photo: 'assets/pricecompare/product_laptop.jpg',
    name: 'Laptops',
    was: '₹72,990',
    now: '₹64,490',
    at: PriceStores.amazon
  ),
  (
    photo: 'assets/pricecompare/product_audio.jpg',
    name: 'Audio',
    was: '₹29,990',
    now: '₹24,990',
    at: PriceStores.croma
  ),
  (
    photo: 'assets/pricecompare/product_watch.jpg',
    name: 'Watches',
    was: '₹14,999',
    now: '₹11,499',
    at: PriceStores.amazon
  ),
  (photo: 'assets/pricecompare/product_tv.jpg', name: 'TVs', was: '₹46,990', now: '₹39,990', at: PriceStores.reliance),
];

/// The Product Compare illustration (2026-11-21, Manish: "auto change
/// image"): the accent tile shows a product that changes every few seconds
/// — phone, laptop, headphones, watch, TV — each with an old price struck
/// out and the lowest price in green with the icon of the store that has
/// it. Still (the first product) when the phone asks for less motion.
/// Decorative only — the card's label says it all.
class _CompareArt extends StatefulWidget {
  const _CompareArt();

  @override
  State<_CompareArt> createState() => _CompareArtState();
}

class _CompareArtState extends State<_CompareArt> {
  static const _every = Duration(milliseconds: 2600);
  Timer? _timer;
  int _i = 0;

  bool _cached = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The photos are ready before they are shown: no blank frame between.
    if (!_cached) {
      _cached = true;
      for (final p in _showcase) {
        precacheImage(ResizeImage(AssetImage(p.photo), width: 360), context).catchError((_) {});
      }
    }
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (still) {
      _timer?.cancel();
      _timer = null;
    } else {
      _timer ??= Timer.periodic(_every, (_) {
        if (mounted) setState(() => _i = (_i + 1) % _showcase.length);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF22C55E);
    final p = _showcase[_i];
    Widget swap(Widget child) => AnimatedSwitcher(
          duration: Neon.med,
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (c, a) => FadeTransition(
            opacity: a,
            child: ScaleTransition(scale: Tween(begin: 0.85, end: 1.0).animate(a), child: c),
          ),
          child: child,
        );
    return ExcludeSemantics(
      child: SizedBox(
        width: 112,
        height: 128,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              top: 10,
              bottom: 10,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(Neon.rLg),
                  gradient: Neon.gVioletPink,
                  boxShadow: [
                    BoxShadow(color: Neon.violet.withValues(alpha: 0.35), blurRadius: 18, offset: const Offset(0, 6))
                  ],
                ),
                // The product's real photo, edge to edge (2026-11-22, Manish:
                // "real images of the laptop, watches, TVs, phones"), cross-
                // fading with a slight zoom; a dark fade at the bottom keeps
                // its name readable.
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(Neon.rLg),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 550),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        layoutBuilder: (current, previous) =>
                            Stack(fit: StackFit.expand, children: [...previous, if (current != null) current]),
                        transitionBuilder: (c, a) => FadeTransition(
                          opacity: a,
                          child: ScaleTransition(scale: Tween(begin: 1.08, end: 1.0).animate(a), child: c),
                        ),
                        child: Image(
                          key: ValueKey(p.photo),
                          image: ResizeImage(AssetImage(p.photo), width: 360),
                          fit: BoxFit.cover,
                          filterQuality: FilterQuality.medium,
                          errorBuilder: (_, __, ___) =>
                              DecoratedBox(decoration: BoxDecoration(gradient: Neon.gVioletPink)),
                        ),
                      ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: const [0.45, 1],
                            colors: [Colors.transparent, Colors.black.withValues(alpha: 0.72)],
                          ),
                        ),
                      ),
                      // What is showing, under the product.
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 18,
                        child: swap(Text(p.name,
                            key: ValueKey(p.name),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            style: NeonType.manrope(10, FontWeight.w800)
                                .copyWith(color: Colors.white.withValues(alpha: 0.9), letterSpacing: 0.6))),
                      ),
                      // Which one of how many, as dots.
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 8,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (var k = 0; k < _showcase.length; k++)
                              AnimatedContainer(
                                duration: Neon.med,
                                width: k == _i ? 10 : 4,
                                height: 4,
                                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: k == _i ? 0.95 : 0.45),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // The old price, struck out.
            Positioned(
              top: 0,
              right: -4,
              child: swap(_tag(
                key: ValueKey('was$_i'),
                child: Text(p.was,
                    style: TextStyle(
                      color: Neon.textLo,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.lineThrough,
                      decorationColor: Neon.textLo,
                    )),
              )),
            ),
            // The lowest price, and the store that has it.
            Positioned(
              bottom: 0,
              left: -6,
              child: swap(_tag(
                key: ValueKey('now$_i'),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.asset(storeLogo(p.at),
                          width: 15,
                          height: 15,
                          cacheWidth: 48,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.trending_down_rounded, color: green, size: 13)),
                    ),
                    const SizedBox(width: 4),
                    Text(p.now, style: NeonType.manrope(11.5, FontWeight.w800).copyWith(color: Neon.textHi)),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(color: green, borderRadius: BorderRadius.circular(4)),
                      child: Text('LOW',
                          style:
                              NeonType.manrope(8, FontWeight.w800).copyWith(color: Colors.white, letterSpacing: 0.4)),
                    ),
                  ],
                ),
              )),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tag({Key? key, required Widget child}) => Container(
        key: key,
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: Neon.surfaceHigh,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Neon.hairline),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 10, offset: const Offset(0, 3))
          ],
        ),
        child: child,
      );
}

/// The photo credits the licences ask for.
void showPhotoCredits(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Photo Credits', style: NeonType.manrope(18, FontWeight.w800).copyWith(color: Neon.textHi)),
              const SizedBox(height: 4),
              Text('Sourced from Wikimedia Commons and resized.', style: TextStyle(color: Neon.textLo, fontSize: 12.5)),
              const SizedBox(height: 10),
              for (final (what, who, licence) in [...photoCredits, ...airlineCredits])
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Text('$what — $who ($licence)', style: TextStyle(color: Neon.textHi, fontSize: 13)),
                ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => openPriceLink('https://commons.wikimedia.org/wiki/Main_Page'),
                child: const Text('Wikimedia Commons'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// A small coloured label: LOWEST, AI PICK, 12% OFF.
class PriceBadge extends StatelessWidget {
  const PriceBadge(this.text, this.color, {super.key});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.45)),
        ),
        child: Text(text, style: NeonType.manrope(9.5, FontWeight.w800).copyWith(color: color, letterSpacing: 0.8)),
      );
}

/// Opens [url] in its app when installed (Android app links), else the
/// browser.
Future<void> openPriceLink(String url) async {
  final u = Uri.tryParse(url);
  if (u == null || u.scheme != 'https') return;
  HapticFeedback.selectionClick();
  try {
    await launchUrl(u, mode: LaunchMode.externalApplication);
  } catch (_) {}
}
