import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../design/motion.dart';
import '../../design/neon_tokens.dart';
import 'home_fx.dart';

/// HOME'S "UPLOAD YOUR FILES" CARD (owner, 2026-11-16: renamed from "My
/// Documents"; "need wow like design and animation"). A glowing icon tile
/// with a floating upload arrow, a light travelling round the edge and a
/// sheen now and then. It slides up into place once when Home first shows.
class UploadFilesCard extends StatefulWidget {
  const UploadFilesCard({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  State<UploadFilesCard> createState() => _UploadFilesCardState();
}

class _UploadFilesCardState extends State<UploadFilesCard>
    with SingleTickerProviderStateMixin, LoopFx {
  @override
  Widget build(BuildContext context) {
    final c = Neon.violet;
    final r = BorderRadius.circular(Neon.rLg);
    return EnterOnce(
      delay: const Duration(milliseconds: 180),
      duration: const Duration(milliseconds: 520),
      rise: 18,
      scaleFrom: 0.97,
      child: Tappable(
        onTap: widget.onTap,
        semanticLabel: 'Upload Your Documents',
        child: CustomPaint(
          foregroundPainter: AuroraBorderPainter(
              t: loop, radius: Neon.rLg, color: c, cycles: 1, offset: 0.5),
          child: Container(
            decoration: Neon.glassBox(Neon.rLg),
            child: Stack(
              children: [
                Positioned.fill(
                  child: IgnorePointer(
                    child: ClipRRect(
                      borderRadius: r,
                      child: RepaintBoundary(
                        child: CustomPaint(
                            painter: ShimmerPainter(t: loop)),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
                  child: ExcludeSemantics(
                    child: Row(
                      children: [
                        _iconTile(c),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Upload Your Documents',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: NeonType.manrope(
                                          NeonType.body, FontWeight.w800)
                                      .copyWith(
                                          color: Neon.textHi,
                                          letterSpacing: -0.2)),
                              const SizedBox(height: 2),
                              Text('IDs, bills and certificates, kept secure',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      color: Neon.textLo,
                                      fontSize: 12.5,
                                      height: 1.25)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Neon.textHi.withValues(alpha: 0.07),
                            border: Border.all(
                                color: c.withValues(alpha: 0.35)),
                          ),
                          child: Icon(Icons.arrow_forward_rounded,
                              size: 16, color: Neon.textHi),
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

  Widget _iconTile(Color c) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color.lerp(c, Colors.white, 0.25)!, Neon.accentFill],
        ),
        boxShadow: [
          BoxShadow(
              color: c.withValues(alpha: 0.5),
              blurRadius: 16,
              spreadRadius: -4,
              offset: const Offset(0, 5)),
        ],
      ),
      // The arrow floats gently, like something rising to the cloud.
      child: AnimatedBuilder(
        animation: loop,
        builder: (_, child) {
          final s = math.sin(loopPhase(loop.value, 2) * 2 * math.pi);
          return Transform.translate(offset: Offset(0, -2.5 * s), child: child);
        },
        child: const Icon(Icons.cloud_upload_rounded,
            color: Colors.white, size: 24),
      ),
    );
  }
}
