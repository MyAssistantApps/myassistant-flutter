import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../design/neon_tokens.dart';
import 'airlines.dart';
import 'price_models.dart';

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

/// A CATEGORY'S TILE, BuyHatke's (owner, 2026-11-04): a glass card with
/// its photo on top, "Flight / Compare" under it and an optional ribbon
/// (HOT, NEW, BETA) on the top edge. The photo keeps its 4:3 shape and the
/// text sizes itself, so the tile never overflows (it did as a fixed-ratio
/// grid cell at large text sizes).
class PriceCategoryTile extends StatelessWidget {
  const PriceCategoryTile({super.key, required this.category, required this.onTap, this.selected = false});
  final PriceCategory category;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(Neon.rLg);
    final tag = category.tag;
    final tagColor = switch (tag) {
      'HOT' => const Color(0xFFFF6A3D),
      'NEW' => const Color(0xFF3D7BFF),
      _ => const Color(0xFF22B573),
    };
    return Semantics(
      button: true,
      selected: selected,
      label: '${category.tileTitle} ${category.tileSubtitle}. ${category.line}',
      excludeSemantics: true,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: r,
              onTap: () {
                HapticFeedback.selectionClick();
                onTap();
              },
              child: Ink(
                padding: const EdgeInsets.fromLTRB(6, 6, 6, 10),
                decoration: Neon.glassBox(Neon.rLg).copyWith(
                  border: Border.all(color: selected ? Neon.violet : Neon.glassEdge.first, width: selected ? 1.6 : 1),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(Neon.rMd - 2),
                      child: AspectRatio(
                        aspectRatio: 4 / 3,
                        child: Image.asset(category.photo,
                            fit: BoxFit.cover, cacheWidth: 360, filterQuality: FilterQuality.medium),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(category.tileTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: NeonType.manrope(14.5, FontWeight.w800).copyWith(color: Neon.textHi, height: 1.15)),
                    Text(category.tileSubtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: NeonType.manrope(14.5, FontWeight.w800).copyWith(color: Neon.textHi, height: 1.15)),
                  ],
                ),
              ),
            ),
          ),
          if (tag.isNotEmpty)
            Positioned(
              top: -7,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: tagColor,
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [BoxShadow(color: tagColor.withValues(alpha: 0.45), blurRadius: 8)],
                  ),
                  child: Text(tag == 'HOT' ? '🔥 HOT' : tag,
                      style: NeonType.manrope(10, FontWeight.w800).copyWith(color: Colors.white, letterSpacing: 0.6)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The six tiles, three to a row; rows take their tallest tile's height.
class PriceCategoryGrid extends StatelessWidget {
  const PriceCategoryGrid({super.key, required this.onTap, this.selected});
  final void Function(PriceCategory c) onTap;
  final PriceCategory? selected;

  @override
  Widget build(BuildContext context) {
    const all = PriceCategory.values;
    return Column(
      children: [
        for (var row = 0; row < all.length; row += 3) ...[
          if (row > 0) const SizedBox(height: 14),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // A short last row (5 tiles: 3 + 2) sits centred, its
                // tiles the same width as the row above.
                if (all.length - row < 3) Spacer(flex: 3 - (all.length - row)),
                for (var i = row; i < row + 3 && i < all.length; i++) ...[
                  if (i > row) const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child:
                        PriceCategoryTile(category: all[i], selected: all[i] == selected, onTap: () => onTap(all[i])),
                  ),
                ],
                if (all.length - row < 3) Spacer(flex: 3 - (all.length - row)),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// THE BANNER, BuyHatke's top (owner, 2026-11-04): a private jet on the
/// runway, the promise over it, and one button.
class PriceHeroBanner extends StatelessWidget {
  const PriceHeroBanner({super.key, required this.onTap, this.height = 210, this.bottomInset = 0});
  final VoidCallback onTap;
  final double height;

  /// Room kept clear at the bottom for something laid over it (the
  /// search bar on Home).
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(Neon.rCard);
    return Semantics(
      button: true,
      label: 'Pay less, travel better. Compare flights, hotels, rides and shopping.',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          // At least [height]; taller when large text needs it.
          constraints: BoxConstraints(minHeight: height),
          decoration: BoxDecoration(borderRadius: r, boxShadow: Neon.glassShadow),
          child: ClipRRect(
            borderRadius: r,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Image.asset('assets/pricecompare/hero.jpg',
                      fit: BoxFit.cover, alignment: const Alignment(0, 0.2)),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.55),
                          Colors.black.withValues(alpha: 0.05),
                          Colors.black.withValues(alpha: 0.65),
                        ],
                        stops: const [0, 0.45, 1],
                      ),
                    ),
                  ),
                ),
                ConstrainedBox(
                  constraints: BoxConstraints(minHeight: height, minWidth: double.infinity),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(18, 16, 18, 16 + bottomInset),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Pay less.\nTravel first class.',
                              style: NeonType.manrope(25, FontWeight.w800)
                                  .copyWith(color: Colors.white, letterSpacing: -0.6, height: 1.1)),
                          const SizedBox(height: 6),
                          Text('Compare flights, hotels, rides & shopping',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.88), fontSize: 13)),
                        ]),
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(Neon.rPill),
                            gradient: LinearGradient(colors: [
                              Color.lerp(Neon.accentFill, Colors.white, 0.12)!,
                              Neon.accentFill,
                            ]),
                            boxShadow: Neon.halo(Neon.violet, strength: 0.6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('COMPARE NOW',
                                  style: NeonType.manrope(13, FontWeight.w800)
                                      .copyWith(color: Colors.white, letterSpacing: 0.8)),
                              const SizedBox(width: 8),
                              Container(
                                width: 22,
                                height: 22,
                                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                child: Icon(Icons.play_arrow_rounded, size: 17, color: Neon.accentFill),
                              ),
                            ],
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
}

/// BuyHatke's search bar: search, "or paste a link", a paste button.
class PriceSearchBar extends StatelessWidget {
  const PriceSearchBar({super.key, required this.onTap, required this.onPaste});
  final VoidCallback onTap;
  final VoidCallback onPaste;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(Neon.rMd);
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: r,
          color: Color.alphaBlend(Neon.surfaceHigh.withValues(alpha: 0.92), Neon.bg),
          border: Border.all(color: Neon.glassEdge.first),
          boxShadow: Neon.glassShadow,
        ),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                borderRadius: r,
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 15, 8, 15),
                  child: Row(
                    children: [
                      Icon(Icons.search_rounded, color: Neon.violet, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text('Search or paste a link for the best price',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Neon.textDim, fontSize: 14.5)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Container(width: 1, height: 26, color: Neon.hairline),
            IconButton(
              tooltip: 'Paste a product link',
              onPressed: onPaste,
              icon: Icon(Icons.content_paste_rounded, color: Neon.violet, size: 21),
            ),
          ],
        ),
      ),
    );
  }
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
              Text('Photo credits', style: NeonType.manrope(18, FontWeight.w800).copyWith(color: Neon.textHi)),
              const SizedBox(height: 4),
              Text('From Wikimedia Commons, resized.', style: TextStyle(color: Neon.textLo, fontSize: 12.5)),
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
