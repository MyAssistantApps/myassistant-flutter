import 'package:flutter/material.dart';

import '../design/neon_tokens.dart';

/// THE GROUND THE APP SITS ON (2026-11-02, the minimal restyle): one flat
/// [Neon.bg]. The night-sky wash, pools and ribbons (shaders/ambient.frag)
/// were taken out for a calmer, quieter look; the content carries the page.
class AmbientBackground extends StatelessWidget {
  final Widget child;

  /// True while something opaque covers the whole page (the voice session).
  final bool covered;

  const AmbientBackground(
      {super.key, required this.child, this.covered = false});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Visibility.maintain(
            visible: !covered,
            child: const AmbientLight(),
          ),
        ),
        child,
      ],
    );
  }
}

/// The ground alone. A tab opening in a circle over another tab carries it
/// inside the circle (TabDeck.ground), so the tab being covered does not
/// show through.
class AmbientLight extends StatelessWidget {
  const AmbientLight({super.key});

  @override
  Widget build(BuildContext context) =>
      IgnorePointer(child: ColoredBox(color: Neon.bg));
}
