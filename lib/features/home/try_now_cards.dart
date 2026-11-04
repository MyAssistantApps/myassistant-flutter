import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design/neon_tokens.dart';
import 'try_on_screen.dart';

/// ─────────────────────────────────────────────────────────────────────────
///  TRY NOW (2026-11-03, owner): a slice of Style Studio on Home, as
///  sliding cards that move on by themselves — Clothes, Haircut,
///  Jewellery and Custom. Each one: upload your own photo and a reference
///  photo, add your own words if you like, and see yourself in it.
///
///  A card opens its own try-on screen (TryOnScreen): your photo, the
///  reference, your words, and the result — nothing else in between. The robot on each card is the app's own mascot, dressed for
///  the job (assets/tryon/).
///
///  Slides every 4 s; a finger on the cards pauses it, and "Remove
///  animations" stops it.
/// ─────────────────────────────────────────────────────────────────────────
class TryNowCard {
  const TryNowCard(this.recipe, this.title, this.line, this.art, this.hue,
      {required this.headline,
      required this.refLabel,
      required this.refHint,
      required this.notesHint});
  final String recipe;
  final String title;
  final String line;
  final String art;

  /// Degrees round the colour wheel from the accent: the aurora's own
  /// companions (blue, rose, teal), so the cards belong to the page.
  final double hue;

  /// The try-on screen's own words (TryOnScreen).
  final String headline;
  final String refLabel;
  final String refHint;
  final String notesHint;
}

const tryNowCards = <TryNowCard>[
  TryNowCard('outfit', 'Clothes',
      'Your photo + any outfit. See yourself wearing it.', 'clothes', 0,
      headline: 'See yourself in any outfit',
      refLabel: 'The outfit',
      refHint: 'A photo of the clothes — a shop screenshot works',
      notesHint: 'Optional — e.g. slim fit, in navy blue, for a wedding'),
  TryNowCard('hair', 'Haircut',
      'Your photo + a cut you like. Try it before the salon.', 'haircut', -58,
      headline: 'Try a haircut before the salon',
      refLabel: 'The haircut',
      refHint: 'A salon or celebrity photo of the cut you want',
      notesHint: 'Optional — e.g. a bit shorter on the sides, keep my colour'),
  TryNowCard('jewellery', 'Jewellery',
      'Your photo + a necklace or earrings. See it on you.', 'jewellery', 52,
      headline: 'See the jewellery on you',
      refLabel: 'The jewellery',
      refHint: 'A necklace, earrings, a ring — from a shop or a photo',
      notesHint: 'Optional — e.g. in rose gold, a smaller pendant'),
  TryNowCard('custom', 'Custom',
      'Your photo, any reference and your own words.', 'custom', -86,
      headline: 'Your photo, any idea',
      refLabel: 'Reference',
      refHint: 'Anything to borrow from — a look, an accessory, a place',
      notesHint: 'Tell me what to do — e.g. wear this watch, put me on this beach'),
];

class TryNowSection extends StatefulWidget {
  const TryNowSection({super.key, required this.onOpen});

  /// Opens a page the way Home opens every page.
  final void Function(Widget page) onOpen;

  @override
  State<TryNowSection> createState() => _TryNowSectionState();
}

class _TryNowSectionState extends State<TryNowSection> {
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
    final next = (_at + 1) % tryNowCards.length;
    _pages.animateToPage(next,
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeInOutCubic);
  }

  void _open(TryNowCard c) {
    HapticFeedback.selectionClick();
    // Straight into THIS try-on (owner, 2026-11-03: "when I click Clothes
    // it should not take me to AI Studio — directly Clothes").
    widget.onOpen(TryOnScreen(card: c));
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
                Text('Try now',
                    style: NeonType.manrope(21, FontWeight.w800)
                        .copyWith(color: Neon.textHi, letterSpacing: -0.6)),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Neon.violet.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: Neon.violet.withValues(alpha: 0.4)),
                  ),
                  child: Text('AI STUDIO',
                      style: NeonType.manrope(10, FontWeight.w800).copyWith(
                          color: Neon.violet, letterSpacing: 1.2)),
                ),
              ],
            ),
          ),
        ),
        // The cards run to the screen's edges, so the next one peeks in.
        Listener(
          onPointerDown: (_) => _stopAuto(),
          child: SizedBox(
            height: 176,
            child: OverflowBox(
              maxWidth: MediaQuery.sizeOf(context).width,
              child: PageView.builder(
                controller: _pages,
                padEnds: true,
                itemCount: tryNowCards.length,
                onPageChanged: (i) => setState(() => _at = i),
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: _Card(
                      card: tryNowCards[i],
                      onTap: () => _open(tryNowCards[i])),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < tryNowCards.length; i++)
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

/// One look: glass tinted with its own colour, the name and what it does
/// on the left, a Try now pill, and the dressed robot on the right.
class _Card extends StatelessWidget {
  const _Card({required this.card, required this.onTap});
  final TryNowCard card;
  final VoidCallback onTap;

  Color get _tint {
    final h = HSLColor.fromColor(Neon.violet);
    return h
        .withHue((h.hue + card.hue) % 360)
        .withSaturation(0.85)
        .withLightness(0.58)
        .toColor();
  }

  @override
  Widget build(BuildContext context) {
    final tint = _tint;
    final dark = Neon.isDark;
    final r = BorderRadius.circular(Neon.rCard);
    return Semantics(
      button: true,
      label: 'Try ${card.title}. ${card.line}',
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
              clipBehavior: Clip.none,
              children: [
                // The robot, standing in the card's right side.
                Positioned(
                  right: 4,
                  top: 6,
                  bottom: 0,
                  width: 150,
                  child: ExcludeSemantics(
                    child: Image.asset('assets/tryon/${card.art}.png',
                        fit: BoxFit.contain,
                        alignment: Alignment.bottomCenter,
                        filterQuality: FilterQuality.medium),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 150, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(card.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: NeonType.manrope(24, FontWeight.w800)
                              .copyWith(
                                  color: Neon.textHi, letterSpacing: -0.6)),
                      const SizedBox(height: 6),
                      Text(card.line,
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
                            Text('Try now',
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
