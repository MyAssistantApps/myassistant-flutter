import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../design/apple_kit.dart';
import '../../design/neon_tokens.dart';
import '../../design/neon_widgets.dart';
import '../../models/clinic.dart';
import '../../services/app_feedback.dart';
import '../../services/pro_service.dart';
import '../clinic/clinic_sheets.dart' show followUpWhen;

/// ─────────────────────────────────────────────────────────────────────────
///  LEADS & DEALS — the pipeline, ordered by who to call next.
///
///  Each deal carries a value, a stage (new → contacted → proposal → won /
///  lost) and the next follow-up date; the ones due today are at the top
///  and on the assistant's Today card. Winning a deal turns it into a
///  client, so invoices, dues and meetings attach to a real record.
/// ─────────────────────────────────────────────────────────────────────────
class LeadsScreen extends StatefulWidget {
  const LeadsScreen({super.key});

  @override
  State<LeadsScreen> createState() => _LeadsScreenState();
}

class _LeadsScreenState extends State<LeadsScreen> {
  bool _all = false;
  List<Lead>? _leads;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await ProService.instance.leads(all: _all);
    if (!mounted) return;
    setState(() {
      _leads = r ?? _leads;
      _failed = r == null && _leads == null;
    });
  }

  Future<void> _edit([Lead? l]) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Neon.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _LeadSheet(lead: l),
      ),
    );
    if (ok == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final leads = _leads;
    final value = (leads ?? const <Lead>[])
        .where((l) => l.stage != 'won' && l.stage != 'lost')
        .fold<double>(0, (s, l) => s + l.value);
    return Scaffold(
      backgroundColor: Neon.bg,
      appBar: appleAppBar(context, 'Leads & deals'),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Neon.violet,
        foregroundColor: Colors.white,
        onPressed: () => _edit(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New lead'),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Open pipeline')),
              ButtonSegment(value: true, label: Text('All, incl. won/lost')),
            ],
            selected: {_all},
            onSelectionChanged: (s) {
              setState(() {
                _all = s.first;
                _leads = null;
              });
              _load();
            },
          ),
        ),
        Expanded(
          child: _failed
              ? NeonErrorState(
                  message: "Couldn't load leads.",
                  onRetry: () {
                    setState(() => _failed = false);
                    _load();
                  })
              : leads == null
                  ? const Center(child: NeonLoader())
                  : leads.isEmpty
                      ? const NeonEmptyState(
                          icon: Icons.trending_up_rounded,
                          title: 'No open deals',
                          body: 'Add a lead with a follow-up date — it shows on your Today card when it\'s due.',
                        )
                      : RefreshIndicator(
                          color: Neon.violet,
                          onRefresh: _load,
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 6, 16, 100),
                            children: [
                              if (value > 0)
                                Padding(
                                  padding: const EdgeInsets.only(left: 4, bottom: 10),
                                  child: Text('Pipeline value ${rupees(value)}',
                                      style: TextStyle(color: Neon.textLo, fontWeight: FontWeight.w600)),
                                ),
                              GroupedCard(dividerInset: 16, children: [for (final l in leads) _row(l)]),
                            ],
                          ),
                        ),
        ),
      ]),
    );
  }

  Widget _row(Lead l) {
    final due = l.nextFollowUp != null && l.nextFollowUp!.isBefore(DateTime.now().add(const Duration(hours: 12)));
    final closed = l.stage == 'won' || l.stage == 'lost';
    return InkWell(
      onTap: () => _edit(l),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 6, 12),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l.company.isEmpty ? l.name : '${l.name} · ${l.company}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Neon.textHi, fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(
                [
                  leadStageLabel[l.stage] ?? l.stage,
                  if (l.value > 0) rupees(l.value),
                  if (!closed && l.nextFollowUp != null) 'follow up ${followUpWhen(l.nextFollowUp!)}',
                ].join(' · '),
                style: TextStyle(
                    color: closed
                        ? (l.stage == 'won' ? Neon.success : Neon.textDim)
                        : (due ? Neon.warning : Neon.textLo),
                    fontSize: 12.5),
              ),
            ]),
          ),
          if (l.phone.isNotEmpty)
            IconButton(
              tooltip: 'Call ${l.name}',
              icon: Icon(Icons.call_rounded, color: Neon.accentE),
              onPressed: () => launchUrl(Uri(scheme: 'tel', path: l.phone)),
            ),
        ]),
      ),
    );
  }
}

class _LeadSheet extends StatefulWidget {
  const _LeadSheet({this.lead});
  final Lead? lead;
  @override
  State<_LeadSheet> createState() => _LeadSheetState();
}

class _LeadSheetState extends State<_LeadSheet> {
  late final _name = TextEditingController(text: widget.lead?.name ?? '');
  late final _company = TextEditingController(text: widget.lead?.company ?? '');
  late final _phone = TextEditingController(text: widget.lead?.phone ?? '');
  late final _value = TextEditingController(
      text: (widget.lead?.value ?? 0) > 0 ? widget.lead!.value.toStringAsFixed(0) : '');
  late final _note = TextEditingController(text: widget.lead?.note ?? '');
  late String _stage = widget.lead?.stage ?? 'new';
  late int? _followDays = widget.lead == null ? 2 : null;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_name, _company, _phone, _value, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  DateTime? get _follow {
    if (_followDays == null) return null;
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day, 10).add(Duration(days: _followDays!));
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty || _busy) return;
    setState(() => _busy = true);
    final value = double.tryParse(_value.text.replaceAll(',', '').trim()) ?? 0;
    final Lead? r;
    if (widget.lead == null) {
      r = await ProService.instance.createLead(
        name: _name.text.trim(),
        company: _company.text.trim(),
        phone: _phone.text.trim(),
        value: value,
        nextFollowUp: _follow,
        note: _note.text.trim(),
      );
    } else {
      r = await ProService.instance.updateLead(widget.lead!.id, {
        'name': _name.text.trim(),
        'company': _company.text.trim(),
        'phone': _phone.text.trim(),
        'value': value,
        'stage': _stage,
        'note': _note.text.trim(),
        if (_followDays != null) 'nextFollowUp': _follow!.millisecondsSinceEpoch,
      });
    }
    if (!mounted) return;
    if (r == null) {
      setState(() => _busy = false);
      AppFeedback.toast("Couldn't save. Check your connection.");
      return;
    }
    HapticFeedback.lightImpact();
    if (r.stage == 'won' && widget.lead?.stage != 'won') {
      AppFeedback.toast('Deal won — ${r.name} is now a client.');
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.lead != null;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(editing ? 'Deal' : 'New lead',
            style: TextStyle(color: Neon.textHi, fontSize: 19, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        TextField(
            controller: _name,
            autofocus: !editing,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Name')),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
              child: TextField(
                  controller: _company,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Company'))),
          const SizedBox(width: 10),
          Expanded(
              child: TextField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone'))),
        ]),
        const SizedBox(height: 10),
        TextField(
            controller: _value,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Deal value', prefixText: '₹ ')),
        if (editing) ...[
          const SizedBox(height: 14),
          Text('Stage', style: TextStyle(color: Neon.textHi, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final s in leadStages)
              ChoiceChip(
                label: Text(leadStageLabel[s]!),
                selected: _stage == s,
                showCheckmark: false,
                selectedColor: (s == 'won' ? Neon.success : s == 'lost' ? Neon.error : Neon.violet)
                    .withValues(alpha: 0.15),
                onSelected: (_) => setState(() => _stage = s),
              ),
          ]),
        ],
        const SizedBox(height: 14),
        Text(editing ? 'Next follow-up (leave to keep as is)' : 'Follow up',
            style: TextStyle(color: Neon.textHi, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final (d, label) in const [(0, 'Today'), (1, 'Tomorrow'), (2, 'In 2 days'), (7, 'Next week'), (30, 'Next month')])
            ChoiceChip(
              label: Text(label),
              selected: _followDays == d,
              showCheckmark: false,
              selectedColor: Neon.violet.withValues(alpha: 0.15),
              onSelected: (_) => setState(() => _followDays = _followDays == d ? null : d),
            ),
        ]),
        const SizedBox(height: 12),
        TextField(
            controller: _note,
            minLines: 1,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Note (optional)')),
        const SizedBox(height: 18),
        ApplePrimaryButton(
          label: _busy ? 'Saving…' : (editing ? 'Save' : 'Add lead'),
          onPressed: _name.text.trim().isEmpty || _busy ? null : _save,
        ),
      ]),
    );
  }
}
