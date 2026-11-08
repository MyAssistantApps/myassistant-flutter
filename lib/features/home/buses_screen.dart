import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design/apple_kit.dart';
import '../../design/neon_tokens.dart';
import '../../design/neon_widgets.dart';
import 'bus_search.dart';
import 'premium_photo_card.dart';

/// ─────────────────────────────────────────────────────────────────────────
///  BUSES (owner, 2026-11-04): Premium, Standard, Sleeper and Government
///  (State RTC) — the same premium photo cards as Flights, one under the
///  other, each opening its own page (to be described by the owner).
///  Photos: assets/buses/ (Wikimedia Commons, see CREDITS.md).
/// ─────────────────────────────────────────────────────────────────────────
enum BusKind { premium, standard, sleeper, government }

extension BusKindText on BusKind {
  String get title => switch (this) {
        BusKind.premium => 'Premium',
        BusKind.standard => 'Standard',
        BusKind.sleeper => 'Sleeper',
        BusKind.government => 'Government',
      };
  String get tag => switch (this) {
        BusKind.premium => 'PREMIUM',
        BusKind.standard => 'STANDARD',
        BusKind.sleeper => 'SLEEPER',
        BusKind.government => 'STATE RTC',
      };
  String get headline => switch (this) {
        BusKind.premium => 'Travel in luxury',
        BusKind.standard => 'Everyday travel',
        BusKind.sleeper => 'Sleep through the night',
        BusKind.government => 'Government buses',
      };
  String get line => switch (this) {
        BusKind.premium => 'Volvo & Scania multi-axle AC coaches',
        BusKind.standard => 'AC and non-AC seaters at fair prices',
        BusKind.sleeper => 'AC and non-AC sleeper berths',
        BusKind.government => 'KSRTC, MSRTC, TNSTC, APSRTC and more',
      };
  List<(IconData, String)> get features => switch (this) {
        BusKind.premium => const [
            (Icons.ac_unit_rounded, 'AC'),
            (Icons.airline_seat_recline_extra_rounded, 'Recliners'),
            (Icons.electrical_services_rounded, 'Charging'),
          ],
        BusKind.standard => const [
            (Icons.event_seat_rounded, 'Seater'),
            (Icons.ac_unit_rounded, 'AC / Non-AC'),
            (Icons.savings_rounded, 'Budget'),
          ],
        BusKind.sleeper => const [
            (Icons.bed_rounded, 'Berths'),
            (Icons.nightlight_round, 'Overnight'),
            (Icons.ac_unit_rounded, 'AC / Non-AC'),
          ],
        BusKind.government => const [
            (Icons.verified_rounded, 'Official'),
            (Icons.schedule_rounded, 'Frequent'),
            (Icons.currency_rupee_rounded, 'Low fares'),
          ],
      };
  IconData get icon => switch (this) {
        BusKind.premium => Icons.workspace_premium_rounded,
        BusKind.standard => Icons.directions_bus_rounded,
        BusKind.sleeper => Icons.bed_rounded,
        BusKind.government => Icons.account_balance_rounded,
      };
  String get photo => 'assets/buses/$name.jpg';
}

class BusesScreen extends StatelessWidget {
  const BusesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return NeonScaffold(
      appBar: appleAppBar(context, 'Buses'),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
            16, 8, 16, 24 + MediaQuery.paddingOf(context).bottom),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('How do you want to travel?',
                    style: NeonType.manrope(28, FontWeight.w800).copyWith(
                        color: Neon.textHi, letterSpacing: -0.8)),
                const SizedBox(height: 4),
                Text('Pick the kind of bus.',
                    style: TextStyle(color: Neon.textLo, fontSize: 15)),
              ],
            ),
          ),
          for (final k in BusKind.values) ...[
            PremiumPhotoCard(
              photo: k.photo,
              tag: k.tag,
              tagIcon: k.icon,
              headline: k.headline,
              line: k.line,
              footer: _Features(k.features),
              onTap: () {
                HapticFeedback.selectionClick();
                Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => BusSearchScreen(kind: k)));
              },
            ),
            const SizedBox(height: 18),
          ],
        ],
      ),
    );
  }
}

/// A row of small frosted feature chips.
class _Features extends StatelessWidget {
  const _Features(this.items);
  final List<(IconData, String)> items;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          for (final (icon, label) in items)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Colors.white.withValues(alpha: 0.14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 14, color: Colors.white),
                  const SizedBox(width: 5),
                  Text(label,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
        ],
      );
}
