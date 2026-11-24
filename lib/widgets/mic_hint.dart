import 'dart:async';

import 'package:flutter/material.dart';

import '../design/neon_tokens.dart';

/// THE MIC HINT (2026-11-24): a small speech bubble above the dock's mic —
/// "Tap to talk, hold for 3 seconds to customise" — that comes up once
/// soon after Home opens, then every [every] (5 minutes), and stays
/// [shownFor] each time. Not shown while [quiet] is true (a voice
/// conversation is on), so it never talks over the assistant. It ignores
/// touches: the mic under it stays fully usable.
class MicHint extends StatefulWidget {
  const MicHint({
    super.key,
    required this.child,
    required this.listenable,
    required this.quiet,
    this.text = 'Tap to talk, hold for 3 seconds to customise',
    this.every = const Duration(minutes: 5),
    this.shownFor = const Duration(milliseconds: 3000),
    this.lift = 84,
  });

  /// The mic.
  final Widget child;

  /// What [quiet] depends on (the assistant engine).
  final Listenable listenable;

  /// True while the hint must stay hidden.
  final bool Function() quiet;
  final String text;
  final Duration every;
  final Duration shownFor;

  /// How far above the mic's bottom edge the bubble's bottom sits.
  final double lift;

  @override
  State<MicHint> createState() => _MicHintState();
}

class _MicHintState extends State<MicHint> {
  Timer? _cycle;
  Timer? _hide;
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    _cycle = Timer.periodic(widget.every, (_) => _show());
    // The first one soon after Home opens, not five seconds in.
    _hide = Timer(const Duration(milliseconds: 1200), _show);
  }

  void _show() {
    if (!mounted || widget.quiet()) return;
    setState(() => _shown = true);
    _hide?.cancel();
    _hide = Timer(widget.shownFor, () {
      if (mounted) setState(() => _shown = false);
    });
  }

  @override
  void dispose() {
    _cycle?.cancel();
    _hide?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        widget.child,
        Positioned(
          bottom: widget.lift,
          child: IgnorePointer(
            child: ListenableBuilder(
              listenable: widget.listenable,
              builder: (_, bubble) {
                final on = _shown && !widget.quiet();
                return AnimatedOpacity(
                  opacity: on ? 1 : 0,
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOut,
                  child: AnimatedSlide(
                    offset: on ? Offset.zero : const Offset(0, 0.25),
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    child: bubble,
                  ),
                );
              },
              child: _Bubble(widget.text),
            ),
          ),
        ),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble(this.text);
  final String text;

  static const _fill = Color(0xFF1E1B2E);
  static const _rim = Color(0xFF8B5CF6);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width - 48),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: _fill,
            borderRadius: BorderRadius.circular(Neon.rPill),
            border: Border.all(color: _rim.withValues(alpha: 0.55)),
            boxShadow: [BoxShadow(color: _rim.withValues(alpha: 0.28), blurRadius: 16, offset: const Offset(0, 6))],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.mic_rounded, size: 15, color: Color(0xFFC4B5FD)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(text,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    style: NeonType.manrope(12.5, FontWeight.w700).copyWith(color: Colors.white, height: 1.25)),
              ),
            ],
          ),
        ),
        // The pointer down to the mic.
        CustomPaint(size: const Size(14, 7), painter: _Pointer(_fill, _rim.withValues(alpha: 0.55))),
      ],
    );
  }
}

class _Pointer extends CustomPainter {
  _Pointer(this.fill, this.rim);
  final Color fill;
  final Color rim;

  @override
  void paint(Canvas canvas, Size s) {
    final p = Path()
      ..moveTo(0, -1)
      ..lineTo(s.width / 2, s.height)
      ..lineTo(s.width, -1);
    canvas.drawPath(p, Paint()..color = fill);
    canvas.drawPath(
        p,
        Paint()
          ..color = rim
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1);
  }

  @override
  bool shouldRepaint(_Pointer old) => old.fill != fill || old.rim != rim;
}
