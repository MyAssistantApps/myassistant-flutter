import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design/apple_kit.dart';
import '../../design/neon_tokens.dart';
import '../../design/neon_widgets.dart';
import 'buses_screen.dart';
import 'flights_screen.dart';
import 'services_screen.dart';
import '../shop/shop_api.dart';
import '../shop/shop_screens.dart';

/// ─────────────────────────────────────────────────────────────────────────
///  QUICK TOOLS (owner, 2026-11-04): sliding cards on Home like Try now —
///  Flights, Buses, Groceries, Food and Misc — each opening its own page.
///  The pages are placeholders until the owner describes each one.
///  Slides every 4 s; a finger on the cards pauses it, and "Remove
///  animations" stops it. Each card carries a photo of what it is for
///  (assets/quick/*.jpg).
/// ─────────────────────────────────────────────────────────────────────────
class QuickTool {
  const QuickTool(this.id, this.title, this.line, this.icon, this.hue);
  final String id;
  final String title;
  final String line;
  final IconData icon;

  /// Degrees round the colour wheel from the accent (the aurora's own
  /// companions), so each card has its own tint.
  final double hue;
}

const quickTools = <QuickTool>[
  QuickTool('flights', 'Flights', 'Search and book flights in a few taps.',
      Icons.flight_takeoff_rounded, -58),
  QuickTool('buses', 'Buses', 'Find buses and seats for your next trip.',
      Icons.directions_bus_rounded, 52),
  QuickTool('groceries', 'Groceries', 'Order from stores near you, pay in the app.',
      Icons.shopping_basket_rounded, -86),
  QuickTool('food', 'Food', 'Order from restaurants near you, in the app.',
      Icons.restaurant_rounded, 30),
  QuickTool('misc', 'Everyday', 'Fashion, beauty, medicines, moving & more.',
      Icons.widgets_rounded, 0),
];

class QuickToolsSection extends StatefulWidget {
  const QuickToolsSection({super.key, required this.onOpen});

  /// Opens a page the way Home opens every page.
  final void Function(Widget page) onOpen;

  @override
  State<QuickToolsSection> createState() => _QuickToolsSectionState();
}

class _QuickToolsSectionState extends State<QuickToolsSection> {
  static const _every = Duration(seconds: 4);
  final _pages = PageController(viewportFraction: 0.9);
  Timer? _timer;
  int _at = 0;
  bool _held = false;

  @override
  void initState() {
    super.initState();
    _restart();
  }

  /// THE USER TOOK OVER (owner, 2026-11-04: "when the user taps or swipes
  /// a card, the auto-sliding should stop instantly"): the timer is
  /// cancelled for good and a slide already under way halts where it is.
  void _stopAuto() {
    _held = true;
    _timer?.cancel();
    if (_pages.hasClients && _pages.position.isScrollingNotifier.value) {
      _pages.jumpTo(_pages.offset);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pages.dispose();
    super.dispose();
  }

  void _restart() {
    _timer?.cancel();
    if (_held) return;
    _timer = Timer.periodic(_every, (_) => _advance());
  }

  void _advance() {
    if (!mounted || _held || !_pages.hasClients) return;
    if (MediaQuery.of(context).disableAnimations) return;
    _pages.animateToPage((_at + 1) % quickTools.length,
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeInOutCubic);
  }

  void _open(QuickTool t) {
    HapticFeedback.selectionClick();
    widget.onOpen(switch (t.id) {
      'flights' => const FlightsScreen(),
      'buses' => const BusesScreen(),
      'groceries' => const ShopHomeScreen(domain: ShopDomain.grocery),
      'food' => const ShopHomeScreen(domain: ShopDomain.food),
      'misc' => const ServicesScreen(),
      _ => QuickToolScreen(tool: t),
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
            child: Text('Quick tools',
                style: NeonType.manrope(21, FontWeight.w800)
                    .copyWith(color: Neon.textHi, letterSpacing: -0.6)),
          ),
        ),
        Listener(
          onPointerDown: (_) => _stopAuto(),
          child: SizedBox(
            height: 176,
            child: OverflowBox(
              maxWidth: MediaQuery.sizeOf(context).width,
              child: PageView.builder(
                controller: _pages,
                itemCount: quickTools.length,
                onPageChanged: (i) => setState(() => _at = i),
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: _Card(
                      tool: quickTools[i], onTap: () => _open(quickTools[i])),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < quickTools.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _at ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  color: i == _at
                      ? Neon.violet
                      : Neon.textDim.withValues(alpha: 0.45),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

Color _tintOf(QuickTool t) {
  final h = HSLColor.fromColor(Neon.violet);
  return h
      .withHue((h.hue + t.hue) % 360)
      .withSaturation(0.85)
      .withLightness(0.58)
      .toColor();
}

/// One tool: glass tinted with its own colour, the name and what it does
/// on the left, an Open pill, and its photo on the right.
class _Card extends StatelessWidget {
  const _Card({required this.tool, required this.onTap});
  final QuickTool tool;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tint = _tintOf(tool);
    final dark = Neon.isDark;
    final r = BorderRadius.circular(Neon.rCard);
    return Semantics(
      button: true,
      label: '${tool.title}. ${tool.line}',
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: r,
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: r,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.alphaBlend(tint.withValues(alpha: dark ? 0.30 : 0.18),
                      Neon.glassFill.colors.first),
                  Color.alphaBlend(tint.withValues(alpha: dark ? 0.08 : 0.05),
                      Neon.glassFill.colors.last),
                ],
              ),
              border: Border.all(color: tint.withValues(alpha: 0.35)),
              boxShadow: Neon.glassShadow,
            ),
            child: Stack(
              children: [
                // The photo on the right, its left edge fading into the
                // card (as the assistant banners).
                Positioned(
                  top: 0,
                  bottom: 0,
                  right: 0,
                  width: 190,
                  child: ExcludeSemantics(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(Neon.rCard),
                          bottomRight: Radius.circular(Neon.rCard)),
                      child: ShaderMask(
                        blendMode: BlendMode.dstIn,
                        shaderCallback: (r) => const LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          stops: [0, 0.45, 1],
                          colors: [
                            Colors.transparent,
                            Colors.white,
                            Colors.white
                          ],
                        ).createShader(r),
                        child: Image.asset('assets/quick/${tool.id}.jpg',
                            fit: BoxFit.cover,
                            filterQuality: FilterQuality.medium,
                            gaplessPlayback: true,
                            errorBuilder: (_, __, ___) => Center(
                                child: Icon(tool.icon,
                                    size: 72,
                                    color: tint.withValues(alpha: 0.8)))),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 150, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(tool.icon, size: 18, color: tint),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(tool.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: NeonType.manrope(24, FontWeight.w800)
                                    .copyWith(
                                        color: Neon.textHi,
                                        letterSpacing: -0.6)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(tool.line,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: Neon.textLo,
                              fontSize: 13.5,
                              height: 1.35)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(Neon.rPill),
                          gradient: LinearGradient(colors: [
                            Color.lerp(Neon.accentFill, Colors.white, 0.12)!,
                            Neon.accentFill,
                          ]),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Open',
                                style: NeonType.manrope(13, FontWeight.w800)
                                    .copyWith(color: Colors.white)),
                            const SizedBox(width: 4),
                            const Icon(Icons.arrow_forward_rounded,
                                size: 16, color: Colors.white),
                          ],
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
    );
  }
}

/// A tool's own page. A placeholder until the owner describes what each
/// one does.
class QuickToolScreen extends StatelessWidget {
  const QuickToolScreen({super.key, required this.tool});
  final QuickTool tool;

  @override
  Widget build(BuildContext context) {
    final tint = _tintOf(tool);
    return NeonScaffold(
      appBar: appleAppBar(context, tool.title),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(Neon.rCard),
                child: Image.asset('assets/quick/${tool.id}.jpg',
                    width: 220,
                    height: 160,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        Icon(tool.icon, size: 96, color: tint)),
              ),
              const SizedBox(height: 18),
              Text(tool.title,
                  style: NeonType.manrope(26, FontWeight.w800)
                      .copyWith(color: Neon.textHi)),
              const SizedBox(height: 8),
              Text('Coming soon.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Neon.textLo, fontSize: 15)),
            ],
          ),
        ),
      ),
    );
  }
}
