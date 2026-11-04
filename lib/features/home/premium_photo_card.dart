import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../design/neon_tokens.dart';

/// A PREMIUM PHOTO CARD (owner, 2026-11-04: "make it premium"): the
/// photo full-bleed, a frosted label and arrow on top, and the headline
/// and a little flight path at the foot, straight on the photo.
class PremiumPhotoCard extends StatelessWidget {
  const PremiumPhotoCard({
    super.key,
    required this.photo,
    required this.tag,
    required this.tagIcon,
    required this.headline,
    required this.line,
    required this.onTap,
    this.focus = Alignment.center,
    this.footer,
  });
  final String photo;
  final String tag;
  final IconData tagIcon;
  final String headline;
  final String line;
  final VoidCallback onTap;
  final Alignment focus;

  /// Under the words, e.g. a flight path or a row of features.
  final Widget? footer;

  static Widget _frost({
    required Widget child,
    required BorderRadius radius,
    EdgeInsets padding = EdgeInsets.zero,
    double alpha = 0.16,
  }) =>
      ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: radius,
              color: Colors.white.withValues(alpha: alpha),
              border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
            ),
            child: child,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(28);
    return Semantics(
      button: true,
      label: '$tag. $headline. $line',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: r,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 30,
                offset: const Offset(0, 16),
                spreadRadius: -8),
            BoxShadow(
                color: Neon.violet.withValues(alpha: 0.25),
                blurRadius: 40,
                spreadRadius: -14),
          ],
        ),
        child: AspectRatio(
          aspectRatio: 4 / 3.4,
          child: Material(
            borderRadius: r,
            clipBehavior: Clip.antiAlias,
            color: Colors.black,
            child: InkWell(
              onTap: onTap,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(photo,
                      fit: BoxFit.cover,
                      alignment: focus,
                      filterQuality: FilterQuality.medium),
                  // Depth: a touch of shade at the top for the label, a
                  // deep fall at the foot, a hint of violet across it.
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0, 0.22, 0.5, 1],
                        colors: [
                          Colors.black.withValues(alpha: 0.30),
                          Colors.transparent,
                          Colors.transparent,
                          Color.alphaBlend(
                              Neon.violet.withValues(alpha: 0.14),
                              Colors.black.withValues(alpha: 0.82)),
                        ],
                      ),
                    ),
                  ),
                  // The label and the arrow.
                  Positioned(
                    top: 14,
                    left: 14,
                    child: _frost(
                      radius: BorderRadius.circular(40),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(tagIcon, size: 15, color: Colors.white),
                          const SizedBox(width: 6),
                          Text(tag,
                              style: NeonType.manrope(11.5, FontWeight.w800)
                                  .copyWith(
                                      color: Colors.white,
                                      letterSpacing: 1.6)),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: _frost(
                      radius: BorderRadius.circular(40),
                      child: const SizedBox(
                        width: 42,
                        height: 42,
                        child: Icon(Icons.arrow_outward_rounded,
                            color: Colors.white, size: 22),
                      ),
                    ),
                  ),
                  // The words at the foot, straight on the photo — the
                  // aircraft keeps the whole card.
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 18,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(headline,
                            style: NeonType.manrope(30, FontWeight.w800)
                                .copyWith(
                                    color: Colors.white,
                                    letterSpacing: -0.8,
                                    height: 1.05,
                                    shadows: const [
                                  Shadow(blurRadius: 12, color: Colors.black54)
                                ])),
                        const SizedBox(height: 4),
                        Text(line,
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 14)),
                        if (footer != null) ...[
                          const SizedBox(height: 14),
                          footer!,
                        ],
                      ],
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

