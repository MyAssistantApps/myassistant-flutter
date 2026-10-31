import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design/motion.dart';
import '../design/neon_tokens.dart';
import '../ai/types.dart' show AgentTurn;
import '../features/assistant/state/assistant_engine.dart';
import '../design/neon_fonts.dart';
import '../services/assistant_identity.dart';

/// One of the assistant's agents, as the owner sees it. The ids match the
/// server's specialists (backend src/agents/manager.js).
class AgentInfo {
  const AgentInfo(this.id, this.label, this.icon, this.blurb, [this.short]);
  final String id;
  final String label;
  final IconData icon;
  final String blurb;

  /// The chip's word in the hand-off lane.
  final String? short;
  String get chip => short ?? label;
}

AgentInfo? agentById(String id) {
  for (final a in agentRoster) {
    if (a.id == id) return a;
  }
  return null;
}

/// The manager first, then the nine specialists it hands turns to.
const agentRoster = <AgentInfo>[
  AgentInfo('manager', 'Manager', Icons.hub_rounded,
      'Reads each request and decides which agents handle it.', 'Manager'),
  AgentInfo('comms', 'Communication', Icons.forum_rounded, 'Calls, messages, WhatsApp and email.',
      'Comms'),
  AgentInfo('planner', 'Planning', Icons.event_note_rounded,
      'Reminders, calendar, alarms, timers and your day.'),
  AgentInfo('info', 'Information', Icons.travel_explore_rounded,
      'Search, news, weather, places, law and travel.', 'Info'),
  AgentInfo('commerce', 'Shopping and money', Icons.shopping_bag_rounded,
      'Shopping list, orders, rides, recharges and payments.', 'Shopping'),
  AgentInfo('creative', 'Creative', Icons.palette_rounded,
      'Images, video, photo edits, documents and music.'),
  AgentInfo('device', 'Phone control', Icons.tune_rounded,
      'Settings, apps, the camera, screenshots and shortcuts.', 'Phone'),
  AgentInfo('memory', 'Memory', Icons.psychology_rounded,
      'What to remember or forget about you and your people.'),
  AgentInfo('records', 'Records', Icons.folder_copy_rounded,
      'Saved documents, record books, cases and clients.'),
  AgentInfo('design', 'Design', Icons.brush_rounded,
      'How this app looks: colours, cards, fonts, Home layout and new cards.'),
];

/// THE AGENTS, ON SCREEN (2026-10-31).
///
/// All ten agents in one row. Idle ones sit dim and take a slow breath
/// every few seconds — available, not in use. When a turn starts, the
/// manager and the specialists it chose light up, and the one running a
/// tool pulses. Tap for the list of who does what.
///
/// Battery: idle, the animation runs one 1.6 s breath every ~5 s rather
/// than a 60 fps loop; it runs continuously only while agents work, and
/// never with "Remove animations" on.
class AgentStrip extends StatefulWidget {
  const AgentStrip({super.key});

  @override
  State<AgentStrip> createState() => _AgentStripState();
}

class _AgentStripState extends State<AgentStrip> with TickerProviderStateMixin {
  final engine = AssistantEngine.instance;
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  Timer? _idle;
  bool _still = false;

  @override
  void initState() {
    super.initState();
    engine.agentControl.addListener(_onControl);
    _onControl();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = Motion.reduced(context);
    _schedule();
  }

  @override
  void dispose() {
    engine.agentControl.removeListener(_onControl);
    _idle?.cancel();
    _breath.dispose();
    _pulse.dispose();
    super.dispose();
  }

  bool get _working => engine.agentControl.value != null;

  void _onControl() {
    if (!mounted) return;
    setState(() {});
    _schedule();
  }

  /// Working: the pulse loops. Idle: one breath now and then.
  void _schedule() {
    _idle?.cancel();
    if (_still) {
      _breath.stop();
      _pulse.stop();
      return;
    }
    if (_working) {
      if (!_pulse.isAnimating) _pulse.repeat();
      return;
    }
    _pulse.stop();
    _pulse.value = 0;
    void breathe() {
      if (!mounted || _working) return;
      unawaited(_breath.forward(from: 0));
    }
    breathe();
    _idle = Timer.periodic(const Duration(milliseconds: 5200), (_) => breathe());
  }

  /// Agent id -> its state this moment.
  _AgentState _stateOf(String id) {
    final held = engine.agentControl.value;
    if (held == null) return _AgentState.idle;
    if (id == 'manager') return held.running == null ? _AgentState.running : _AgentState.active;
    final chosen = held.control.agents.where((a) => a.id == id);
    if (chosen.isEmpty) return _AgentState.idle;
    return held.running == chosen.first.label ? _AgentState.running : _AgentState.active;
  }

  String get _caption {
    final held = engine.agentControl.value;
    if (held == null) return '${agentRoster.length} agents ready';
    if (held.running != null) return '${held.running} agent working';
    return held.control.summary;
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Your assistant\'s agents. $_caption. Tap to see what each one does.',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => showAgentSheet(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_awesome_rounded, size: 13, color: _working ? Neon.violet : Neon.textLo),
                  const SizedBox(width: 6),
                  Flexible(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Text(
                        _caption,
                        key: ValueKey(_caption),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: displayFont(
                          color: _working ? Neon.violet : Neon.textLo,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              RepaintBoundary(
                child: LayoutBuilder(
                  builder: (context, box) {
                    // Nine across, sized to the width (never wider than 36).
                    final size = math.min(36.0, (box.maxWidth - 8 * 6) / agentRoster.length);
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        for (var i = 0; i < agentRoster.length; i++)
                          _AgentDot(
                            agent: agentRoster[i],
                            state: _stateOf(agentRoster[i].id),
                            size: size,
                            breath: _breath,
                            pulse: _pulse,
                            // Each idle agent breathes a beat after the last.
                            offset: i / agentRoster.length,
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _AgentState { idle, active, running }

class _AgentDot extends StatelessWidget {
  const _AgentDot({
    required this.agent,
    required this.state,
    required this.size,
    required this.breath,
    required this.pulse,
    required this.offset,
  });

  final AgentInfo agent;
  final _AgentState state;
  final double size;
  final Animation<double> breath;
  final Animation<double> pulse;
  final double offset;

  @override
  Widget build(BuildContext context) {
    final lit = state != _AgentState.idle;
    return Tooltip(
      message: agent.label,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Motion.easeMove,
        width: size,
        height: size,
        child: CustomPaint(
          painter: _DotPainter(
            breath: breath,
            pulse: pulse,
            state: state,
            offset: offset,
            accent: Neon.violet,
            idle: Neon.textLo,
            track: Neon.line,
            fill: Neon.surface,
          ),
          child: Center(
            child: Icon(
              agent.icon,
              size: size * 0.48,
              color: lit ? Neon.violet : Neon.textLo.withValues(alpha: 0.75),
            ),
          ),
        ),
      ),
    );
  }
}

/// The dot's ring: a faint track idle (breathing a little brighter once in
/// a while), a solid ring when chosen, and an expanding ring when running.
class _DotPainter extends CustomPainter {
  _DotPainter({
    required this.breath,
    required this.pulse,
    required this.state,
    required this.offset,
    required this.accent,
    required this.idle,
    required this.track,
    required this.fill,
  }) : super(repaint: Listenable.merge([breath, pulse]));

  final Animation<double> breath;
  final Animation<double> pulse;
  final _AgentState state;
  final double offset;
  final Color accent;
  final Color idle;
  final Color track;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 1.5;
    canvas.drawCircle(c, r, Paint()..color = fill);
    switch (state) {
      case _AgentState.idle:
        // A wave across the row: each dot peaks a little after the last.
        final t = ((breath.value - offset * 0.5) / 0.5).clamp(0.0, 1.0);
        final glow = math.sin(t * math.pi);
        canvas.drawCircle(
          c,
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..color = Color.lerp(track, idle, glow * 0.8)!,
        );
      case _AgentState.active:
        canvas.drawCircle(
          c,
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.8
            ..color = accent,
        );
      case _AgentState.running:
        canvas.drawCircle(
          c,
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.2
            ..color = accent,
        );
        final p = pulse.value;
        canvas.drawCircle(
          c,
          r + 1 + p * 5,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = accent.withValues(alpha: (1 - p) * 0.6),
        );
    }
  }

  @override
  bool shouldRepaint(_DotPainter o) =>
      o.state != state || o.accent != accent || o.idle != idle || o.offset != offset;
}

/// Who does what, and who is working right now.
Future<void> showAgentSheet(BuildContext context) {
  final engine = AssistantEngine.instance;
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Neon.surface,
    showDragHandle: true,
    // Tall enough for all ten without a scroll on a phone.
    isScrollControlled: true,
    builder: (_) => ValueListenableBuilder(
      valueListenable: engine.agentControl,
      builder: (context, held, _) {
        bool busy(String id) =>
            held != null && (id == 'manager' || held.control.agents.any((a) => a.id == id));
        return ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            Text(
              'Your agents',
              style: displayFont(
                color: Neon.textHi,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'The manager reads each request and hands it to the agents that know that work.',
              style: TextStyle(color: Neon.textLo, fontSize: 13.5),
            ),
            const SizedBox(height: 12),
            for (final a in agentRoster)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(a.icon, color: busy(a.id) ? Neon.violet : Neon.textLo),
                title: Text(a.label, style: TextStyle(color: Neon.textHi, fontWeight: FontWeight.w600)),
                subtitle: Text(a.blurb, style: TextStyle(color: Neon.textLo, fontSize: 12.5)),
                trailing: Text(
                  busy(a.id) ? 'Working' : 'Ready',
                  style: TextStyle(
                    color: busy(a.id) ? Neon.violet : Neon.textDim,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
}

/// THE HAND-OFF, ON SCREEN (2026-10-31): the manager, then each specialist
/// it chose — waiting (dim), working (lit, pulsing) or done (✓) — so the
/// owner watches the work move from one agent to the next.
class AgentHandoffLane extends StatelessWidget {
  const AgentHandoffLane({super.key, required this.turn, required this.pulse});

  final AgentTurn turn;
  final Animation<double> pulse;

  @override
  Widget build(BuildContext context) {
    final started = turn.over || turn.running != null || turn.done.isNotEmpty;
    // Maya hands design straight to the Designer — no manager in between.
    final lead = turn.control.via == 'maya'
        ? AgentInfo('maya', AssistantIdentity.notifier.value.trim().isEmpty ? 'Maya' : AssistantIdentity.notifier.value.trim(),
            Icons.mic_rounded, 'Your assistant.')
        : agentRoster.first;
    final chips = <Widget>[
      _HandoffChip(
        agent: lead,
        state: started ? _ChipState.done : _ChipState.working,
        pulse: pulse,
      ),
    ];
    for (final a in turn.control.agents) {
      final info = agentById(a.id);
      if (info == null) continue;
      final state = turn.done.contains(a.id)
          ? _ChipState.done
          : turn.running == a.label
              ? _ChipState.working
              : _ChipState.waiting;
      chips
        ..add(Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Icon(Icons.arrow_forward_rounded, size: 12, color: Neon.textLo),
        ))
        ..add(_HandoffChip(agent: info, state: state, pulse: pulse));
    }
    return Semantics(
      label: 'Handed from the manager to ${turn.control.agents.map((a) => a.label).join(', ')}',
      // Wraps rather than scrolls: a chip cut at the edge hid "Memory".
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 6,
        children: chips,
      ),
    );
  }
}

enum _ChipState { waiting, working, done }

class _HandoffChip extends StatelessWidget {
  const _HandoffChip({required this.agent, required this.state, required this.pulse});

  final AgentInfo agent;
  final _ChipState state;
  final Animation<double> pulse;

  @override
  Widget build(BuildContext context) {
    final working = state == _ChipState.working;
    final done = state == _ChipState.done;
    final color = done ? Neon.success : (working ? Neon.violet : Neon.textLo);
    Widget chip(double glow) => AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.fromLTRB(7, 4, 9, 4),
          decoration: BoxDecoration(
            color: working ? Neon.violet.withValues(alpha: 0.12 + 0.10 * glow) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: working ? Neon.violet : (done ? Neon.success.withValues(alpha: 0.6) : Neon.line),
              width: working ? 1.4 : 1,
            ),
            boxShadow: working
                ? [BoxShadow(color: Neon.violet.withValues(alpha: 0.35 * glow), blurRadius: 10)]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(done ? Icons.check_circle_rounded : agent.icon, size: 13, color: color),
              const SizedBox(width: 4),
              Text(
                agent.chip,
                style: displayFont(
                  color: state == _ChipState.waiting ? Neon.textLo : Neon.textHi,
                  fontSize: 11.5,
                  fontWeight: working ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ],
          ),
        );
    if (!working) return chip(0);
    return AnimatedBuilder(
      animation: pulse,
      builder: (_, __) => chip(math.sin(pulse.value * math.pi * 2).abs()),
    );
  }
}
