import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../design/apple_kit.dart';
import '../../design/neon_tokens.dart';
import '../../design/neon_widgets.dart';
import '../../features/assistant/state/assistant_engine.dart';
import '../../services/app_feedback.dart';
import '../../services/auth_service.dart';
import '../../services/my_photo.dart';
import '../../services/workspace_service.dart';
import '../auth/photo_step_screen.dart';
import '../focus_screen.dart';

/// ─────────────────────────────────────────────────────────────────────────
///  WORKSPACE — the dashboard for every profession without a Pro workspace
///  (owner, 2026-11-21: "how we have for doctors, advocates ... the same
///  way we need for engineers ... plan our day and automate that").
///
///  One screen, top to bottom, the order a working day is used in:
///   1. Who and where: their photo, "<Profession> Workspace", today's numbers
///   2. Today's Plan: an AI time-block plan built from their real reminders,
///      promises and Today's 3 (POST /workspace/plan), or the profession's
///      typical day until they ask for one; the current block is lit
///   3. Today's Top 3 (shared with Momentum): tick, add, edit
///   4. Due Today: reminders and promises owed to people
///   5. Focus: one tap starts a session of the profession's length on the
///      top priority
///   6. Automations: the profession's routines, each one switch → a
///      repeating reminder at a time they can change
///   7. Quick Actions: profession-specific requests the assistant does
///
///  Content comes from the server's pack (src/workspace/packs.js), so a
///  new profession needs no change here.
/// ─────────────────────────────────────────────────────────────────────────
class WorkspaceScreen extends StatefulWidget {
  const WorkspaceScreen({super.key});

  @override
  State<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends State<WorkspaceScreen> {
  WorkspaceOverview? _o;
  bool _loading = true;
  bool _failed = false;
  bool _planning = false;
  final Set<String> _switching = {};
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _load();
    // The "now" marker on the plan moves with the clock.
    _tick = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final o = await WorkspaceService.load();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _failed = o == null;
      if (o != null) _o = o;
    });
  }

  Future<void> _plan({bool force = false}) async {
    if (_planning) return;
    setState(() => _planning = true);
    final p = await WorkspaceService.plan(force: force);
    if (!mounted) return;
    setState(() => _planning = false);
    if (p == null) {
      AppFeedback.show('Unable to plan your day right now. Please try again.',
          context: context);
      return;
    }
    HapticFeedback.mediumImpact();
    await _load();
  }

  Future<void> _toggle(PackRoutine r, bool on, {String? time}) async {
    if (_switching.contains(r.id)) return;
    setState(() => _switching.add(r.id));
    final o = await WorkspaceService.setRoutine(r.id, on: on, time: time);
    if (!mounted) return;
    setState(() {
      _switching.remove(r.id);
      if (o != null) _o = o;
    });
    if (o == null) {
      AppFeedback.show(
          'Unable to update the automation. Check your connection.',
          context: context);
    } else {
      HapticFeedback.selectionClick();
      AppFeedback.toast(on
          ? '${r.title} is on: ${r.when.toLowerCase()} at ${time ?? o.routines[r.id]?.time ?? r.time}.'
          : '${r.title} is off.');
    }
  }

  Future<void> _changeTime(PackRoutine r) async {
    final cur = _o?.routines[r.id]?.time ?? r.time;
    final parts = cur.split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
          hour: int.tryParse(parts.first) ?? 9,
          minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0),
    );
    if (picked == null) return;
    final t =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    await _toggle(r, true, time: t);
  }

  Future<void> _tickPriority(Priority p) async {
    final o = _o;
    if (o == null || p.id <= 0) return;
    HapticFeedback.selectionClick();
    final ok = await WorkspaceService.tickPriority(p.id, !p.done);
    if (ok) await _load();
  }

  Future<void> _editPriorities() async {
    final o = _o;
    if (o == null) return;
    final ctrls = [
      for (var i = 0; i < 3; i++)
        TextEditingController(
            text: i < o.priorities.length ? o.priorities[i].title : ''),
    ];
    final save = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Neon.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 16, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text("Today's Top 3",
                style: NeonType.manrope(19, FontWeight.w800)
                    .copyWith(color: Neon.textHi)),
            const SizedBox(height: 4),
            Text('The three things that would make today a success.',
                style: TextStyle(color: Neon.textLo, fontSize: 13.5)),
            const SizedBox(height: 14),
            for (var i = 0; i < 3; i++) ...[
              TextField(
                controller: ctrls[i],
                maxLength: 120,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  counterText: '',
                  hintText: [
                    'The most important task',
                    'The second task',
                    'The third task'
                  ][i],
                  prefixIcon: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text('${i + 1}',
                        style: TextStyle(
                            color: Neon.violet, fontWeight: FontWeight.w800)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 6),
            FilledButton(
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50)),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (save != true) return;
    final items = <Priority>[];
    for (var i = 0; i < 3; i++) {
      final t = ctrls[i].text.trim();
      if (t.isEmpty) continue;
      final keep = i < o.priorities.length && o.priorities[i].title == t
          ? o.priorities[i]
          : null;
      items.add(Priority(keep?.id ?? 0, t, keep?.done ?? false));
    }
    final ok = await WorkspaceService.setPriorities(o.day, items);
    if (!mounted) return;
    if (!ok) {
      AppFeedback.show('Unable to save your priorities. Please try again.',
          context: context);
      return;
    }
    await _load();
  }

  void _ask(PackAction a) {
    HapticFeedback.selectionClick();
    unawaited(
        AssistantEngine.instance.askAssistant(a.ask).catchError((Object _) {
      AppFeedback.toast('Unable to submit the request. Please try again.');
    }));
    AppFeedback.toast('Your assistant is working on it.');
  }

  void _focus() {
    final o = _o;
    if (o == null) return;
    final top =
        o.priorities.where((p) => !p.done).map((p) => p.title).firstOrNull;
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) =>
          FocusScreen(minutes: o.pack.focus, label: top ?? '', autoStart: true),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final o = _o;
    return NeonScaffold(
      appBar: appleAppBar(context, o?.pack.title ?? 'Workspace', actions: [
        IconButton(
          tooltip: 'Talk to Your Assistant',
          icon: const Icon(Icons.graphic_eq_rounded),
          onPressed: () => unawaited(AssistantEngine.instance
              .beginInlineConversation(name: AuthService.instance.user?.name)),
        ),
      ]),
      body: _loading && o == null
          ? const Center(child: NeonLoader())
          : o == null
              ? NeonErrorState(
                  message: 'Unable to Load Your Workspace',
                  hint: _failed ? null : 'Please try again.',
                  onRetry: () {
                    setState(() => _loading = true);
                    _load();
                  },
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                    children: [
                      _Hero(o: o),
                      const SizedBox(height: 18),
                      _planCard(o),
                      const SizedBox(height: 18),
                      _prioritiesCard(o),
                      if (o.reminders.isNotEmpty || o.promises.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        _dueCard(o),
                      ],
                      const SizedBox(height: 18),
                      _focusCard(o),
                      const SizedBox(height: 26),
                      const _Section(
                        title: 'Automations',
                        subtitle:
                            'Switch on the routines you want. Each one reminds you at its time, every time.',
                      ),
                      const SizedBox(height: 10),
                      _Card(
                        padding: EdgeInsets.zero,
                        child: Column(children: [
                          for (var i = 0; i < o.pack.routines.length; i++) ...[
                            if (i > 0)
                              Divider(
                                  height: 1,
                                  color: Neon.line,
                                  indent: 16,
                                  endIndent: 16),
                            _routineRow(o, o.pack.routines[i]),
                          ],
                        ]),
                      ),
                      const SizedBox(height: 26),
                      const _Section(
                        title: 'Quick Actions',
                        subtitle: 'Hand these to your assistant with one tap.',
                      ),
                      const SizedBox(height: 10),
                      _actionsGrid(o),
                    ],
                  ),
                ),
    );
  }

  // ── Today's plan ────────────────────────────────────────────────────────
  Widget _planCard(WorkspaceOverview o) {
    final plan = o.plan;
    final blocks = plan?.blocks ?? o.pack.day;
    final now = TimeOfDay.now();
    final nowMin = now.hour * 60 + now.minute;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Today's Plan",
                        style: NeonType.manrope(18, FontWeight.w800)
                            .copyWith(color: Neon.textHi)),
                    const SizedBox(height: 2),
                    Text(
                        plan == null
                            ? 'A typical day for your work. Let your assistant plan yours.'
                            : plan.source == 'ai'
                                ? 'Planned around your priorities and reminders.'
                                : 'Your typical working day.',
                        style: TextStyle(color: Neon.textLo, fontSize: 12.5)),
                  ]),
            ),
            if (plan != null)
              IconButton(
                tooltip: 'Plan Again',
                onPressed: _planning ? null : () => _plan(force: true),
                icon: _planning
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(Icons.refresh_rounded, color: Neon.textLo),
              ),
          ]),
          if (plan?.note.isNotEmpty == true) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: Neon.violet.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.auto_awesome_rounded, size: 16, color: Neon.violet),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(plan!.note,
                        style: TextStyle(
                            color: Neon.textHi, fontSize: 13, height: 1.35))),
              ]),
            ),
          ],
          const SizedBox(height: 12),
          for (var i = 0; i < blocks.length; i++)
            _BlockRow(
              block: blocks[i],
              last: i == blocks.length - 1,
              state: nowMin >= blocks[i].endMin
                  ? _BlockState.past
                  : nowMin >= blocks[i].startMin
                      ? _BlockState.now
                      : _BlockState.next,
            ),
          if (plan == null) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _planning ? null : _plan,
                icon: _planning
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.auto_awesome_rounded, size: 18),
                label: Text(_planning ? 'Planning Your Day' : 'Plan My Day'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Today's top 3 ───────────────────────────────────────────────────────
  Widget _prioritiesCard(WorkspaceOverview o) {
    final done = o.priorities.where((p) => p.done).length;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text("Today's Top 3",
                  style: NeonType.manrope(18, FontWeight.w800)
                      .copyWith(color: Neon.textHi)),
            ),
            if (o.priorities.isNotEmpty)
              Text('$done of ${o.priorities.length} done',
                  style: TextStyle(
                      color: Neon.textLo,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600)),
            IconButton(
              tooltip: 'Edit Priorities',
              onPressed: _editPriorities,
              icon: Icon(
                  o.priorities.isEmpty ? Icons.add_rounded : Icons.edit_rounded,
                  color: Neon.violet,
                  size: 20),
            ),
          ]),
          if (o.priorities.isEmpty)
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _editPriorities,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                    'Set the three things that would make today a success.',
                    style: TextStyle(
                        color: Neon.textLo, fontSize: 13.5, height: 1.4)),
              ),
            )
          else
            for (final p in o.priorities)
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => _tickPriority(p),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: p.done ? Neon.gBrand : null,
                        border: p.done
                            ? null
                            : Border.all(color: Neon.textDim, width: 1.6),
                      ),
                      child: p.done
                          ? Icon(Icons.check_rounded,
                              size: 15, color: Neon.onBrand)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(p.title,
                          style: TextStyle(
                            color: p.done ? Neon.textDim : Neon.textHi,
                            fontSize: 14.5,
                            decoration:
                                p.done ? TextDecoration.lineThrough : null,
                          )),
                    ),
                  ]),
                ),
              ),
        ],
      ),
    );
  }

  // ── Due today ───────────────────────────────────────────────────────────
  Widget _dueCard(WorkspaceOverview o) {
    String time(int ms) {
      final d = DateTime.fromMillisecondsSinceEpoch(ms);
      final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
      return '$h:${d.minute.toString().padLeft(2, '0')} ${d.hour < 12 ? 'AM' : 'PM'}';
    }

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Due Today',
              style: NeonType.manrope(18, FontWeight.w800)
                  .copyWith(color: Neon.textHi)),
          const SizedBox(height: 8),
          for (final r in o.reminders)
            _DueRow(
                icon: Icons.alarm_rounded,
                color: Neon.violet,
                title: r.text,
                trailing: time(r.at)),
          for (final p in o.promises)
            _DueRow(
              icon: Icons.handshake_rounded,
              color: Neon.pink,
              title: p.text,
              trailing: p.owedTo.isNotEmpty ? 'To ${p.owedTo}' : 'Promise',
            ),
        ],
      ),
    );
  }

  // ── Focus ───────────────────────────────────────────────────────────────
  Widget _focusCard(WorkspaceOverview o) {
    final top =
        o.priorities.where((p) => !p.done).map((p) => p.title).firstOrNull;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(Neon.rLg),
        onTap: _focus,
        child: Ink(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          decoration: BoxDecoration(
            gradient: Neon.gBrand,
            borderRadius: BorderRadius.circular(Neon.rLg),
            boxShadow: Neon.halo(Neon.violet),
          ),
          child: Row(children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.timer_rounded, color: Neon.onBrand),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Start a ${o.pack.focus}-Minute Focus Session',
                        style: TextStyle(
                            color: Neon.onBrand,
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                        top != null
                            ? 'On: $top'
                            : 'Silence distractions and do your most important work.',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: Neon.onBrand.withValues(alpha: 0.85),
                            fontSize: 12.5)),
                  ]),
            ),
            Icon(Icons.play_arrow_rounded, color: Neon.onBrand, size: 28),
          ]),
        ),
      ),
    );
  }

  // ── Automations ─────────────────────────────────────────────────────────
  Widget _routineRow(WorkspaceOverview o, PackRoutine r) {
    final st = o.routines[r.id];
    final on = st?.on ?? false;
    final busy = _switching.contains(r.id);
    final time = st?.time.isNotEmpty == true ? st!.time : r.time;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          IconTile(_routineIcon(r.repeat), on ? Neon.violet : Neon.accentF,
              size: 36),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.title,
                  style: TextStyle(
                      color: Neon.textHi,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(r.detail,
                  style: TextStyle(
                      color: Neon.textLo, fontSize: 12.5, height: 1.3)),
              const SizedBox(height: 6),
              InkWell(
                borderRadius: BorderRadius.circular(100),
                onTap: busy ? null : () => _changeTime(r),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (on ? Neon.violet : Neon.textDim)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.schedule_rounded,
                        size: 13, color: on ? Neon.violet : Neon.textLo),
                    const SizedBox(width: 5),
                    Text('${r.when}, ${_twelve(time)}',
                        style: TextStyle(
                            color: on ? Neon.violet : Neon.textLo,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ]),
          ),
          busy
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : Switch.adaptive(value: on, onChanged: (v) => _toggle(r, v)),
        ],
      ),
    );
  }

  static IconData _routineIcon(String repeat) => switch (repeat) {
        'weekly' => Icons.date_range_rounded,
        'monthly' => Icons.calendar_month_rounded,
        _ => Icons.repeat_rounded,
      };

  static String _twelve(String hhmm) {
    final p = hhmm.split(':');
    final h = int.tryParse(p.first) ?? 0;
    final m = p.length > 1 ? p[1] : '00';
    return '${h % 12 == 0 ? 12 : h % 12}:$m ${h < 12 ? 'AM' : 'PM'}';
  }

  // ── Quick actions ───────────────────────────────────────────────────────
  Widget _actionsGrid(WorkspaceOverview o) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.55,
      children: [
        for (final a in o.pack.actions)
          Material(
            color: Neon.surface,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => _ask(a),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Neon.line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconTile(actionIcon(a.icon), Neon.violet, size: 34),
                    const Spacer(),
                    Text(a.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: Neon.textHi,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            height: 1.25)),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// The pack's Material icon names → icons (unknown → a spark).
  static IconData actionIcon(String name) =>
      const {
        'record_voice_over': Icons.record_voice_over_rounded,
        'event_note': Icons.event_note_rounded,
        'summarize': Icons.summarize_rounded,
        'groups': Icons.groups_rounded,
        'account_tree': Icons.account_tree_rounded,
        'description': Icons.description_rounded,
        'menu_book': Icons.menu_book_rounded,
        'quiz': Icons.quiz_rounded,
        'mail': Icons.mail_rounded,
        'calendar_month': Icons.calendar_month_rounded,
        'lightbulb': Icons.lightbulb_rounded,
        'checklist': Icons.checklist_rounded,
        'event_busy': Icons.event_busy_rounded,
        'calculate': Icons.calculate_rounded,
        'payments': Icons.payments_rounded,
        'send': Icons.send_rounded,
        'call': Icons.call_rounded,
        'campaign': Icons.campaign_rounded,
        'list_alt': Icons.list_alt_rounded,
        'request_quote': Icons.request_quote_rounded,
        'person': Icons.person_rounded,
        'work': Icons.work_rounded,
        'rate_review': Icons.rate_review_rounded,
        'short_text': Icons.short_text_rounded,
        'movie': Icons.movie_rounded,
        'handshake': Icons.handshake_rounded,
        'autorenew': Icons.autorenew_rounded,
        'assignment': Icons.assignment_rounded,
        'alarm': Icons.alarm_rounded,
        'inventory': Icons.inventory_2_rounded,
        'self_improvement': Icons.self_improvement_rounded,
        'route': Icons.route_rounded,
        'wb_sunny': Icons.wb_sunny_rounded,
        'timer': Icons.timer_rounded,
        'travel_explore': Icons.travel_explore_rounded,
        'restaurant_menu': Icons.restaurant_menu_rounded,
        'shopping_cart': Icons.shopping_cart_rounded,
        'receipt_long': Icons.receipt_long_rounded,
        'family_restroom': Icons.family_restroom_rounded,
        'soup_kitchen': Icons.soup_kitchen_rounded,
        'newspaper': Icons.newspaper_rounded,
        'medication': Icons.medication_rounded,
        'insights': Icons.insights_rounded,
        'event_available': Icons.event_available_rounded,
        'school': Icons.school_rounded,
      }[name] ??
      Icons.auto_awesome_rounded;
}

/// Photo, "<Profession> Workspace", the pack's line and today's numbers.
class _Hero extends StatelessWidget {
  const _Hero({required this.o});
  final WorkspaceOverview o;

  @override
  Widget build(BuildContext context) {
    final label = o.profession.isNotEmpty
        ? o.profession
        : o.pack.title.replaceAll(' Workspace', '');
    final done = o.priorities.where((p) => p.done).length;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Neon.rLg),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Neon.violet.withValues(alpha: 0.20), Neon.surface],
        ),
        border: Border.all(color: Neon.violet.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            // Tap the photo to add or change it (the onboarding photo step,
            // with its professional headshot).
            GestureDetector(
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (ctx) => PhotoStepScreen(
                    editing: true, onDone: () => Navigator.of(ctx).pop()),
              )),
              child: ValueListenableBuilder<int>(
                valueListenable: MyPhoto.version,
                builder: (_, v, __) => FutureBuilder<File?>(
                  key: ValueKey(v),
                  future: MyPhoto.current(),
                  builder: (_, snap) => Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: Neon.gBrand,
                      boxShadow: Neon.halo(Neon.violet),
                    ),
                    padding: const EdgeInsets.all(2),
                    child: ClipOval(
                      child: snap.data != null
                          ? Image.file(snap.data!,
                              fit: BoxFit.cover,
                              alignment: const Alignment(0, -0.4))
                          : Container(
                              color: Neon.surface,
                              child: Icon(Icons.add_a_photo_rounded,
                                  color: Neon.violet, size: 24),
                            ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.interTight(
                            fontSize: 21,
                            fontWeight: FontWeight.w700,
                            color: Neon.textHi,
                            letterSpacing: -0.4)),
                    const SizedBox(height: 3),
                    Text(o.pack.tagline,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: Neon.textLo, fontSize: 12.5, height: 1.3)),
                  ]),
            ),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            _Stat(value: '${o.focusMinutesToday}', label: 'Focus Minutes'),
            _Stat(
                value:
                    o.priorities.isEmpty ? '–' : '$done/${o.priorities.length}',
                label: 'Top 3 Done'),
            _Stat(
                value: '${o.routinesOn}/${o.pack.routines.length}',
                label: 'Automations On'),
          ]),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
          Text(value,
              style: NeonType.manrope(20, FontWeight.w800)
                  .copyWith(color: Neon.textHi)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: Neon.textLo, fontSize: 11.5)),
        ]),
      );
}

enum _BlockState { past, now, next }

class _BlockRow extends StatelessWidget {
  const _BlockRow(
      {required this.block, required this.last, required this.state});
  final DayBlock block;
  final bool last;
  final _BlockState state;

  static Color colorFor(String kind) => switch (kind) {
        'focus' => Neon.violet,
        'meeting' => Neon.cyan,
        'break' => Neon.success,
        'admin' => Neon.warning,
        'personal' => Neon.pink,
        _ => Neon.accentF,
      };

  static String labelFor(String kind) => switch (kind) {
        'focus' => 'Focus',
        'meeting' => 'Meeting',
        'break' => 'Break',
        'admin' => 'Admin',
        'personal' => 'Personal',
        _ => 'Task',
      };

  @override
  Widget build(BuildContext context) {
    final c = colorFor(block.kind);
    final now = state == _BlockState.now;
    final past = state == _BlockState.past;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 46,
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(block.start,
                  style: TextStyle(
                      color: past ? Neon.textDim : Neon.textLo,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()])),
            ),
          ),
          Column(children: [
            const SizedBox(height: 12),
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: past ? Neon.textDim : c,
                boxShadow: now
                    ? [
                        BoxShadow(
                            color: c.withValues(alpha: 0.6), blurRadius: 8)
                      ]
                    : null,
              ),
            ),
            if (!last) Expanded(child: Container(width: 1.5, color: Neon.line)),
          ]),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
              decoration: BoxDecoration(
                color: now ? c.withValues(alpha: 0.12) : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border:
                    now ? Border.all(color: c.withValues(alpha: 0.5)) : null,
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(block.title,
                        style: TextStyle(
                            color: past ? Neon.textDim : Neon.textHi,
                            fontSize: 14,
                            fontWeight: now ? FontWeight.w700 : FontWeight.w500,
                            height: 1.3)),
                    const SizedBox(height: 3),
                    Row(children: [
                      Text('${block.start} – ${block.end}',
                          style:
                              TextStyle(color: Neon.textDim, fontSize: 11.5)),
                      const SizedBox(width: 8),
                      Text(
                          now
                              ? 'Now · ${labelFor(block.kind)}'
                              : labelFor(block.kind),
                          style: TextStyle(
                              color: past ? Neon.textDim : c,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700)),
                    ]),
                  ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _DueRow extends StatelessWidget {
  const _DueRow(
      {required this.icon,
      required this.color,
      required this.title,
      required this.trailing});
  final IconData icon;
  final Color color;
  final String title;
  final String trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style:
                    TextStyle(color: Neon.textHi, fontSize: 14, height: 1.3)),
          ),
          const SizedBox(width: 8),
          Text(trailing,
              style: TextStyle(
                  color: Neon.textLo,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ]),
      );
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: NeonType.manrope(19, FontWeight.w800)
                  .copyWith(color: Neon.textHi)),
          const SizedBox(height: 2),
          Text(subtitle,
              style:
                  TextStyle(color: Neon.textLo, fontSize: 12.5, height: 1.35)),
        ]),
      );
}

class _Card extends StatelessWidget {
  const _Card(
      {required this.child,
      this.padding = const EdgeInsets.fromLTRB(16, 14, 16, 14)});
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: Neon.surface,
          borderRadius: BorderRadius.circular(Neon.rLg),
          border: Border.all(color: Neon.line),
        ),
        child: child,
      );
}
