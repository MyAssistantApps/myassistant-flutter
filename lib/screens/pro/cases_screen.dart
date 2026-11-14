import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../design/apple_kit.dart';
import '../../design/neon_tokens.dart';
import '../../design/neon_widgets.dart';
import '../../models/client.dart';
import '../../models/clinic.dart';
import '../../services/app_feedback.dart';
import '../../services/pro_service.dart';
import '../clients_screen.dart';
import '../clinic/clinic_sheets.dart';
import 'invoices_screen.dart';
import 'legal_draft_screen.dart';

/// ─────────────────────────────────────────────────────────────────────────
///  CASES & HEARINGS — the advocate's case diary.
///
///  Every open matter with its next hearing, soonest first, so the list IS
///  the week ahead. A case holds its court, case number, opposite party and
///  stage; its hearings are added in two taps, and the client gets a
///  reminder call the day before (when their number is on file).
/// ─────────────────────────────────────────────────────────────────────────
class CasesScreen extends StatefulWidget {
  const CasesScreen({super.key});

  @override
  State<CasesScreen> createState() => _CasesScreenState();
}

class _CasesScreenState extends State<CasesScreen> {
  bool _closed = false;
  List<LegalCase>? _cases;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final c = await ProService.instance.cases(closed: _closed);
    if (!mounted) return;
    setState(() {
      _cases = c ?? _cases;
      _failed = c == null && _cases == null;
    });
  }

  Future<void> _new() async {
    final c = await newCaseSheet(context);
    if (c != null && mounted) {
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => CaseDetailScreen(caseId: c.id)));
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cases = _cases;
    return Scaffold(
      backgroundColor: Neon.bg,
      appBar: appleAppBar(context, 'Cases & hearings'),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Neon.violet,
        foregroundColor: Colors.white,
        onPressed: _new,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New case'),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Open')),
              ButtonSegment(value: true, label: Text('Closed')),
            ],
            selected: {_closed},
            onSelectionChanged: (s) {
              setState(() {
                _closed = s.first;
                _cases = null;
              });
              _load();
            },
          ),
        ),
        Expanded(
          child: _failed
              ? NeonErrorState(
                  message: "Couldn't load your cases.",
                  onRetry: () {
                    setState(() => _failed = false);
                    _load();
                  })
              : cases == null
                  ? const Center(child: NeonLoader())
                  : cases.isEmpty
                      ? NeonEmptyState(
                          icon: Icons.gavel_rounded,
                          title: _closed ? 'No closed cases' : 'No open cases yet',
                          body: _closed
                              ? null
                              : 'Add a case with its court and next hearing — your assistant '
                                  'reminds the client before each one.',
                        )
                      : RefreshIndicator(
                          color: Neon.violet,
                          onRefresh: _load,
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 6, 16, 100),
                            children: [
                              GroupedCard(
                                dividerInset: 16,
                                children: [for (final c in cases) _caseRow(c)],
                              ),
                            ],
                          ),
                        ),
        ),
      ]),
    );
  }

  Widget _caseRow(LegalCase c) {
    final next = c.nextHearingAt;
    final soon = next != null && next.difference(DateTime.now()).inHours < 48;
    return InkWell(
      onTap: () async {
        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => CaseDetailScreen(caseId: c.id)));
        _load();
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Neon.textHi, fontSize: 15.5, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(
                [
                  if (c.caseNumber.isNotEmpty) c.caseNumber,
                  if (c.court.isNotEmpty) c.court,
                  if (c.clientName.isNotEmpty) c.clientName,
                ].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Neon.textLo, fontSize: 12.5),
              ),
              if (next != null) ...[
                const SizedBox(height: 4),
                Row(children: [
                  Icon(Icons.event_rounded, size: 14, color: soon ? Neon.warning : Neon.violet),
                  const SizedBox(width: 4),
                  Text('Next hearing: ${followUpWhen(next)}',
                      style: TextStyle(
                          color: soon ? Neon.warning : Neon.violet,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600)),
                ]),
              ],
            ]),
          ),
          Icon(Icons.chevron_right_rounded, color: Neon.textDim),
        ]),
      ),
    );
  }
}

/* ====================================================================== */
/* New case                                                                */
/* ====================================================================== */

/// Opens the new-case sheet; returns the created case.
Future<LegalCase?> newCaseSheet(BuildContext context, {Client? client}) {
  return showModalBottomSheet<LegalCase>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Neon.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: _NewCaseSheet(client: client),
    ),
  );
}

class _NewCaseSheet extends StatefulWidget {
  const _NewCaseSheet({this.client});
  final Client? client;
  @override
  State<_NewCaseSheet> createState() => _NewCaseSheetState();
}

class _NewCaseSheetState extends State<_NewCaseSheet> {
  late Client? _client = widget.client;
  final _title = TextEditingController();
  final _number = TextEditingController();
  final _court = TextEditingController();
  final _opp = TextEditingController();
  String _stage = '';
  bool _busy = false;

  static const _stages = ['Filing', 'Notice', 'Pleadings', 'Evidence', 'Arguments', 'Judgment', 'Appeal'];

  @override
  void dispose() {
    for (final c in [_title, _number, _court, _opp]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final t = _title.text.trim();
    if (t.isEmpty || _busy) return;
    setState(() => _busy = true);
    final c = await ProService.instance.createCase(
      clientId: _client?.id,
      title: t,
      caseNumber: _number.text.trim(),
      court: _court.text.trim(),
      oppositeParty: _opp.text.trim(),
      stage: _stage,
    );
    if (!mounted) return;
    if (c == null) {
      setState(() => _busy = false);
      AppFeedback.toast("Couldn't save the case. Check your connection.");
      return;
    }
    HapticFeedback.lightImpact();
    Navigator.pop(context, c);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('New case', style: TextStyle(color: Neon.textHi, fontSize: 19, fontWeight: FontWeight.w700)),
        const SizedBox(height: 14),
        GroupedCard(children: [
          AppleRow(
            leading: IconTile(Icons.person_rounded, Neon.accentF),
            title: _client?.name ?? 'Choose client (optional)',
            titleColor: _client == null ? Neon.violet : null,
            trailing: Icon(Icons.chevron_right_rounded, color: Neon.textDim),
            onTap: () async {
              final c = await pickPatient(context);
              if (c != null) setState(() => _client = c);
            },
          ),
        ]),
        const SizedBox(height: 12),
        TextField(
          controller: _title,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(labelText: 'Case title', hintText: 'e.g. Shetty vs Kumar — rent recovery'),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: TextField(controller: _number, decoration: const InputDecoration(labelText: 'Case number'))),
          const SizedBox(width: 10),
          Expanded(
              child: TextField(
                  controller: _court,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Court'))),
        ]),
        const SizedBox(height: 10),
        TextField(
            controller: _opp,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Opposite party')),
        const SizedBox(height: 14),
        Text('Stage', style: TextStyle(color: Neon.textHi, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final s in _stages)
            ChoiceChip(
              label: Text(s),
              selected: _stage == s,
              showCheckmark: false,
              selectedColor: Neon.violet.withValues(alpha: 0.15),
              onSelected: (_) => setState(() => _stage = _stage == s ? '' : s),
            ),
        ]),
        const SizedBox(height: 18),
        ApplePrimaryButton(
          label: _busy ? 'Saving…' : 'Create case',
          onPressed: _title.text.trim().isEmpty || _busy ? null : _save,
        ),
      ]),
    );
  }
}

/* ====================================================================== */
/* Case detail                                                             */
/* ====================================================================== */

class CaseDetailScreen extends StatefulWidget {
  const CaseDetailScreen({super.key, required this.caseId});
  final int caseId;

  @override
  State<CaseDetailScreen> createState() => _CaseDetailScreenState();
}

class _CaseDetailScreenState extends State<CaseDetailScreen> {
  LegalCase? _c;
  List<Hearing> _hearings = const [];
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await ProService.instance.caseDetail(widget.caseId);
    if (!mounted) return;
    setState(() {
      if (r != null) {
        _c = r.kase;
        _hearings = r.hearings;
      }
      _failed = r == null && _c == null;
    });
  }

  Future<void> _addHearing() async {
    final ok = await _hearingSheet(context, widget.caseId);
    if (ok == true) _load();
  }

  Future<void> _setStatus(Hearing h, String status) async {
    String? outcome;
    if (status == 'done' || status == 'adjourned') {
      outcome = await _askText(context, status == 'done' ? 'What happened?' : 'Why adjourned?');
      if (outcome == null) return;
    }
    final ok = await ProService.instance.updateHearing(h.id, status: status, outcome: outcome);
    if (!ok) AppFeedback.toast("Couldn't update. Check your connection.");
    _load();
    if (ok && status == 'adjourned' && mounted) {
      AppFeedback.toast('Add the next date for this case.');
      _addHearing();
    }
  }

  Future<void> _toggleClosed() async {
    final c = _c;
    if (c == null) return;
    final r = await ProService.instance.updateCase(c.id, {'status': c.status == 'open' ? 'closed' : 'open'});
    if (r == null) AppFeedback.toast("Couldn't update. Check your connection.");
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    return Scaffold(
      backgroundColor: Neon.bg,
      appBar: appleAppBar(context, c?.title ?? 'Case', actions: [
        if (c != null)
          IconButton(
            tooltip: c.status == 'open' ? 'Close case' : 'Reopen case',
            icon: Icon(c.status == 'open' ? Icons.archive_outlined : Icons.unarchive_outlined),
            onPressed: _toggleClosed,
          ),
      ]),
      floatingActionButton: c == null
          ? null
          : FloatingActionButton.extended(
              backgroundColor: Neon.violet,
              foregroundColor: Colors.white,
              onPressed: _addHearing,
              icon: const Icon(Icons.event_rounded),
              label: const Text('Add hearing'),
            ),
      body: _failed
          ? NeonErrorState(message: "Couldn't load this case.", onRetry: _load)
          : c == null
              ? const Center(child: NeonLoader())
              : RefreshIndicator(
                  color: Neon.violet,
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    children: [
                      GroupedCard(dividerInset: 16, children: [
                        if (c.caseNumber.isNotEmpty) AppleRow(title: 'Case number', subtitle: c.caseNumber),
                        if (c.court.isNotEmpty) AppleRow(title: 'Court', subtitle: c.court),
                        if (c.oppositeParty.isNotEmpty) AppleRow(title: 'Opposite party', subtitle: c.oppositeParty),
                        if (c.stage.isNotEmpty) AppleRow(title: 'Stage', subtitle: c.stage),
                        AppleRow(
                          title: 'Client',
                          subtitle: c.clientName.isEmpty ? 'Not linked' : c.clientName,
                          trailing: c.clientId == null
                              ? null
                              : Row(mainAxisSize: MainAxisSize.min, children: [
                                  if (c.clientPhone.isNotEmpty)
                                    IconButton(
                                      tooltip: 'Call client',
                                      icon: Icon(Icons.call_rounded, color: Neon.accentE),
                                      onPressed: () => launchUrl(Uri(scheme: 'tel', path: c.clientPhone)),
                                    ),
                                  Icon(Icons.chevron_right_rounded, color: Neon.textDim),
                                ]),
                          onTap: c.clientId == null
                              ? null
                              : () => Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => ClientDetailScreen(clientId: c.clientId!))),
                        ),
                      ]),
                      const SizedBox(height: 14),
                      Row(children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.edit_note_rounded),
                            label: const Text('Draft document'),
                            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => LegalDraftScreen(caseId: c.id, clientId: c.clientId, clientName: c.clientName))),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.receipt_long_rounded),
                            label: const Text('Bill fee'),
                            onPressed: c.clientId == null
                                ? () => AppFeedback.toast('Link a client to this case first.')
                                : () => Navigator.of(context).push(MaterialPageRoute(
                                    builder: (_) => InvoiceEditorScreen(
                                        clientId: c.clientId, clientName: c.clientName, presetLine: 'Professional fee — ${c.caseNumber.isNotEmpty ? c.caseNumber : c.title}'))),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 22),
                      GroupLabel('Hearings · ${_hearings.length}'),
                      if (_hearings.isEmpty)
                        Text('No hearings yet. Add the next date — your assistant reminds the client the day before.',
                            style: TextStyle(color: Neon.textLo, fontSize: 13.5, height: 1.4))
                      else
                        GroupedCard(dividerInset: 16, children: [
                          for (final h in _hearings.reversed) _hearingRow(h),
                        ]),
                    ],
                  ),
                ),
    );
  }

  Widget _hearingRow(Hearing h) {
    final upcoming = h.status == 'upcoming';
    final color = switch (h.status) {
      'done' => Neon.success,
      'adjourned' => Neon.warning,
      'cancelled' => Neon.textDim,
      _ => Neon.violet,
    };
    return InkWell(
      onTap: upcoming
          ? () => showModalBottomSheet<void>(
                context: context,
                backgroundColor: Neon.surface,
                builder: (ctx) => SafeArea(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    for (final (s, label, icon) in const [
                      ('done', 'Hearing done', Icons.check_circle_rounded),
                      ('adjourned', 'Adjourned — set next date', Icons.update_rounded),
                      ('cancelled', 'Cancelled', Icons.event_busy_rounded),
                    ])
                      ListTile(
                        leading: Icon(icon),
                        title: Text(label),
                        onTap: () {
                          Navigator.pop(ctx);
                          _setStatus(h, s);
                        },
                      ),
                  ]),
                ),
              )
          : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Row(children: [
          Icon(Icons.event_rounded, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(followUpWhen(h.at),
                  style: TextStyle(color: Neon.textHi, fontWeight: FontWeight.w700, fontSize: 14.5)),
              Text(
                [
                  if (h.purpose.isNotEmpty) h.purpose,
                  if (!upcoming) h.status[0].toUpperCase() + h.status.substring(1),
                  if (h.outcome.isNotEmpty) h.outcome,
                ].join(' · '),
                style: TextStyle(color: Neon.textLo, fontSize: 12.5),
              ),
            ]),
          ),
          if (upcoming) Icon(Icons.more_horiz_rounded, color: Neon.textDim),
        ]),
      ),
    );
  }
}

/* ---------------- add hearing ---------------- */

Future<bool?> _hearingSheet(BuildContext context, int caseId) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Neon.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: _HearingSheet(caseId: caseId),
    ),
  );
}

class _HearingSheet extends StatefulWidget {
  const _HearingSheet({required this.caseId});
  final int caseId;
  @override
  State<_HearingSheet> createState() => _HearingSheetState();
}

class _HearingSheetState extends State<_HearingSheet> {
  DateTime? _date;
  TimeOfDay _time = const TimeOfDay(hour: 10, minute: 30);
  final _purpose = TextEditingController();
  bool _remind = true;
  bool _busy = false;

  @override
  void dispose() {
    _purpose.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _date ?? now.add(const Duration(days: 7)),
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 1095)),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _save() async {
    final d = _date;
    if (d == null || _busy) return;
    setState(() => _busy = true);
    final at = DateTime(d.year, d.month, d.day, _time.hour, _time.minute);
    final r = await ProService.instance.addHearing(widget.caseId,
        at: at, purpose: _purpose.text.trim(), remindClient: _remind);
    if (!mounted) return;
    if (r == null) {
      setState(() => _busy = false);
      AppFeedback.toast("Couldn't save the hearing. Check your connection.");
      return;
    }
    HapticFeedback.lightImpact();
    AppFeedback.toast(r.noPhone
        ? 'Hearing saved. No client number on file, so no reminder call.'
        : 'Hearing saved — the client gets a reminder call the day before.');
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Add hearing', style: TextStyle(color: Neon.textHi, fontSize: 19, fontWeight: FontWeight.w700)),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.event_rounded),
              label: Text(_date == null ? 'Pick date' : '${_date!.day}/${_date!.month}/${_date!.year}'),
              onPressed: _pickDate,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.schedule_rounded),
              label: Text(_time.format(context)),
              onPressed: () async {
                final t = await showTimePicker(context: context, initialTime: _time);
                if (t != null) setState(() => _time = t);
              },
            ),
          ),
        ]),
        const SizedBox(height: 12),
        TextField(
          controller: _purpose,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Purpose (optional)', hintText: 'e.g. Cross-examination, arguments'),
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: _remind,
          onChanged: (v) => setState(() => _remind = v),
          title: Text('Remind the client', style: TextStyle(color: Neon.textHi, fontSize: 15)),
          subtitle: Text('Your assistant calls them the day before', style: TextStyle(color: Neon.textLo, fontSize: 12.5)),
        ),
        const SizedBox(height: 10),
        ApplePrimaryButton(
          label: _busy ? 'Saving…' : 'Save hearing',
          onPressed: _date == null || _busy ? null : _save,
        ),
      ]),
    );
  }
}

Future<String?> _askText(BuildContext context, String title) {
  final c = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Neon.surface,
      title: Text(title),
      content: TextField(
        controller: c,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(hintText: 'Optional'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Save')),
      ],
    ),
  );
}
