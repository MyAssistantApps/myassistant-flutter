import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design/neon_fonts.dart';
import '../../design/neon_tokens.dart';
import '../../design/ui_spec.dart';
import '../../widgets/neon_cards.dart';
import '../assistant/state/assistant_engine.dart';

/// A HOME CARD THE DESIGN AGENT BUILT (2026-10-31): "a card with my
/// reminders today", "a water card with a button to log a glass". Its
/// blocks are only text, a list or a figure from the person's own data
/// (filled in by the server), and buttons that ask the assistant — a card
/// shows things and asks for things; it never acts by itself.
class CustomHomeCard extends StatelessWidget {
  const CustomHomeCard({super.key, required this.card});

  final UiCard card;

  @override
  Widget build(BuildContext context) {
    final accent = card.accent ?? Neon.violet;
    return GlassCard(
      wash: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, size: 16, color: accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  card.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: displayFont(
                    color: Neon.textHi,
                    fontSize: NeonType.headline,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
            ],
          ),
          for (final b in card.blocks) ...[
            const SizedBox(height: 10),
            _Block(block: b, accent: accent),
          ],
        ],
      ),
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({required this.block, required this.accent});

  final UiBlock block;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final label = block.label?.trim() ?? '';
    final small = TextStyle(color: Neon.textLo, fontSize: NeonType.footnote, fontWeight: FontWeight.w600);
    switch (block.type) {
      case 'text':
        return Text(block.value ?? '', style: TextStyle(color: Neon.textHi, fontSize: NeonType.body, height: 1.35));
      case 'stat':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (label.isNotEmpty) Text(label, style: small),
            Text(
              block.value ?? '—',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: displayFont(color: Neon.textHi, fontSize: NeonType.title3, fontWeight: FontWeight.w700),
            ),
          ],
        );
      case 'list':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (label.isNotEmpty) ...[Text(label, style: small), const SizedBox(height: 4)],
            if (block.items.isEmpty)
              Text('Nothing here right now.', style: TextStyle(color: Neon.textDim, fontSize: NeonType.body))
            else
              for (final item in block.items)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 7, right: 8),
                        child: Container(width: 5, height: 5, decoration: BoxDecoration(color: accent, shape: BoxShape.circle)),
                      ),
                      Expanded(
                        child: Text(item, style: TextStyle(color: Neon.textHi, fontSize: NeonType.body, height: 1.35)),
                      ),
                    ],
                  ),
                ),
          ],
        );
      case 'button':
        final ask = block.ask?.trim() ?? '';
        return Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: accent,
              side: BorderSide(color: accent.withValues(alpha: 0.6)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Neon.rPill)),
            ),
            onPressed: ask.isEmpty
                ? null
                : () {
                    HapticFeedback.lightImpact();
                    unawaited(AssistantEngine.instance.askAssistant(ask));
                  },
            child: Text(label.isEmpty ? ask : label, style: bodyFont(fontWeight: FontWeight.w700)),
          ),
        );
    }
    return const SizedBox.shrink();
  }
}
