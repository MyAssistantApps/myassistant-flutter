import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../design/apple_kit.dart';
import '../../design/neon_tokens.dart';
import '../../design/neon_widgets.dart';
import '../../models/clinic.dart';
import '../../services/app_feedback.dart';
import '../../services/clinic_service.dart';
import '../clients_screen.dart';
import 'clinic_settings_screen.dart';
import 'clinic_sheets.dart';

/// ─────────────────────────────────────────────────────────────────────────
///  CLINIC — the doctor's workspace. Visible ONLY to doctors (persona).
///
///  Three tabs, ordered by how often a doctor needs them between patients:
///    Today      — who is due, who slipped, who owes; one-tap actions
///    Follow-ups — everything scheduled, overdue first
///    Payments   — outstanding balances, tap to settle
///
///  Every row acts in one tap (call, done, settle); everything less common
///  sits behind a long-press menu. Everything here can also be done by
///  voice ("follow up Ramesh in two weeks", "Ramesh paid 500"), and the
///  screen says so, because voice is faster with gloves on.
/// ─────────────────────────────────────────────────────────────────────────
class ClinicScreen extends StatefulWidget {
  const ClinicScreen({super.key, this.initialTab = 0});
  final int initialTab;

  @override
  State<ClinicScreen> createState() => _ClinicScreenState();
}

class _ClinicScreenState extends State<ClinicScreen> {
  @override
  void initState() {
    super.initState();
    ClinicService.instance.refresh(force: true);
    // Profile tells Today whether to show the one-time setup prompt.
    ClinicService.instance.loadProfile();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      initialIndex: widget.initialTab.clamp(0, 2),
      child: Scaffold(
        backgroundColor: Neon.bg,
        appBar: appleAppBar(context, 'Clinic', actions: [
          IconButton(
            tooltip: 'Patients',
            icon: const Icon(Icons.folder_shared_rounded),
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ClientsScreen())),
          ),
          IconButton(
            tooltip: 'Clinic settings',
            icon: const Icon(Icons.tune_rounded),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const ClinicSettingsScreen())),
          ),
        ]),
        body: Column(
          children: [
            TabBar(
              labelColor: Neon.violet,
              unselectedLabelColor: Neon.textLo,
              indicatorColor: Neon.violet,
              dividerColor: Neon.line,
              labelStyle:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              tabs: const [
                Tab(text: 'Today'),
                Tab(text: 'Follow-ups'),
                Tab(text: 'Payments'),
              ],
            ),
            const Expanded(
              child: TabBarView(children: [
                _TodayTab(),
                _FollowUpsTab(),
                _PaymentsTab(),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

/* ====================================================================== */
/* Today                                                                   */
/* ====================================================================== */

class _TodayTab extends StatelessWidget {
  const _TodayTab();

  @override
  Widget build(BuildContext context) {
    final svc = ClinicService.instance;
    return AnimatedBuilder(
      animation: svc,
      builder: (context, _) {
        final t = svc.today;
        if (t == null) {
          if (svc.failed) {
            return NeonErrorState(
                message: "Couldn't load your clinic day.",
                onRetry: () => svc.refresh(force: true));
          }
          return const Center(child: NeonLoader());
        }
        final f = t.followUps;
        final open = t.openAppointments;
        final waiting = open.where((a) => a.status == 'arrived').length;
        final needsSetup = svc.profile != null && !svc.profile!.configured;
        return RefreshIndicator(
          color: Neon.violet,
          onRefresh: () => svc.refresh(force: true),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
            children: [
              if (needsSetup) ...[
                const _SetupCard(),
                const SizedBox(height: 14),
              ],
              Row(children: [
                _Stat('${open.length}', waiting > 0 ? '$waiting waiting' : 'To see',
                    Neon.violet),
                const SizedBox(width: 10),
                _Stat('${f.today.length + f.overdue.length}', 'Follow-ups',
                    f.overdue.isEmpty ? Neon.textLo : Neon.warning),
                const SizedBox(width: 10),
                _Stat(rupees(t.duesTotal), 'Pending',
                    t.duesTotal > 0 ? Neon.error : Neon.textLo),
              ]),
              const SizedBox(height: 16),
              _QuickActions(patientsLeft: open.where((a) => a.status == 'booked').length),
              const SizedBox(height: 22),
              GroupLabel(t.appointments.isEmpty
                  ? 'Appointments'
                  : 'Appointments · ${t.appointments.length}'),
              if (t.appointments.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Text(
                    'No appointments today. Book one above — or let your phone '
                    'receptionist book callers (Clinic settings).',
                    style: TextStyle(color: Neon.textLo, fontSize: 13.5, height: 1.4),
                  ),
                )
              else ...[
                GroupedCard(
                  dividerInset: 60,
                  children: [for (final a in t.appointments) _ApptRow(a)],
                ),
                const SizedBox(height: 20),
              ],
              if (f.today.isEmpty && f.overdue.isEmpty)
                _calmCard(t)
              else ...[
                if (f.overdue.isNotEmpty) ...[
                  GroupLabel('Overdue · ${f.overdue.length}'),
                  _FollowUpGroup(f.overdue),
                  const SizedBox(height: 20),
                ],
                if (f.today.isNotEmpty) ...[
                  GroupLabel('Due today · ${f.today.length}'),
                  _FollowUpGroup(f.today),
                  const SizedBox(height: 20),
                ],
              ],
              if (t.dues.isNotEmpty) ...[
                GroupLabel('Payments pending · ${t.duesCount}'),
                _DuesGroup(t.dues),
                const SizedBox(height: 20),
              ],
              const _VoiceHint(),
            ],
          ),
        );
      },
    );
  }

  Widget _calmCard(ClinicToday t) {
    final next = t.followUps.upcoming.isNotEmpty ? t.followUps.upcoming.first : null;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Neon.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Neon.line),
      ),
      child: Row(children: [
        Icon(Icons.check_circle_rounded, color: Neon.success, size: 26),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            next == null
                ? 'No follow-ups due. ${t.patients} patient${t.patients == 1 ? '' : 's'} on file.'
                : 'Nothing due today. Next: ${next.clientName}, ${followUpWhen(next.dueAt)}.',
            style: TextStyle(color: Neon.textHi, fontSize: 14, height: 1.35),
          ),
        ),
      ]),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.value, this.label, this.color);
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 11),
        decoration: BoxDecoration(
          color: Neon.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Neon.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value,
                  style: TextStyle(
                      color: color, fontSize: 22, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: Neon.textLo, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({this.patientsLeft = 0});

  /// Booked patients still to come today — the running-late audience.
  final int patientsLeft;

  @override
  Widget build(BuildContext context) {
    Widget btn(IconData i, String l, VoidCallback onTap) => Expanded(
          child: Material(
            color: Neon.violet.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                HapticFeedback.selectionClick();
                onTap();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(children: [
                  Icon(i, color: Neon.violet, size: 22),
                  const SizedBox(height: 4),
                  Text(l,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: Neon.violet,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ),
        );
    return Row(children: [
      btn(Icons.event_available_rounded, 'Book', () => bookAppointment(context)),
      const SizedBox(width: 8),
      btn(Icons.event_repeat_rounded, 'Follow-up',
          () => scheduleFollowUp(context)),
      const SizedBox(width: 8),
      btn(Icons.currency_rupee_rounded, 'Payment',
          () => recordPayment(context)),
      const SizedBox(width: 8),
      btn(Icons.timer_outlined, 'Late',
          () => runningLate(context, patientsLeft: patientsLeft)),
    ]);
  }
}

/// First open: a clinic that hasn't set timings books nothing sensible.
class _SetupCard extends StatelessWidget {
  const _SetupCard();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Neon.violet.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ClinicSettingsScreen())),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Icon(Icons.storefront_rounded, color: Neon.violet),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Set up your clinic — timings, fee and registration number. '
                'Takes a minute; booking and prescriptions use it.',
                style: TextStyle(color: Neon.textHi, fontSize: 13.5, height: 1.35),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Neon.violet),
          ]),
        ),
      ),
    );
  }
}

/// One appointment: time, patient, status, and the next action in one tap.
class _ApptRow extends StatelessWidget {
  const _ApptRow(this.a);
  final Appointment a;

  static String _hm(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    return '$h:${d.minute.toString().padLeft(2, '0')} ${d.hour < 12 ? 'am' : 'pm'}';
  }

  Future<void> _set(String status) async {
    HapticFeedback.lightImpact();
    final ok = await ClinicService.instance.setAppointmentStatus(a.id, status);
    if (!ok) AppFeedback.toast("Couldn't update. Check your connection.");
  }

  void _menu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Neon.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (a.clientId != null)
            ListTile(
              leading: const Icon(Icons.folder_open_rounded),
              title: const Text('Open patient file'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ClientDetailScreen(clientId: a.clientId!)));
              },
            ),
          if (a.patientPhone.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.call_rounded),
              title: Text('Call ${a.patientName}'),
              onTap: () {
                Navigator.pop(ctx);
                launchUrl(Uri(scheme: 'tel', path: a.patientPhone));
              },
            ),
          for (final (s, label, icon) in const [
            ('arrived', 'Arrived — in waiting room', Icons.chair_rounded),
            ('done', 'Seen', Icons.check_circle_rounded),
            ('no_show', 'No-show', Icons.person_off_rounded),
            ('cancelled', 'Cancel appointment', Icons.event_busy_rounded),
          ])
            if (a.status != s)
              ListTile(
                leading: Icon(icon),
                title: Text(label),
                onTap: () {
                  Navigator.pop(ctx);
                  _set(s);
                },
              ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final closed = !a.isOpen;
    final (statusLabel, statusColor) = switch (a.status) {
      'arrived' => ('Waiting', Neon.warning),
      'done' => ('Seen', Neon.success),
      'no_show' => ('No-show', Neon.error),
      'cancelled' => ('Cancelled', Neon.textDim),
      _ => (a.source == 'receptionist' ? 'Booked by phone' : 'Booked', Neon.violet),
    };
    return InkWell(
      onTap: () => _menu(context),
      child: Opacity(
        opacity: closed ? 0.55 : 1,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
          child: Row(children: [
            SizedBox(
              width: 58,
              child: Text(_hm(a.startsAt),
                  style: TextStyle(
                      color: Neon.textHi, fontSize: 13.5, fontWeight: FontWeight.w700)),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a.patientName,
                      style: TextStyle(
                          color: Neon.textHi,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          decoration: a.status == 'cancelled'
                              ? TextDecoration.lineThrough
                              : null)),
                  const SizedBox(height: 2),
                  Text(
                    [statusLabel, if (a.reason.isNotEmpty) a.reason].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: statusColor, fontSize: 12.5),
                  ),
                ],
              ),
            ),
            if (a.status == 'booked')
              TextButton(
                onPressed: () => _set('arrived'),
                child: const Text('Arrived'),
              )
            else if (a.status == 'arrived')
              TextButton(
                onPressed: () => _set('done'),
                child: const Text('Seen'),
              ),
          ]),
        ),
      ),
    );
  }
}

class _VoiceHint extends StatelessWidget {
  const _VoiceHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Neon.violet.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.mic_rounded, color: Neon.violet, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Faster by voice — tap the mic and say:\n'
              '“Follow up Ramesh in two weeks”\n'
              '“Note for Ramesh: BP 130/85, continue meds”\n'
              '“Ramesh paid 500”',
              style: TextStyle(color: Neon.textLo, fontSize: 13, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

/* ====================================================================== */
/* Follow-up rows                                                          */
/* ====================================================================== */

class _FollowUpGroup extends StatelessWidget {
  const _FollowUpGroup(this.items, {this.onChanged});
  final List<FollowUp> items;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    return GroupedCard(
      dividerInset: 60,
      children: [for (final f in items) _FollowUpRow(f, onChanged: onChanged)],
    );
  }
}

class _FollowUpRow extends StatelessWidget {
  const _FollowUpRow(this.f, {this.onChanged});
  final FollowUp f;
  final VoidCallback? onChanged;

  Future<void> _close(BuildContext context, {bool cancel = false}) async {
    HapticFeedback.lightImpact();
    final ok = await ClinicService.instance.closeFollowUp(f.id, cancel: cancel);
    AppFeedback.toast(ok
        ? (cancel ? 'Follow-up cancelled.' : '${f.clientName} — done.')
        : "Couldn't update. Check your connection.");
    if (ok) onChanged?.call();
  }

  Future<void> _call() async {
    final ok = await launchUrl(Uri(scheme: 'tel', path: f.clientPhone));
    if (!ok) AppFeedback.toast("Couldn't open the dialer.");
  }

  void _menu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Neon.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.folder_open_rounded),
            title: const Text('Open patient file'),
            onTap: () {
              Navigator.pop(ctx);
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ClientDetailScreen(clientId: f.clientId)));
            },
          ),
          ListTile(
            leading: const Icon(Icons.check_rounded),
            title: const Text('Mark done'),
            onTap: () {
              Navigator.pop(ctx);
              _close(context);
            },
          ),
          ListTile(
            leading: Icon(Icons.close_rounded, color: Neon.error),
            title: Text('Cancel follow-up', style: TextStyle(color: Neon.error)),
            onTap: () {
              Navigator.pop(ctx);
              _close(context, cancel: true);
            },
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final overdue = f.dueAt.isBefore(DateTime.now()) &&
        DateTime.now().difference(f.dueAt).inHours >= 1;
    final sub = [
      followUpWhen(f.dueAt),
      if (f.note.isNotEmpty) f.note,
      if (f.patientCalled) 'reminded',
    ].join(' · ');
    return InkWell(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ClientDetailScreen(clientId: f.clientId))),
      onLongPress: () => _menu(context),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
        child: Row(children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: (overdue ? Neon.warning : Neon.violet)
                .withValues(alpha: 0.15),
            child: Text(
              f.clientName.isEmpty ? '?' : f.clientName[0].toUpperCase(),
              style: TextStyle(
                  color: overdue ? Neon.warning : Neon.violet,
                  fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(f.clientName,
                    style: TextStyle(
                        color: Neon.textHi,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(sub,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: overdue ? Neon.warning : Neon.textLo,
                        fontSize: 12.5)),
              ],
            ),
          ),
          if (f.clientPhone.isNotEmpty)
            IconButton(
              tooltip: 'Call ${f.clientName}',
              icon: Icon(Icons.call_rounded, color: Neon.accentE),
              onPressed: _call,
            ),
          IconButton(
            tooltip: 'Mark done',
            icon: Icon(Icons.check_circle_outline_rounded, color: Neon.violet),
            onPressed: () => _close(context),
          ),
        ]),
      ),
    );
  }
}

/* ====================================================================== */
/* Follow-ups tab                                                          */
/* ====================================================================== */

class _FollowUpsTab extends StatefulWidget {
  const _FollowUpsTab();
  @override
  State<_FollowUpsTab> createState() => _FollowUpsTabState();
}

class _FollowUpsTabState extends State<_FollowUpsTab>
    with AutomaticKeepAliveClientMixin {
  FollowUpBuckets? _b;
  bool _failed = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final b = await ClinicService.instance.followUps();
    if (!mounted) return;
    setState(() {
      _b = b ?? _b;
      _failed = b == null && _b == null;
    });
  }

  Future<void> _add() async {
    final ok = await scheduleFollowUp(context);
    if (ok == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final b = _b;
    Widget body;
    if (_failed) {
      body = NeonErrorState(
          message: "Couldn't load follow-ups.",
          onRetry: () {
            setState(() => _failed = false);
            _load();
          });
    } else if (b == null) {
      body = const Center(child: NeonLoader());
    } else if (b.isEmpty) {
      body = const NeonEmptyState(
        icon: Icons.event_repeat_rounded,
        title: 'No follow-ups scheduled',
        body: 'Schedule one here or just say “follow up Ramesh in two weeks”. '
            'Your assistant can call the patient to remind them.',
      );
    } else {
      body = RefreshIndicator(
        color: Neon.violet,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
          children: [
            for (final (label, items) in [
              ('Overdue', b.overdue),
              ('Today', b.today),
              ('Upcoming', b.upcoming),
            ])
              if (items.isNotEmpty) ...[
                GroupLabel('$label · ${items.length}'),
                _FollowUpGroup(items, onChanged: _load),
                const SizedBox(height: 20),
              ],
          ],
        ),
      );
    }
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'clinic-followup',
        backgroundColor: Neon.violet,
        foregroundColor: Colors.white,
        onPressed: _add,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Follow-up'),
      ),
      body: body,
    );
  }
}

/* ====================================================================== */
/* Payments tab                                                            */
/* ====================================================================== */

class _DuesGroup extends StatelessWidget {
  const _DuesGroup(this.dues, {this.onChanged});
  final List<Due> dues;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    return GroupedCard(
      dividerInset: 60,
      children: [
        for (final d in dues)
          AppleRow(
            leading: CircleAvatar(
              radius: 15,
              backgroundColor: Neon.error.withValues(alpha: 0.12),
              child: Text(d.name.isEmpty ? '?' : d.name[0].toUpperCase(),
                  style: TextStyle(
                      color: Neon.error, fontWeight: FontWeight.w700)),
            ),
            title: d.name,
            subtitle: 'Tap to record a payment',
            trailing: Text(rupees(d.balance),
                style: TextStyle(
                    color: Neon.error,
                    fontWeight: FontWeight.w700,
                    fontSize: 15)),
            onTap: () async {
              final ok = await recordPayment(context,
                  clientId: d.clientId, clientName: d.name);
              if (ok == true) onChanged?.call();
            },
          ),
      ],
    );
  }
}

class _PaymentsTab extends StatefulWidget {
  const _PaymentsTab();
  @override
  State<_PaymentsTab> createState() => _PaymentsTabState();
}

class _PaymentsTabState extends State<_PaymentsTab>
    with AutomaticKeepAliveClientMixin {
  List<Due>? _dues;
  double _total = 0;
  bool _failed = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await ClinicService.instance.dues();
    if (!mounted) return;
    setState(() {
      if (r != null) {
        _dues = r.dues;
        _total = r.total;
      }
      _failed = r == null && _dues == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final d = _dues;
    Widget body;
    if (_failed) {
      body = NeonErrorState(
          message: "Couldn't load payments.",
          onRetry: () {
            setState(() => _failed = false);
            _load();
          });
    } else if (d == null) {
      body = const Center(child: NeonLoader());
    } else if (d.isEmpty) {
      body = const NeonEmptyState(
        icon: Icons.verified_rounded,
        title: 'Nobody owes you anything',
        body: 'Record a balance with “Owes”, or say “Ramesh owes 2000”.',
      );
    } else {
      body = RefreshIndicator(
        color: Neon.violet,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Neon.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Neon.line),
              ),
              child: Row(children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Total pending',
                          style: TextStyle(color: Neon.textLo, fontSize: 13)),
                      const SizedBox(height: 2),
                      Text(rupees(_total),
                          style: TextStyle(
                              color: Neon.error,
                              fontSize: 26,
                              fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
                Text('${d.length} patient${d.length == 1 ? '' : 's'}',
                    style: TextStyle(color: Neon.textLo, fontSize: 13)),
              ]),
            ),
            const SizedBox(height: 18),
            _DuesGroup(d, onChanged: _load),
          ],
        ),
      );
    }
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'clinic-payment',
        backgroundColor: Neon.violet,
        foregroundColor: Colors.white,
        onPressed: () async {
          final ok = await recordPayment(context);
          if (ok == true) _load();
        },
        icon: const Icon(Icons.currency_rupee_rounded),
        label: const Text('Record'),
      ),
      body: body,
    );
  }
}
