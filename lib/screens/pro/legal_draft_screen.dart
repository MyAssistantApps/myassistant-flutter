import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../design/apple_kit.dart';
import '../../design/neon_tokens.dart';
import '../../models/client.dart';
import '../../models/clinic.dart';
import '../../services/app_feedback.dart';
import '../../services/clinic_service.dart';
import '../../services/pro_service.dart';
import '../../widgets/document_tile.dart' show openDocument;
import '../clinic/clinic_settings_screen.dart';
import '../clinic/clinic_sheets.dart';

/// ─────────────────────────────────────────────────────────────────────────
///  DRAFT A DOCUMENT — the advocate describes it, reviews it, prints it.
///
///  1. Pick the kind (legal notice, reply, affidavit, agreement, letter),
///     optionally the client, and type or dictate the facts.
///  2. The draft comes back grounded in the app's Indian-law pack: it cites
///     only provisions it was given, and every fact it did not have is a
///     [PLACEHOLDER] listed under "Check before sending".
///  3. Edit anything, then "Create PDF" on the chamber letterhead (with the
///     enrolment number), filed under the client.
/// ─────────────────────────────────────────────────────────────────────────
class LegalDraftScreen extends StatefulWidget {
  const LegalDraftScreen({super.key, this.clientId, this.clientName, this.caseId});
  final int? clientId;
  final String? clientName;
  final int? caseId;

  @override
  State<LegalDraftScreen> createState() => _LegalDraftScreenState();
}

class _LegalDraftScreenState extends State<LegalDraftScreen> {
  static const _kinds = [
    ('notice', 'Legal notice', Icons.mail_lock_rounded),
    ('reply', 'Reply to notice', Icons.reply_rounded),
    ('affidavit', 'Affidavit', Icons.verified_user_rounded),
    ('agreement', 'Agreement', Icons.handshake_rounded),
    ('letter', 'Legal letter', Icons.description_rounded),
  ];

  String _kind = 'notice';
  late int? _clientId = widget.clientId;
  late String? _clientName = widget.clientName;
  final _facts = TextEditingController();
  final _title = TextEditingController();
  final _body = TextEditingController();
  LegalDraft? _draft;
  bool _drafting = false;
  bool _creating = false;

  final AudioRecorder _rec = AudioRecorder();
  bool _recording = false;
  bool _transcribing = false;

  @override
  void dispose() {
    if (_recording) _rec.stop();
    _rec.dispose();
    for (final c in [_facts, _title, _body]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _dictate() async {
    if (_recording) {
      final path = await _rec.stop();
      setState(() {
        _recording = false;
        _transcribing = path != null;
      });
      if (path == null) return;
      final text = await ClinicService.instance.transcribeConsult(path);
      if (!mounted) return;
      setState(() => _transcribing = false);
      if (text == null || text.isEmpty) {
        AppFeedback.toast("Couldn't hear that. Try again or type it.");
        return;
      }
      final cur = _facts.text.trim();
      _facts.text = cur.isEmpty ? text : '$cur $text';
      setState(() {});
      return;
    }
    if (!await _rec.hasPermission()) {
      AppFeedback.toast('Microphone permission is needed to dictate.');
      return;
    }
    final dir = await getTemporaryDirectory();
    await _rec.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, sampleRate: 16000, bitRate: 48000, numChannels: 1),
      path: '${dir.path}/draft_${DateTime.now().millisecondsSinceEpoch}.m4a',
    );
    HapticFeedback.mediumImpact();
    setState(() => _recording = true);
  }

  Future<void> _makeDraft() async {
    final f = _facts.text.trim();
    if (f.length < 15) {
      AppFeedback.toast('Describe the facts in a sentence or two.');
      return;
    }
    setState(() => _drafting = true);
    final d = await ProService.instance
        .draftLegal(kind: _kind, facts: f, clientId: _clientId, caseId: widget.caseId);
    if (!mounted) return;
    setState(() => _drafting = false);
    if (d == null) {
      AppFeedback.toast("Couldn't draft this. Check your connection and try again.");
      return;
    }
    _title.text = d.title;
    _body.text = d.body;
    setState(() => _draft = d);
  }

  Future<void> _createPdf() async {
    if (_body.text.trim().isEmpty || _creating) return;
    final profile = ClinicService.instance.profile ?? await ClinicService.instance.loadProfile();
    if (!mounted) return;
    if (profile != null && profile.regNo.trim().isEmpty) {
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Neon.surface,
          title: const Text('No enrolment number yet'),
          content: const Text('Your letterhead prints your Bar Council enrolment number. Add it first?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Create without it')),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx, false);
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ClinicSettingsScreen()));
              },
              child: const Text('Add it'),
            ),
          ],
        ),
      );
      if (go != true) return;
    }
    setState(() => _creating = true);
    final doc = await ProService.instance
        .legalPdf(title: _title.text.trim(), body: _body.text.trim(), clientId: _clientId);
    if (!mounted) return;
    setState(() => _creating = false);
    if (doc == null) {
      AppFeedback.toast("Couldn't create the PDF. Check your connection.");
      return;
    }
    HapticFeedback.lightImpact();
    AppFeedback.toast(_clientName == null ? 'PDF saved to your documents.' : 'PDF saved to $_clientName\'s file.');
    final nav = Navigator.of(context);
    nav.pop(true);
    openDocument(nav.context, doc);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Neon.bg,
      appBar: appleAppBar(context, 'Draft a document'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: _draft == null ? _askStep() : _reviewStep(),
      ),
    );
  }

  List<Widget> _askStep() => [
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final (k, label, icon) in _kinds)
            ChoiceChip(
              avatar: Icon(icon, size: 16, color: _kind == k ? Neon.violet : Neon.textLo),
              label: Text(label),
              selected: _kind == k,
              showCheckmark: false,
              selectedColor: Neon.violet.withValues(alpha: 0.15),
              onSelected: (_) => setState(() => _kind = k),
            ),
        ]),
        const SizedBox(height: 14),
        GroupedCard(children: [
          AppleRow(
            leading: IconTile(Icons.person_rounded, Neon.accentF),
            title: _clientName ?? 'For which client? (optional)',
            titleColor: _clientName == null ? Neon.violet : null,
            trailing: Icon(Icons.chevron_right_rounded, color: Neon.textDim),
            onTap: () async {
              final Client? c = await pickPatient(context);
              if (c != null) {
                setState(() {
                  _clientId = c.id;
                  _clientName = c.name;
                });
              }
            },
          ),
        ]),
        const SizedBox(height: 14),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: TextField(
              controller: _facts,
              minLines: 5,
              maxLines: 12,
              onChanged: (_) => setState(() {}),
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Facts and instructions',
                hintText: 'e.g. Tenant hasn\'t paid 4 months\' rent of ₹60,000; vacate within 15 days.',
                alignLabelWithHint: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            tooltip: _recording ? 'Stop' : 'Dictate',
            style: IconButton.styleFrom(backgroundColor: _recording ? Neon.error : Neon.violet),
            onPressed: _transcribing ? null : _dictate,
            icon: Icon(_recording ? Icons.stop_rounded : Icons.mic_rounded, color: Colors.white),
          ),
        ]),
        if (_recording || _transcribing)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(_recording ? 'Listening… tap stop when done' : 'Transcribing…',
                style: TextStyle(color: Neon.violet, fontSize: 12.5, fontWeight: FontWeight.w600)),
          ),
        const SizedBox(height: 16),
        ApplePrimaryButton(
          label: _drafting ? 'Drafting…' : 'Draft it',
          icon: Icons.auto_awesome_rounded,
          onPressed: _drafting || _recording || _transcribing || _facts.text.trim().length < 15 ? null : _makeDraft,
        ),
        const SizedBox(height: 10),
        Text(
          'Cites only provisions from the app\'s Indian-law reference (BNS/BNSS/BSA, not repealed IPC '
          'numbers). Facts it doesn\'t have are left as [PLACEHOLDERS] for you to fill.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Neon.textDim, fontSize: 12, height: 1.4),
        ),
      ];

  List<Widget> _reviewStep() {
    final d = _draft!;
    return [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Neon.warning.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          Icon(Icons.fact_check_rounded, color: Neon.warning, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text('A draft for you to check and sign — edit anything before creating the PDF.',
                style: TextStyle(color: Neon.textHi, fontSize: 12.5, height: 1.35)),
          ),
        ]),
      ),
      if (d.advocateChecks.isNotEmpty) ...[
        const SizedBox(height: 14),
        const GroupLabel('Check before sending'),
        GroupedCard(dividerInset: 16, children: [
          for (final c in d.advocateChecks)
            AppleRow(
              leading: Icon(Icons.radio_button_unchecked_rounded, color: Neon.warning, size: 18),
              title: c,
            ),
        ]),
      ],
      if (d.provisionsCited.isNotEmpty) ...[
        const SizedBox(height: 14),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final p in d.provisionsCited)
            Chip(
              avatar: Icon(Icons.menu_book_rounded, size: 15, color: Neon.violet),
              label: Text(p, style: const TextStyle(fontSize: 12)),
              backgroundColor: Neon.violet.withValues(alpha: 0.10),
              side: BorderSide(color: Neon.violet.withValues(alpha: 0.3)),
            ),
        ]),
      ],
      const SizedBox(height: 14),
      TextField(
        controller: _title,
        textCapitalization: TextCapitalization.sentences,
        style: const TextStyle(fontWeight: FontWeight.w700),
        decoration: const InputDecoration(labelText: 'Title'),
      ),
      const SizedBox(height: 10),
      TextField(
        controller: _body,
        minLines: 14,
        maxLines: 40,
        textCapitalization: TextCapitalization.sentences,
        style: const TextStyle(fontSize: 14, height: 1.45),
        decoration: const InputDecoration(labelText: 'Document', alignLabelWithHint: true),
      ),
      const SizedBox(height: 18),
      Row(children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _creating ? null : () => setState(() => _draft = null),
            child: const Text('Back'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: ApplePrimaryButton(
            label: _creating ? 'Creating…' : 'Create PDF',
            icon: Icons.picture_as_pdf_rounded,
            onPressed: _creating ? null : _createPdf,
          ),
        ),
      ]),
    ];
  }
}
