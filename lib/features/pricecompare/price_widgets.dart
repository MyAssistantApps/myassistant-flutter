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

/// THE HERO (2026-11-08, Manish: "the aeroplane image is not looking good —
/// redesign it so it attracts the user"). No photo: a warm gradient that
/// says "deals", the promise, a small example of what a comparison looks
/// like (real store logos, marked "e.g."), and the search field inside it.
class PriceHeroBanner extends StatelessWidget {
  const PriceHeroBanner({super.key, required this.onSearch, required this.onPaste});
  final VoidCallback onSearch;
  final VoidCallback onPaste;

  static const _c1 = Color(0xFF5B2EFF), _c2 = Color(0xFFB026E0), _c3 = Color(0xFFFF7A45);

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(Neon.rCard);
    return Container(
      decoration: BoxDecoration(
        borderRadius: r,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_c1, _c2, _c3],
          stops: [0, 0.55, 1],
        ),
        boxShadow: [BoxShadow(color: _c2.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 10))],
      ),
      child: ClipRRect(
        borderRadius: r,
        child: Stack(
          children: [
            // Two soft lights in the corners, so the gradient has depth.
            Positioned(right: -60, top: -70, child: _glow(200, Colors.white.withValues(alpha: 0.16))),
            Positioned(left: -50, bottom: -80, child: _glow(180, _c3.withValues(alpha: 0.35))),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(Neon.rPill),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.auto_awesome_rounded, size: 13, color: Colors.white),
                      const SizedBox(width: 5),
                      Text('SMART SHOPPING',
                          style: NeonType.manrope(10.5, FontWeight.w800)
                              .copyWith(color: Colors.white, letterSpacing: 1.1)),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  Text('Same product.\nLower price.',
                      style: NeonType.manrope(27, FontWeight.w800)
                          .copyWith(color: Colors.white, letterSpacing: -0.8, height: 1.08)),
                  const SizedBox(height: 6),
                  Text('We check every store in seconds — you just pick the cheapest.',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13.5, height: 1.3)),
                  const SizedBox(height: 14),
                  const _ExampleCompare(),
                  const SizedBox(height: 14),
                  _search(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _glow(double size, Color c) => IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [c, c.withValues(alpha: 0)]),
          ),
        ),
      );

  /// White on the gradient: the one thing to tap, impossible to miss.
  Widget _search() {
    final r = BorderRadius.circular(Neon.rMd);
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
                onSearch();
              },
              child: const Padding(
                padding: EdgeInsets.fromLTRB(14, 14, 8, 14),
                child: Row(children: [
                  Icon(Icons.search_rounded, color: _c1, size: 22),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text('Search or paste a link',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Color(0xFF6B6880), fontSize: 14.5, fontWeight: FontWeight.w500)),
                  ),
                ]),
              ),
            ),
          ),
          Container(width: 1, height: 24, color: const Color(0x1A141627)),
          IconButton(
            tooltip: 'Paste a product link',
            onPressed: onPaste,
            icon: const Icon(Icons.content_paste_rounded, color: _c1, size: 21),
          ),
        ],
      ),
    );
  }
}

/// What a comparison looks like: three stores, one marked LOWEST. An
/// illustration ("e.g."), not a live price.
class _ExampleCompare extends StatelessWidget {
  const _ExampleCompare();

  @override
  Widget build(BuildContext context) {
    const rows = [
      ('amazon', 'Amazon', '₹1,099', true),
      ('flipkart', 'Flipkart', '₹1,299', false),
      ('croma', 'Croma', '₹1,499', false),
    ];
    return ExcludeSemantics(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(Neon.rMd),
          border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('e.g. boAt Airdopes 141',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 11.5, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            for (final (logo, name, price, best) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.asset('assets/brands/$logo.png', width: 24, height: 24, cacheWidth: 72),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(name,
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: best ? 1 : 0.85),
                              fontSize: 13.5,
                              fontWeight: best ? FontWeight.w700 : FontWeight.w500)),
                    ),
                    if (best) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: const Color(0xFF22C55E), borderRadius: BorderRadius.circular(5)),
                        child: Text('LOWEST',
                            style: NeonType.manrope(9, FontWeight.w800).copyWith(color: Colors.white, letterSpacing: 0.6)),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(price,
                        style: NeonType.manrope(best ? 15 : 13.5, FontWeight.w800).copyWith(
                          color: Colors.white.withValues(alpha: best ? 1 : 0.7),
                          decoration: best ? null : TextDecoration.lineThrough,
                          decorationColor: Colors.white.withValues(alpha: 0.6),
                        )),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// THE CATEGORIES, REDONE (2026-11-08): Shopping, the one most used, as a
/// wide card on top; the other four as a 2 × 2 of full-photo cards. Five
/// tiles as 3 + 2 left a ragged, centred last row.
class PriceCategoryShowcase extends StatelessWidget {
  const PriceCategoryShowcase({super.key, required this.onTap, this.selected});
  final void Function(PriceCategory c) onTap;
  final PriceCategory? selected;

  @override
  Widget build(BuildContext context) {
    final rest = PriceCategory.values.where((c) => c != PriceCategory.shopping).toList();
    return Column(
      children: [
        _PhotoCard(
          category: PriceCategory.shopping,
          title: 'Product compare',
          line: 'Amazon, Flipkart, Croma & more',
          wide: true,
          selected: selected == PriceCategory.shopping,
          onTap: () => onTap(PriceCategory.shopping),
        ),
        for (var i = 0; i < rest.length; i += 2) ...[
          const SizedBox(height: 10),
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
  });
  final PriceCategory category;
  final String title;
  final String line;
  final VoidCallback onTap;
  final bool wide;
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
