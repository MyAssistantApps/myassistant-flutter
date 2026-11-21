import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design/neon_tokens.dart';
import 'flight_search_screen.dart';
import 'hotel_search_screen.dart';
import 'price_compare_screen.dart';
import 'price_models.dart';
import 'price_service.dart';
import '../../widgets/neon_cards.dart';
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

  void _open({PriceCategory category = PriceCategory.shopping, bool focus = false, bool paste = false}) {
    HapticFeedback.selectionClick();
    // Flights and hotels have their own pages (dates, travellers, rooms…).
    widget.onOpen(switch (category) {
      PriceCategory.flights => const FlightSearchScreen(),
      PriceCategory.hotels => const HotelSearchScreen(),
      _ => PriceCompareScreen(category: category, focus: focus, paste: paste),
    });
  }

  @override
  Widget build(BuildContext context) {
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
                  child: Text('Price compare',
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
              // 2026-11-09 (owner): the category tiles (product compare,
              // flights, hotels, rides, grocery) and the price history &
              // drop alerts strip are removed from Home.
              PriceHeroBanner(onSearch: () => _open(focus: true), onPaste: () => _open(paste: true)),
              // 2026-11-09 (owner): a small row for just flights and hotels.
              const SizedBox(height: 14),
              PriceCategoryShowcase(
                only: const [PriceCategory.flights, PriceCategory.hotels],
                onTap: (c) => _open(category: c, focus: true),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
