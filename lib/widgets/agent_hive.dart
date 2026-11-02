import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart' show kTouchSlop;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:google_fonts/google_fonts.dart';

import '../ai/types.dart' show AgentTurn;
import '../design/motion.dart';
import '../design/neon_tokens.dart';
import '../features/assistant/state/assistant_engine.dart';
import 'agent_strip.dart';

/// ─────────────────────────────────────────────────────────────────────────
///  THE AGENTS, BEHIND ONE BUTTON (2026-11-01, juniors UI pass).
///
///  The row of nine dots on Home is gone (the client didn't like it). In
///  its place: one glowing hexagon in the Home header.
///
///   * HOLD it: a ring of light traces round the hexagon; when it closes,
///     the nine agents fly out of the button into a honeycomb — the
///     manager in the middle, the eight specialists around it.
///   * TAP it: the same "Your agents" list the row opened (showAgentSheet).
///
///  Live, as the row was: while a turn runs the button glows and pulses,
///  and in the honeycomb the manager and the chosen agents light up, the
///  one running a tool pulsing. Reads AssistantEngine.agentControl only —
///  it changes nothing.
/// ─────────────────────────────────────────────────────────────────────────

/// How long the finger stays down before the honeycomb opens.
const _holdTime = Duration(milliseconds: 420);

/// A pointy-top hexagon filling [r] (slightly rounded corners).
Path hexPath(Rect r, {double corner = 0.12}) {
  final c = r.center;
  final rad = math.min(r.width, r.height) / 2;
  final pts = [
    for (var i = 0; i < 6; i++)
      c + Offset.fromDirection(-math.pi / 2 + i * math.pi / 3, rad),
  ];
  final path = Path();
  for (var i = 0; i < 6; i++) {
    final p = pts[i];
    final prev = pts[(i + 5) % 6];
    final next = pts[(i + 1) % 6];
    final a = Offset.lerp(p, prev, corner)!;
    final b = Offset.lerp(p, next, corner)!;
    if (i == 0) {
      path.moveTo(a.dx, a.dy);
    } else {
      path.lineTo(a.dx, a.dy);
    }
    path.quadraticBezierTo(p.dx, p.dy, b.dx, b.dy);
  }
  return path..close();
}

enum _HiveState { idle, active, running }

_HiveState _stateOf(AgentTurn? held, String id) {
  if (held == null) return _HiveState.idle;
  if (id == 'manager') {
    return held.running == null ? _HiveState.running : _HiveState.active;
  }
  final chosen = held.control.agents.where((a) => a.id == id);
  if (chosen.isEmpty) return _HiveState.idle;
  return held.running == chosen.first.label
      ? _HiveState.running
      : _HiveState.active;
}

// ═════════════════════════════════════════════════════════════════════════
//  THE BUTTON
// ═════════════════════════════════════════════════════════════════════════

class AgentHiveButton extends StatefulWidget {
  const AgentHiveButton({super.key, this.size = 48});
  final double size;

  @override
  State<AgentHiveButton> createState() => _AgentHiveButtonState();
}

class _AgentHiveButtonState extends State<AgentHiveButton>
    with TickerProviderStateMixin {
  final _engine = AssistantEngine.instance;

  /// 0 → 1 while the finger is held; 1 opens the honeycomb.
  late final AnimationController _hold =
      AnimationController(vsync: this, duration: _holdTime)
        ..addStatusListener(_onHoldStatus);

  /// The slow shimmer round the rim (idle) / the pulse (agents working).
  late final AnimationController _glow = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 4200));

  bool _opened = false;
  bool _still = false;

  @override
  void initState() {
    super.initState();
    _engine.agentControl.addListener(_onControl);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = Motion.reduced(context);
    _syncGlow();
  }

  @override
  void dispose() {
    _engine.agentControl.removeListener(_onControl);
    _hold.dispose();
    _glow.dispose();
    super.dispose();
  }

  void _onControl() {
    if (!mounted) return;
    setState(() {});
    _syncGlow();
  }

  void _syncGlow() {
    if (_still) {
      _glow.stop();
      _glow.value = 0;
      return;
    }
    final working = _engine.agentControl.value != null;
    final d = Duration(milliseconds: working ? 1100 : 4200);
    if (_glow.duration != d || !_glow.isAnimating) {
      _glow.duration = d;
      _glow.repeat();
    }
  }

  void _onHoldStatus(AnimationStatus s) {
    if (s == AnimationStatus.completed && !_opened) {
      _opened = true;
      HapticFeedback.mediumImpact();
      _openHive();
    }
  }

  void _down() {
    _opened = false;
    HapticFeedback.selectionClick();
    _hold.forward(from: 0);
  }

  /// Where the finger landed; null once it lifted or turned into a scroll.
  Offset? _downAt;

  /// The finger let go (or scrolled): an unfinished ring drains away.
  void _up({required bool tapped}) {
    if (_opened) return;
    _hold.animateBack(0,
        duration: const Duration(milliseconds: 180), curve: Curves.easeOut);
  }

  Future<void> _openHive() async {
    final box = context.findRenderObject() as RenderBox?;
    final origin = box?.localToGlobal(box.size.center(Offset.zero));
    await showAgentHive(context, origin: origin);
    if (mounted) _hold.value = 0;
  }

  @override
  Widget build(BuildContext context) {
    final held = _engine.agentControl.value;
    final working = held != null;
    final count = working ? 1 + held.control.agents.length : agentRoster.length;
    final s = widget.size;
    return Semantics(
      button: true,
      label: working
          ? 'Your agents. $count working.'
          : 'Your agents. ${agentRoster.length} ready.',
      hint: 'Hold to see all nine. Tap for what each one does.',
      onLongPress: _openHive,
      child: Tooltip(
        message: 'Hold to see your agents',
        triggerMode: TooltipTriggerMode.manual,
        // The ring follows the finger itself (down → charge, up → let go),
        // so it starts the instant the finger lands; a drag past the touch
        // slop is a scroll, not a hold, and lets go. The tap is a plain
        // tap, ignored if the hold already opened the honeycomb.
        child: Listener(
          onPointerDown: (e) {
            _downAt = e.position;
            _down();
          },
          onPointerMove: (e) {
            final at = _downAt;
            if (at != null && (e.position - at).distance > kTouchSlop) {
              _downAt = null;
              _up(tapped: false);
            }
          },
          onPointerUp: (_) {
            if (_downAt != null) _up(tapped: false);
            _downAt = null;
          },
          onPointerCancel: (_) {
            _downAt = null;
            _up(tapped: false);
          },
          child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (!_opened) showAgentSheet(context);
          },
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: Listenable.merge([_hold, _glow]),
              builder: (context, _) {
                final h = Curves.easeOut.transform(_hold.value);
                return Transform.scale(
                  // Sinks a little as it charges, then springs as it opens.
                  scale: 1 - 0.08 * h,
                  child: SizedBox(
                    width: s,
                    height: s,
                    child: CustomPaint(
                      painter: _ButtonPainter(
                        hold: _hold.value,
                        glow: _glow.value,
                        working: working,
                        pink: Neon.pink,
                        violet: Neon.violet,
                        fill: Neon.surface,
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        clipBehavior: Clip.none,
                        children: [
                          Icon(Icons.hive_rounded,
                              size: s * 0.46,
                              color: Color.lerp(
                                  Colors.white, Neon.pink, 0.15 + 0.35 * h)),
                          // How many: 9 ready, or how many are on it now.
                          Positioned(
                            right: -2,
                            top: -2,
                            child: _Badge(count: count, working: working),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.count, required this.working});
  final int count;
  final bool working;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      constraints: const BoxConstraints(minWidth: 18),
      height: 18,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9),
        gradient: LinearGradient(colors: [Neon.pink, Neon.violet]),
        border: Border.all(color: Colors.white.withValues(alpha: 0.7), width: 1),
        boxShadow: Neon.halo(Neon.pink, strength: working ? 0.9 : 0.4),
      ),
      child: Text(
        '$count',
        style: GoogleFonts.interTight(
          color: Colors.white,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
    );
  }
}

class _ButtonPainter extends CustomPainter {
  _ButtonPainter({
    required this.hold,
    required this.glow,
    required this.working,
    required this.pink,
    required this.violet,
    required this.fill,
  });

  final double hold, glow;
  final bool working;
  final Color pink, violet, fill;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final hex = hexPath(rect.deflate(2));

    // Its own light: a soft pink bloom, brighter while agents work.
    final pulse = working ? 0.5 + 0.5 * math.sin(glow * math.pi * 2) : 0.0;
    canvas.drawPath(
      hex,
      Paint()
        ..color = pink.withValues(alpha: 0.28 + 0.30 * pulse + 0.25 * hold)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 10 + 6 * pulse),
    );

    // The glass: violet into plum, lit from the top-left.
    canvas.drawPath(
      hex,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(pink.withValues(alpha: 0.35), violet),
            Color.alphaBlend(violet.withValues(alpha: 0.35), fill),
          ],
        ).createShader(rect),
    );
    // A sheen across the top half.
    canvas.drawPath(
      hex,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.center,
          colors: [
            Colors.white.withValues(alpha: 0.28),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(rect),
    );

    // The rim: a slow sweep of light round the edge.
    canvas.drawPath(
      hex,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..shader = SweepGradient(
          transform: GradientRotation(glow * math.pi * 2),
          colors: [
            Colors.white.withValues(alpha: 0.85),
            pink.withValues(alpha: 0.6),
            violet.withValues(alpha: 0.3),
            pink.withValues(alpha: 0.6),
            Colors.white.withValues(alpha: 0.85),
          ],
        ).createShader(rect),
    );

    // Working: a ring of light breathing out from the edge.
    if (working) {
      final grow = 1 + 0.22 * glow;
      canvas.save();
      canvas.translate(size.width / 2, size.height / 2);
      canvas.scale(grow);
      canvas.translate(-size.width / 2, -size.height / 2);
      canvas.drawPath(
        hex,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = pink.withValues(alpha: (1 - glow) * 0.7),
      );
      canvas.restore();
    }

    // THE HOLD: a bright line tracing round the hexagon as it charges.
    if (hold > 0) {
      final ring = hexPath(rect.inflate(3));
      final metric = ring.computeMetrics().first;
      final part = metric.extractPath(0, metric.length * hold);
      canvas.drawPath(
        part,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round
          ..color = pink.withValues(alpha: 0.55)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      canvas.drawPath(
        part,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..strokeCap = StrokeCap.round
          ..color = Colors.white,
      );
    }
  }

  @override
  bool shouldRepaint(_ButtonPainter o) =>
      o.hold != hold ||
      o.glow != glow ||
      o.working != working ||
      o.pink != pink ||
      o.violet != violet ||
      o.fill != fill;
}

// ═════════════════════════════════════════════════════════════════════════
//  THE HONEYCOMB
// ═════════════════════════════════════════════════════════════════════════

/// Opens the nine agents as a honeycomb, flying out of [origin] (the
/// button's centre on screen) — or from the middle when it isn't given.
Future<void> showAgentHive(BuildContext context, {Offset? origin}) {
  final still = Motion.reduced(context);
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close agents',
    barrierColor: Colors.transparent,
    transitionDuration: Duration(milliseconds: still ? 150 : 620),
    // Material gives the comb's words the app's text style (without it a
    // dialog route draws them in the debug yellow-underlined fallback).
    pageBuilder: (context, animation, _) => Material(
      type: MaterialType.transparency,
      child: _Hive(animation: animation, origin: origin, still: still),
    ),
  );
}

class _Hive extends StatefulWidget {
  const _Hive({required this.animation, required this.origin, required this.still});
  final Animation<double> animation;
  final Offset? origin;
  final bool still;

  @override
  State<_Hive> createState() => _HiveState2();
}

class _HiveState2 extends State<_Hive> with SingleTickerProviderStateMixin {
  final _engine = AssistantEngine.instance;
  late final AnimationController _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100));
  String? _picked;

  @override
  void initState() {
    super.initState();
    if (!widget.still) _pulse.repeat();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _close() => Navigator.of(context).maybePop();

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final screen = mq.size;
    // The comb sits a little above the middle; the picked agent's card
    // goes underneath it.
    final centre = Offset(screen.width / 2, screen.height * 0.43);
    final origin = widget.origin ?? centre;
    // Sized to the phone: two rings of hexes must fit across.
    final unit = math.min(1.0, (screen.width - 24) / 344);
    final big = 92.0 * unit, small = 78.0 * unit;
    final radius = 132.0 * unit;

    final cells = <({AgentInfo agent, Offset at, double size, int order})>[
      (agent: agentRoster.first, at: centre, size: big, order: 0),
      for (var i = 1; i < agentRoster.length; i++)
        (
          agent: agentRoster[i],
          at: centre +
              Offset.fromDirection(
                  -math.pi / 2 + (i - 1) * (2 * math.pi / (agentRoster.length - 1)),
                  radius),
          size: small,
          order: i,
        ),
    ];

    return AnimatedBuilder(
      animation: widget.animation,
      builder: (context, _) {
        final t = widget.animation.value;
        final fade = Curves.easeOut.transform(t.clamp(0.0, 1.0));
        return Stack(
          children: [
            // The page behind dims and softens.
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _close,
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 14 * fade, sigmaY: 14 * fade),
                  child: ColoredBox(
                    color: Color.alphaBlend(
                      Neon.violet.withValues(alpha: 0.10),
                      Neon.scrim,
                    ).withValues(alpha: 0.75 * fade),
                  ),
                ),
              ),
            ),
            ValueListenableBuilder<AgentTurn?>(
              valueListenable: _engine.agentControl,
              builder: (context, held, _) {
                return Stack(
                  children: [
                    // The spokes: light running from the manager out.
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _SpokePainter(
                            centre: centre,
                            ends: [for (final c in cells.skip(1)) c.at],
                            lit: [
                              for (final c in cells.skip(1))
                                _stateOf(held, c.agent.id) != _HiveState.idle
                            ],
                            progress: Curves.easeOutCubic
                                .transform(((t - 0.25) / 0.75).clamp(0.0, 1.0)),
                            pulse: _pulse,
                            pink: Neon.pink,
                            violet: Neon.violet,
                          ),
                        ),
                      ),
                    ),
                    for (final c in cells)
                      _flying(
                        t: t,
                        origin: origin,
                        cell: c,
                        state: _stateOf(held, c.agent.id),
                      ),
                    // The title above and the picked agent's card below.
                    Positioned(
                      left: 24,
                      right: 24,
                      top: centre.dy - radius - small / 2 - 74 * unit,
                      child: Opacity(
                        opacity: fade,
                        child: _Heading(held: held),
                      ),
                    ),
                    Positioned(
                      left: 20,
                      right: 20,
                      top: centre.dy + radius + small / 2 + 22 * unit,
                      child: Opacity(
                        opacity: fade,
                        child: _Details(
                          agent: _picked == null ? null : agentById(_picked!),
                          state: _picked == null
                              ? _HiveState.idle
                              : _stateOf(held, _picked!),
                          onAll: () {
                            final nav = Navigator.of(context);
                            nav.pop();
                            showAgentSheet(nav.context);
                          },
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }

  /// One hex, flying from the button to its place in the comb: the
  /// manager first, the others a beat after one another, overshooting a
  /// touch as they land.
  Widget _flying({
    required double t,
    required Offset origin,
    required ({AgentInfo agent, Offset at, double size, int order}) cell,
    required _HiveState state,
  }) {
    final start = widget.still ? 0.0 : cell.order * 0.045;
    final local = ((t - start) / (1 - start)).clamp(0.0, 1.0);
    final move = widget.still ? 1.0 : Curves.easeOutBack.transform(local);
    final grow = widget.still ? 1.0 : Curves.easeOutCubic.transform(local);
    final at = Offset.lerp(origin, cell.at, move)!;
    final size = cell.size;
    return Positioned(
      left: at.dx - size / 2,
      top: at.dy - size / 2,
      width: size,
      height: size,
      child: Opacity(
        opacity: local.clamp(0.0, 1.0),
        child: Transform.rotate(
          angle: widget.still ? 0 : (1 - grow) * -0.9,
          child: Transform.scale(
            scale: 0.25 + 0.75 * grow,
            child: _HexCell(
              agent: cell.agent,
              state: state,
              picked: _picked == cell.agent.id,
              pulse: _pulse,
              centre: cell.order == 0,
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _picked =
                    _picked == cell.agent.id ? null : cell.agent.id);
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _HexCell extends StatelessWidget {
  const _HexCell({
    required this.agent,
    required this.state,
    required this.picked,
    required this.pulse,
    required this.centre,
    required this.onTap,
  });

  final AgentInfo agent;
  final _HiveState state;
  final bool picked;
  final Animation<double> pulse;
  final bool centre;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lit = state != _HiveState.idle;
    return Semantics(
      button: true,
      selected: picked,
      label: '${agent.label}. ${lit ? 'Working' : 'Ready'}.',
      child: GestureDetector(
        onTap: onTap,
        child: LayoutBuilder(builder: (context, box) {
          final s = box.maxWidth;
          return CustomPaint(
            painter: _HexPainter(
              pulse: pulse,
              state: state,
              picked: picked,
              centre: centre,
              pink: Neon.pink,
              violet: Neon.violet,
              fill: Neon.surface,
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: s * 0.12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(agent.icon,
                      size: s * (centre ? 0.34 : 0.32),
                      color: lit || picked || centre
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.85)),
                  SizedBox(height: s * 0.04),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      agent.chip,
                      maxLines: 1,
                      style: GoogleFonts.interTight(
                        color: Colors.white,
                        fontSize: centre ? 12.5 : 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _HexPainter extends CustomPainter {
  _HexPainter({
    required this.pulse,
    required this.state,
    required this.picked,
    required this.centre,
    required this.pink,
    required this.violet,
    required this.fill,
  }) : super(repaint: state == _HiveState.running ? pulse : null);

  final Animation<double> pulse;
  final _HiveState state;
  final bool picked, centre;
  final Color pink, violet, fill;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final hex = hexPath(rect.deflate(3));
    final lit = state != _HiveState.idle;
    final hot = lit || picked || centre;

    // Glow under the cell.
    canvas.drawPath(
      hex,
      Paint()
        ..color = pink.withValues(alpha: hot ? 0.55 : 0.22)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, hot ? 14 : 8),
    );
    // The glass.
    canvas.drawPath(
      hex,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: hot
              ? [
                  Color.alphaBlend(pink.withValues(alpha: 0.55), violet),
                  Color.alphaBlend(violet.withValues(alpha: 0.55), fill),
                ]
              : [
                  Color.alphaBlend(violet.withValues(alpha: 0.38), fill),
                  Color.alphaBlend(violet.withValues(alpha: 0.14), fill),
                ],
        ).createShader(rect),
    );
    canvas.drawPath(
      hex,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.center,
          colors: [
            Colors.white.withValues(alpha: 0.22),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(rect),
    );
    canvas.drawPath(
      hex,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = picked ? 2.4 : 1.3
        ..color = picked
            ? Colors.white
            : (hot ? Colors.white.withValues(alpha: 0.6) : pink.withValues(alpha: 0.45)),
    );

    // Running a tool: a ring breathing out.
    if (state == _HiveState.running) {
      final p = pulse.value;
      canvas.save();
      canvas.translate(size.width / 2, size.height / 2);
      canvas.scale(1 + 0.25 * p);
      canvas.translate(-size.width / 2, -size.height / 2);
      canvas.drawPath(
        hex,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = pink.withValues(alpha: (1 - p) * 0.8),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_HexPainter o) =>
      o.state != state ||
      o.picked != picked ||
      o.centre != centre ||
      o.pink != pink ||
      o.violet != violet ||
      o.fill != fill;
}

class _SpokePainter extends CustomPainter {
  _SpokePainter({
    required this.centre,
    required this.ends,
    required this.lit,
    required this.progress,
    required this.pulse,
    required this.pink,
    required this.violet,
  }) : super(repaint: pulse);

  final Offset centre;
  final List<Offset> ends;
  final List<bool> lit;
  final double progress;
  final Animation<double> pulse;
  final Color pink, violet;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    for (var i = 0; i < ends.length; i++) {
      final end = Offset.lerp(centre, ends[i], progress)!;
      canvas.drawLine(
        centre,
        end,
        Paint()
          ..strokeWidth = lit[i] ? 2.2 : 1.2
          ..shader = LinearGradient(colors: [
            pink.withValues(alpha: lit[i] ? 0.9 : 0.45),
            violet.withValues(alpha: lit[i] ? 0.6 : 0.15),
          ]).createShader(Rect.fromPoints(centre, ends[i])),
      );
      // A spark running out along a lit spoke.
      if (lit[i] && progress >= 1) {
        final spark = Offset.lerp(centre, ends[i], pulse.value)!;
        canvas.drawCircle(
          spark,
          3,
          Paint()
            ..color = Colors.white
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_SpokePainter o) =>
      o.progress != progress || o.centre != centre || o.lit != lit;
}

class _Heading extends StatelessWidget {
  const _Heading({required this.held});
  final AgentTurn? held;

  @override
  Widget build(BuildContext context) {
    final caption = held == null
        ? '${agentRoster.length} agents ready'
        : held!.running != null
            ? '${held!.running} agent working'
            : held!.control.summary;
    return Column(
      children: [
        Text(
          'Your agents',
          textAlign: TextAlign.center,
          style: GoogleFonts.interTight(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w700,
            shadows: [Shadow(color: Neon.pink.withValues(alpha: 0.6), blurRadius: 16)],
          ),
        ),
        const SizedBox(height: 4),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Text(
            caption,
            key: ValueKey(caption),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: held == null ? Neon.textLo : Neon.pink,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({required this.agent, required this.state, required this.onAll});
  final AgentInfo? agent;
  final _HiveState state;
  final VoidCallback onAll;

  @override
  Widget build(BuildContext context) {
    final a = agent;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween(begin: const Offset(0, 0.15), end: Offset.zero)
                  .animate(anim),
              child: child,
            ),
          ),
          child: a == null
              ? Text(
                  'Tap an agent to see what it does',
                  key: const ValueKey('hint'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Neon.textDim, fontSize: 13),
                )
              : Container(
                  key: ValueKey(a.id),
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: Neon.glassFill,
                    border: Border.all(color: Neon.lineBright),
                    boxShadow: Neon.halo(Neon.pink, strength: 0.4),
                  ),
                  child: Row(
                    children: [
                      Icon(a.icon, color: Neon.pink, size: 26),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(a.label,
                                style: TextStyle(
                                    color: Neon.textHi,
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text(a.blurb,
                                style: TextStyle(
                                    color: Neon.textLo, fontSize: 13, height: 1.3)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        state == _HiveState.idle ? 'Ready' : 'Working',
                        style: TextStyle(
                          color: state == _HiveState.idle ? Neon.textDim : Neon.pink,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: onAll,
          child: Text('See the full list',
              style: TextStyle(color: Neon.pink, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}
