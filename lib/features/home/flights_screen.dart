import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design/apple_kit.dart';
import '../../design/neon_tokens.dart';
import '../../design/neon_widgets.dart';
import 'flight_search.dart';
import 'premium_photo_card.dart';

/// ─────────────────────────────────────────────────────────────────────────
///  FLIGHTS (owner, 2026-11-04): two large cards, one under the other —
///  Domestic (an Air India A350) and International (an Emirates A380) —
///  each opening its own page (to be described by the owner).
///  Photos: assets/flights/ (Wikimedia Commons, see CREDITS.md).
/// ─────────────────────────────────────────────────────────────────────────
enum FlightKind { domestic, international }

extension FlightKindText on FlightKind {
  String get title =>
      this == FlightKind.domestic ? 'Domestic' : 'International';
  String get line => this == FlightKind.domestic
      ? 'Flights within India'
      : 'Fly anywhere in the world';
  String get photo => 'assets/flights/$name.jpg';
  String get headline =>
      this == FlightKind.domestic ? 'Across India' : 'Around the world';
  String get tag => this == FlightKind.domestic ? 'DOMESTIC' : 'INTERNATIONAL';

  /// Where each photo is anchored so the aircraft stays in view.
  Alignment get focus => this == FlightKind.domestic
      ? const Alignment(-0.2, -0.3)
      : const Alignment(0.1, 0);
  IconData get icon => this == FlightKind.domestic
      ? Icons.flight_rounded
      : Icons.public_rounded;
}

class FlightsScreen extends StatelessWidget {
  const FlightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return NeonScaffold(
      appBar: appleAppBar(context, 'Flights'),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
            16, 8, 16, 24 + MediaQuery.paddingOf(context).bottom),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Where to next?',
                    style: NeonType.manrope(30, FontWeight.w800).copyWith(
                        color: Neon.textHi, letterSpacing: -0.8)),
                const SizedBox(height: 4),
                Text('Pick how far you are flying.',
                    style: TextStyle(color: Neon.textLo, fontSize: 15)),
              ],
            ),
          ),
          for (final k in FlightKind.values) ...[
            PremiumPhotoCard(
              photo: k.photo,
              focus: k.focus,
              tag: k.tag,
              tagIcon: k.icon,
              headline: k.headline,
              line: k.line,
              footer: const _FlightPath(),
              onTap: () {
                HapticFeedback.selectionClick();
                Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => FlightSearchScreen(kind: k)));
              },
            ),
            const SizedBox(height: 18),
          ],
        ],
      ),
    );
  }
}

/// dot ─ ─ ─ ✈ ─ ─ ─ dot: a decorative flight path.
class _FlightPath extends StatelessWidget {
  const _FlightPath();

  @override
  Widget build(BuildContext context) {
    Widget dot(bool filled) => Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? Colors.white : Colors.transparent,
            border: Border.all(color: Colors.white, width: 1.6),
          ),
        );
    Widget dashes() => Expanded(
          child: LayoutBuilder(
            builder: (_, box) {
              final n = (box.maxWidth / 9).floor();
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (var i = 0; i < n; i++)
                    Container(
                        width: 4,
                        height: 1.6,
                        color: Colors.white.withValues(alpha: 0.6)),
                ],
              );
            },
          ),
        );
    return Row(
      children: [
        dot(true),
        const SizedBox(width: 6),
        dashes(),
        const SizedBox(width: 6),
        Transform.rotate(
          angle: 1.5708,
          child: const Icon(Icons.flight_rounded,
              color: Colors.white, size: 20),
        ),
        const SizedBox(width: 6),
        dashes(),
        const SizedBox(width: 6),
        dot(false),
      ],
    );
  }
}
