import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design/apple_kit.dart';
import '../../design/neon_tokens.dart';
import '../../design/neon_widgets.dart';
import '../../models/clinic.dart';
import '../../services/app_feedback.dart';
import '../../services/clinic_service.dart';
import '../clients_screen.dart';
import 'clinic_sheets.dart';
import '../../widgets/section_assistant_bar.dart';
import '../pro_assistant_screen.dart';

/// ─────────────────────────────────────────────────────────────────────────
///  BOOKED APPOINTMENTS (owner, 2026-11-21: "I want like already booked
///  appointments ... and even the patient records should be there").
///
///  Every appointment still to happen, grouped by day, whoever booked it —
///  the doctor, by voice, the public page, or a patient talking to the
///  doctor's assistant from their own app. Each opens that patient's record
///  (files, notes, documents): the server links or creates the record for
///  every booking. Arrived / Done / Cancel are one tap; a new appointment
///  is the + button.
/// ─────────────────────────────────────────────────────────────────────────
class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  List<Appointment>? _list;
  bool _loading = true;
  final Set<int> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final l = await ClinicService.instance.upcoming();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (l != null) _list = l;
    });
  }

  Future<void> _status(Appointment a, String status) async {
    if (_busy.contains(a.id)) return;
    HapticFeedback.selectionClick();
    setState(() => _busy.add(a.id));
    final ok = await ClinicService.instance.setAppointmentStatus(a.id, status);
    if (!mounted) return;
    setState(() => _busy.remove(a.id));
    if (!ok) {
      AppFeedback.show('Unable to update the appointment. Please try again.',
          context: context);
      return;
    }
    await _load();
  }

  Future<void> _new() async {
    final done = await bookAppointment(context);
    if (done == true) await _load();
  }

  void _open(Appointment a) {
    final id = a.clientId;
    if (id == null) {
      AppFeedback.toast('This appointment has no patient record yet.');
      return;
    }
    Navigator.of(context)
        .push(MaterialPageRoute<void>(
            builder: (_) => ClientDetailScreen(clientId: id)))
        .then((_) => _load());
  }

  static String dayLabel(DateTime d, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = day.difference(today).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    const wd = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    const mo = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${wd[d.weekday - 1]}, ${d.day} ${mo[d.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final list = _list ?? const <Appointment>[];
    final now = DateTime.now();
    final groups = <String, List<Appointment>>{};
    for (final a in list) {
      groups.putIfAbsent(dayLabel(a.startsAt, now), () => []).add(a);
    }
    return NeonScaffold(
      appBar: appleAppBar(context, 'Booked Appointments'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _new,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New'),
      ),
      body: PinnedSectionBar(
        // A speaker and a camera in every section (client, 2026-11-22),
        // pinned so they stay while the page scrolls.
        bar: proSectionBar(
          line: 'Say who to book and when, or show an appointment slip.',
          photoQuestion: 'Help me with this appointment using this photo.',
        ),
        list: _loading && _list == null
            ? const Center(child: NeonLoader())
            : _list == null
                ? NeonErrorState(
                    message: 'Unable to Load Appointments', onRetry: _load)
                : RefreshIndicator(
                    onRefresh: _load,
                    child: list.isEmpty
                        ? ListView(children: const [
                            SizedBox(height: 80),
                            NeonEmptyState(
                              icon: Icons.event_available_rounded,
                              title: 'No Upcoming Appointments',
                              body:
                                  'Appointments booked by you, by voice, from your public page '
                                  'or by patients talking to your assistant appear here.',
                            ),
                          ])
                        : ListView(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                            children: [
                              _Summary(list: list),
                              for (final e in groups.entries) ...[
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
                                  child: Text(
                                      '${e.key.toUpperCase()} · ${e.value.length}',
                                      style: NeonType.eyebrow
                                          .copyWith(color: Neon.textLo)),
                                ),
                                for (final a in e.value) ...[
                                  AppointmentCard(
                                    appt: a,
                                    busy: _busy.contains(a.id),
                                    onOpen: () => _open(a),
                                    onStatus: (s) => _status(a, s),
                                  ),
                                  const SizedBox(height: 10),
                                ],
                              ],
                            ],
                          ),
                  ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.list});
  final List<Appointment> list;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = list.where((a) =>
        a.startsAt.year == now.year &&
        a.startsAt.month == now.month &&
        a.startsAt.day == now.day);
    final byAssistant =
        list.where((a) => a.source == 'assistant' || a.source == 'web').length;
    Widget stat(String v, String l) => Expanded(
          child: Column(children: [
            Text(v,
                style: NeonType.manrope(22, FontWeight.w800)
                    .copyWith(color: Neon.textHi)),
            const SizedBox(height: 2),
            Text(l, style: TextStyle(color: Neon.textLo, fontSize: 11.5)),
          ]),
        );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Neon.rLg),
        gradient: LinearGradient(
            colors: [Neon.violet.withValues(alpha: 0.18), Neon.surface]),
        border: Border.all(color: Neon.violet.withValues(alpha: 0.35)),
      ),
      child: Row(children: [
        stat('${today.length}', 'Today'),
        stat('${list.length}', 'Upcoming'),
        stat('$byAssistant', 'Booked for You'),
      ]),
    );
  }
}

/// One appointment: time, patient, reason, who booked it, and its actions.
/// Shared with the doctor's page (the next three).
class AppointmentCard extends StatelessWidget {
  const AppointmentCard({
    super.key,
    required this.appt,
    required this.onOpen,
    this.onStatus,
    this.busy = false,
    this.compact = false,
  });

  final Appointment appt;
  final VoidCallback onOpen;
  final ValueChanged<String>? onStatus;
  final bool busy;
  final bool compact;

  static String time(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    return '$h:${d.minute.toString().padLeft(2, '0')} ${d.hour < 12 ? 'AM' : 'PM'}';
  }

  static (String, IconData) sourceOf(String s) => switch (s) {
        'assistant' => (
            'Booked by Their Assistant',
            Icons.auto_awesome_rounded
          ),
        'web' => ('From Your Public Page', Icons.public_rounded),
        'voice' => ('Booked by Voice', Icons.mic_rounded),
        _ => ('Added by You', Icons.edit_calendar_rounded),
      };

  @override
  Widget build(BuildContext context) {
    final a = appt;
    final (src, srcIcon) = sourceOf(a.source);
    final arrived = a.status == 'arrived';
    return Material(
      color: Neon.surface,
      borderRadius: BorderRadius.circular(Neon.rLg),
      child: InkWell(
        borderRadius: BorderRadius.circular(Neon.rLg),
        onTap: onOpen,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Neon.rLg),
            border: Border.all(
                color:
                    arrived ? Neon.success.withValues(alpha: 0.6) : Neon.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 62,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    gradient: Neon.gBrand,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(children: [
                    Text(time(a.startsAt).split(' ').first,
                        style: TextStyle(
                            color: Neon.onBrand,
                            fontSize: 16,
                            fontWeight: FontWeight.w800)),
                    Text(time(a.startsAt).split(' ').last,
                        style: TextStyle(
                            color: Neon.onBrand.withValues(alpha: 0.85),
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                  ]),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Flexible(
                            child: Text(a.patientName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: Neon.textHi,
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w700)),
                          ),
                          if (arrived) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: Neon.success.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: Text('Arrived',
                                  style: TextStyle(
                                      color: Neon.success,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ]),
                        const SizedBox(height: 3),
                        Text(a.reason.isNotEmpty ? a.reason : 'Consultation',
                            maxLines: compact ? 1 : 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: Neon.textLo, fontSize: 13, height: 1.3)),
                        const SizedBox(height: 6),
                        Row(children: [
                          Icon(srcIcon, size: 13, color: Neon.violet),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text('$src · ${a.durationMin} min',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: Neon.violet,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ]),
                      ]),
                ),
                Icon(Icons.chevron_right_rounded, color: Neon.textDim),
              ]),
              if (!compact && onStatus != null) ...[
                const SizedBox(height: 10),
                Divider(height: 1, color: Neon.line),
                const SizedBox(height: 6),
                busy
                    ? const Padding(
                        padding: EdgeInsets.all(8),
                        child: Center(
                            child: SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))),
                      )
                    : Row(children: [
                        if (!arrived)
                          _Act(Icons.how_to_reg_rounded, 'Arrived',
                              Neon.success, () => onStatus!('arrived')),
                        _Act(Icons.task_alt_rounded, 'Done', Neon.violet,
                            () => onStatus!('done')),
                        _Act(Icons.person_off_rounded, 'No-Show', Neon.warning,
                            () => onStatus!('no_show')),
                        _Act(Icons.close_rounded, 'Cancel', Neon.error,
                            () => onStatus!('cancelled')),
                      ]),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Act extends StatelessWidget {
  const _Act(this.icon, this.label, this.color, this.onTap);
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
        child: TextButton.icon(
          style: TextButton.styleFrom(
            foregroundColor: color,
            padding: const EdgeInsets.symmetric(vertical: 6),
            textStyle:
                const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          onPressed: onTap,
          icon: Icon(icon, size: 16),
          label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      );
}
