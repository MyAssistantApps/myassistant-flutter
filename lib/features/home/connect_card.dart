import 'package:flutter/material.dart';

import '../../design/motion.dart';
import '../../design/neon_tokens.dart';
import 'home_fx.dart';

/// Home's way in to the contacts' assistants (2026-11-21): "Talk to a
/// Contact's Assistant" — opens the list of people on MyAssistant. Same
/// glass card and still gradient edge as Upload Your Documents.
class ConnectCard extends StatelessWidget {
  const ConnectCard({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = Neon.violet;
    return Tappable(
      onTap: onTap,
      semanticLabel: "Talk to a Contact's Assistant",
      child: CustomPaint(
        foregroundPainter: AuroraBorderPainter(
            t: const AlwaysStoppedAnimation(0.3),
            radius: Neon.rLg,
            color: c,
            width: 1.2),
        child: Container(
          decoration: Neon.glassBox(Neon.rLg),
          padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
          child: ExcludeSemantics(
            child: Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: Neon.gBrand,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.connect_without_contact_rounded,
                    color: Neon.onBrand, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("Talk to a Contact's Assistant",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: NeonType.manrope(NeonType.body, FontWeight.w800)
                            .copyWith(color: Neon.textHi, letterSpacing: -0.2)),
                    const SizedBox(height: 2),
                    Text(
                        'Leave a message, send an urgent alert or book a time.',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Neon.textLo, fontSize: 12.5)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Neon.textDim),
            ]),
          ),
        ),
      ),
    );
  }
}
