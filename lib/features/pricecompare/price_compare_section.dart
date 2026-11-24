import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design/neon_tokens.dart';
import 'flight_search_screen.dart';
import 'hotel_search_screen.dart';
import 'price_compare_screen.dart';
import 'price_models.dart';
import 'price_service.dart';
import '../../widgets/neon_cards.dart';
import '../../widgets/role_mic_orb.dart';
import 'price_widgets.dart';

/// ─────────────────────────────────────────────────────────────────────────
///  PRICE COMPARE ON HOME (2026-11-04, owner: "below Try now AI studio,
///  matching the current UI, laid out like BuyHatke"): a heading with its
///  pill as Try now's, then one glass card — the search box ("search or
///  paste a link"), the stores it compares, and the six things to compare.
///  A line under it says when an alert has hit its price.
/// ─────────────────────────────────────────────────────────────────────────
class PriceCompareSection extends StatefulWidget {
  const PriceCompareSection({super.key, required this.onOpen});

  /// Opens a page the way Home opens every page.
  final void Function(Widget page) onOpen;

  @override
  State<PriceCompareSection> createState() => _PriceCompareSectionState();
}

class _PriceCompareSectionState extends State<PriceCompareSection> {
  final svc = PriceService.instance;

  @override
  void initState() {
    super.initState();
    svc.addListener(_changed);
    svc.load();
  }

  @override
  void dispose() {
    svc.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _open(
      {PriceCategory category = PriceCategory.shopping, bool focus = false, bool paste = false, bool camera = false}) {
    HapticFeedback.selectionClick();
    // Flights and hotels have their own pages (dates, travellers, rooms…).
    widget.onOpen(switch (category) {
      PriceCategory.flights => const FlightSearchScreen(),
      PriceCategory.hotels => const HotelSearchScreen(),
      _ => PriceCompareScreen(category: category, focus: focus, paste: paste, camera: camera),
    });
  }

  @override
  Widget build(BuildContext context) {
    final hit = svc.watches.where((w) => w.reached).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Padding(
            padding: const EdgeInsets.only(left: Neon.s1, bottom: 10),
            child: Row(
              children: [
                Flexible(
                  child: Text('Price Compare',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: NeonType.manrope(21, FontWeight.w800).copyWith(color: Neon.textHi, letterSpacing: -0.6)),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Neon.success.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Neon.success.withValues(alpha: 0.4)),
                  ),
                  child: Text('SAVE MORE',
                      style: NeonType.manrope(10, FontWeight.w800).copyWith(color: Neon.success, letterSpacing: 1.2)),
                ),
              ],
            ),
          ),
        ),
        // 2026-11-07 (Manish): everything under the heading — banner,
        // search, the six compares and the alerts strip — sits in one card.
        GlassCard(
          padding: const EdgeInsets.all(Neon.s3),
          radius: Neon.rXl,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Owner, 2026-11-14: products only — the hero, the Product
              // Compare card and the alerts strip (as on hardening).
              // Owner, 2026-11-24: the Smart Shopping banner is gone; the
              // Product Compare card carries the search, the camera and the
              // mic.
              PriceCategoryShowcase(
                onTap: (c) => _open(category: c, focus: true),
                onSearch: () => _open(focus: true),
                onCamera: () => _open(camera: true),
                // The mic talks as the Price Compare assistant here on
                // Home; the everyday assistant is back when it ends.
                mic: RoleMicOrb(
                  role: priceCompareRole,
                  tint: Neon.violet,
                  size: 34,
                  showLabel: false,
                  endOnDispose: false,
                  resetRoleWhenDone: true,
                  topic: 'prices',
                  openingNote: () => priceMicNote,
                ),
              ),
              const SizedBox(height: 14),
              _insights(hit),
            ],
          ),
        ),
      ],
    );
  }

  /// BuyHatke's "Instant price insights" strip: the alerts.
  Widget _insights(List<PriceWatch> hit) {
    final watches = svc.watches;
    final (title, line) = hit.isNotEmpty
        ? (
            hit.length == 1 ? 'Price Dropped' : '${hit.length} Prices Dropped',
            hit.length == 1
                ? '${hit.first.product} has reached your target price.'
                : 'Your price alerts have reached their targets.'
          )
        : watches.isNotEmpty
            ? ('Price Drop Alerts', '${watches.length} alert${watches.length == 1 ? '' : 's'} active')
            : ('Price History & Drop Alerts', 'Buy now or wait — the AI recommends');
    final tint = hit.isNotEmpty ? Neon.success : Neon.cyan;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(Neon.rLg),
        onTap: () => _open(),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Neon.rLg),
            color: Color.alphaBlend(tint.withValues(alpha: Neon.isDark ? 0.16 : 0.12), Neon.glassFill.colors.first),
            border: Border.all(color: tint.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              Icon(hit.isNotEmpty ? Icons.trending_down_rounded : Icons.insights_rounded, color: tint, size: 30),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: NeonType.manrope(15, FontWeight.w800).copyWith(color: Neon.textHi)),
                    const SizedBox(height: 2),
                    Text(line,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Neon.textLo, fontSize: 12.5)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.fromLTRB(14, 7, 8, 7),
                decoration: BoxDecoration(color: Neon.accentFill, borderRadius: BorderRadius.circular(Neon.rPill)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('View', style: NeonType.manrope(13.5, FontWeight.w800).copyWith(color: Colors.white)),
                    const SizedBox(width: 6),
                    const Icon(Icons.play_circle_fill_rounded, size: 18, color: Colors.white),
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
