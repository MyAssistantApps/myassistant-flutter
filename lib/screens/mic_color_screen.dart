import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design/apple_kit.dart';
import '../design/neon_scaffold.dart';
import '../design/neon_tokens.dart';
import '../services/mic_color.dart';
import '../widgets/inline_voice.dart' show RingedMic;

/// THE MIC CUSTOMISATION PAGE (2026-11-24): opened by holding the dock mic
/// for 3 seconds; Done goes back to Home. A live preview of the mic and the colours to pick from;
/// the choice applies at once and is kept. Only the colour changes — the
/// mic's design stays the same.
class MicColorScreen extends StatelessWidget {
  const MicColorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = MicColorStore.instance;
    return NeonScaffold(
      appBar: appleAppBar(context, 'Customise Mic'),
      body: SafeArea(
        top: false,
        child: ValueListenableBuilder<MicColorOption>(
          valueListenable: store,
          builder: (context, chosen, _) => ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              Center(
                child: Container(
                  width: 150,
                  height: 150,
                  alignment: Alignment.center,
                  decoration: Neon.glassBox(Neon.rXl),
                  child: Transform.scale(scale: 1.35, child: RingedMic(option: chosen)),
                ),
              ),
              const SizedBox(height: 14),
              Text(chosen.label,
                  textAlign: TextAlign.center,
                  style: NeonType.manrope(NeonType.title3, FontWeight.w800).copyWith(color: Neon.textHi)),
              const SizedBox(height: 4),
              Text('Select a colour for the mic. The change applies straight away.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Neon.textLo, fontSize: NeonType.callout)),
              const SizedBox(height: 24),
              Text('Mic Colour',
                  style: NeonType.manrope(NeonType.rowTitle, FontWeight.w800).copyWith(color: Neon.textHi)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 14,
                runSpacing: 16,
                children: [
                  for (final o in MicColorStore.options)
                    _Swatch(
                      option: o,
                      selected: o.id == chosen.id,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        store.choose(o);
                      },
                    ),
                ],
              ),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  Navigator.of(context).maybePop();
                },
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  backgroundColor: Neon.accentFill,
                  foregroundColor: Neon.onAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Neon.rMd)),
                ),
                child: Text('Done', style: NeonType.manrope(NeonType.rowTitle, FontWeight.w800)),
              ),
              const SizedBox(height: 8),
              if (chosen.id != MicColorStore.options.first.id)
                Center(
                  child: TextButton.icon(
                    onPressed: () => store.choose(MicColorStore.options.first),
                    icon: const Icon(Icons.restart_alt_rounded),
                    label: const Text('Reset to Default'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.option, required this.selected, required this.onTap});
  final MicColorOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '${option.label} mic colour',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 64,
          child: Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 52,
                height: 52,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: selected ? option.ring : Colors.transparent, width: 2.4),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: option.ring,
                    boxShadow: [BoxShadow(color: option.ring.withValues(alpha: 0.4), blurRadius: 10)],
                  ),
                  child: selected
                      ? Icon(Icons.check_rounded, color: Neon.textOn(option.ring), size: 24)
                      : null,
                ),
              ),
              const SizedBox(height: 6),
              Text(option.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: selected ? Neon.textHi : Neon.textLo,
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}
