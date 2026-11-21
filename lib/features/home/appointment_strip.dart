import 'dart:async';

import 'package:flutter/material.dart';

import '../../design/neon_tokens.dart';
import '../../models/brief.dart';
import '../../services/api_service.dart';
import '../../services/app_feedback.dart';
import '../../services/brief_service.dart';
import '../../widgets/neon_cards.dart';

/// "In 2 h", "Tomorrow", "Mon" — how far away, at a glance.
String appointmentCountdown(int atMs, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final t = DateTime.fromMillisecondsSinceEpoch(atMs);
  final d = t.difference(n);
  if (d.isNegative) return 'Now';
  if (d.inMinutes < 60) return 'In ${d.inMinutes} min';
  final today = DateTime(n.year, n.month, n.day);
  final day = DateTime(t.year, t.month, t.day);
  final days = day.difference(today).inDays;
  if (days == 0) return 'In ${d.inHours} h';
  if (days == 1) return 'Tomorrow';
  if (days < 7) return const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][t.weekday - 1];
  return 'In $days days';
}

/// THE NEXT APPOINTMENT, at the top of Home (owner, 2026-11-21): booked
/// through a contact's assistant — with whom, when, how — and a countdown.
/// Tap: every upcoming booking, each cancellable.
class AppointmentStrip extends StatefulWidget {
  const AppointmentStrip({super.key, required this.appointments});
  final List<BriefAppointment> appointments;

  @override
  State<AppointmentStrip> createState() => _AppointmentStripState();
}

class _AppointmentStripState extends State<AppointmentStrip> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // The countdown stays true while Home is open.
    _tick = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final list = widget.appointments;
    if (list.isEmpty) return const SizedBox.shrink();
    final a = list.first;
    final soon = DateTime.fromMillisecondsSinceEpoch(a.atMs)
            .difference(DateTime.now())
            .inMinutes <
        120;
    final tint = soon ? Neon.violet : Neon.accentC;
    final sub = [a.modeLabel, a.purpose].where((s) => s.isNotEmpty).join(' · ');
    return Semantics(
      button: true,
      label: 'Next appointment with ${a.withName}, ${a.when}',
      child: GestureDetector(
        onTap: () => AppointmentsSheet.show(context, list),
        child: GlassCard(
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          glow: soon ? Neon.violet : null,
          child: Row(children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(Icons.event_available_rounded, size: 20, color: tint),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    list.length > 1
                        ? 'Next Appointment · +${list.length - 1} more'
                        : 'Next Appointment',
                    style: NeonType.manrope(11, FontWeight.w700)
                        .copyWith(color: Neon.textLo, letterSpacing: 0.3),
                  ),
                  Text('${a.withName} · ${a.when}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: NeonType.manrope(14, FontWeight.w800)
                          .copyWith(color: Neon.textHi)),
                  if (sub.isNotEmpty)
                    Text(sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: NeonType.manrope(12, FontWeight.w500)
                            .copyWith(color: Neon.textLo)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(appointmentCountdown(a.atMs),
                  style: NeonType.manrope(11.5, FontWeight.w800).copyWith(color: tint)),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Every upcoming booking, with the details and a Cancel for each.
class AppointmentsSheet extends StatefulWidget {
  const AppointmentsSheet({super.key, required this.appointments});
  final List<BriefAppointment> appointments;

  static Future<void> show(BuildContext context, List<BriefAppointment> list) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Neon.surface,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (_) => AppointmentsSheet(appointments: list),
      );

  @override
  State<AppointmentsSheet> createState() => _AppointmentsSheetState();
}

class _AppointmentsSheetState extends State<AppointmentsSheet> {
  late final List<BriefAppointment> _list = List.of(widget.appointments);
  final Set<int> _busy = {};

  Future<void> _cancel(BriefAppointment a) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Cancel This Appointment?'),
        content: Text('${a.withName} · ${a.when}\nThey will be told.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Keep')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Cancel It')),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    setState(() => _busy.add(a.id));
    final r = await ApiService.postJson('/connect/bookings/${a.id}/cancel', const {});
    if (!mounted) return;
    setState(() {
      _busy.remove(a.id);
      if (r != null) _list.removeWhere((x) => x.id == a.id);
    });
    if (r == null) {
      AppFeedback.toast('Unable to cancel. Please try again.');
      return;
    }
    AppFeedback.toast('Cancelled. ${a.withName} has been told.');
    BriefService.instance.refresh(force: true);
    if (_list.isEmpty && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.of(context).size.height * 0.8;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Neon.textLo.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(4)),
                ),
              ),
              const SizedBox(height: 14),
              Text('Upcoming Appointments',
                  style: NeonType.manrope(18, FontWeight.w800).copyWith(color: Neon.textHi)),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final a = _list[i];
                    final place = a.details.split('|').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Neon.violet.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Neon.hairline),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Expanded(
                              child: Text(a.withName,
                                  style: NeonType.manrope(15.5, FontWeight.w800)
                                      .copyWith(color: Neon.textHi)),
                            ),
                            Text(appointmentCountdown(a.atMs),
                                style: NeonType.manrope(12, FontWeight.w700)
                                    .copyWith(color: Neon.violet)),
                          ]),
                          const SizedBox(height: 4),
                          Text(a.when,
                              style: NeonType.manrope(14, FontWeight.w700)
                                  .copyWith(color: Neon.textHi)),
                          const SizedBox(height: 2),
                          Text(
                            [
                              if (a.purpose.isNotEmpty) a.purpose,
                              if (a.modeLabel.isNotEmpty) a.modeLabel,
                              '${a.minutes} min',
                              if (place.length > 4) place.last,
                            ].join(' · '),
                            style: NeonType.manrope(12.5, FontWeight.w500)
                                .copyWith(color: Neon.textLo, height: 1.4),
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: _busy.contains(a.id) ? null : () => _cancel(a),
                              icon: Icon(Icons.event_busy_rounded, size: 17, color: Neon.error),
                              label: Text('Cancel',
                                  style: TextStyle(color: Neon.error, fontWeight: FontWeight.w700)),
                            ),
                          ),
                        ],
                      ),
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
