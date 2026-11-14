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
import 'clinic_sheets.dart';
import 'prescription_screen.dart';

/// ─────────────────────────────────────────────────────────────────────────
///  CONSULT NOTE — the doctor talks to the patient; the note writes itself.
///
///  1. Record the consultation (only after ticking that the patient agreed),
///     or type / paste / dictate. Several recordings append — a pause to
///     examine the patient doesn't lose the first half.
///  2. "Draft note" → a SOAP draft from the clinical model, which records
///     ONLY what was said (no invented findings, no suggested drugs).
///  3. The doctor edits anything, then saves it into the case file — and is
///     offered the follow-up and prescription the draft found, one tap each.
///
///  Nothing reaches the record without the doctor pressing Save.
/// ─────────────────────────────────────────────────────────────────────────
class ConsultNoteScreen extends StatefulWidget {
  const ConsultNoteScreen({super.key, required this.patient});
  final Client patient;

  @override
  State<ConsultNoteScreen> createState() => _ConsultNoteScreenState();
}

class _ConsultNoteScreenState extends State<ConsultNoteScreen> {
  final _transcript = TextEditingController();
  final AudioRecorder _rec = AudioRecorder();
  bool _consent = false;
  bool _recording = false;
  bool _transcribing = false;
  int _seconds = 0;
  Timer? _timer;

  bool _drafting = false;
  SoapNote? _note;
  final _s = TextEditingController();
  final _o = TextEditingController();
  final _a = TextEditingController();
  final _p = TextEditingController();
  final _cc = TextEditingController();
  bool _saving = false;

  static const _maxSeconds = 20 * 60;

  @override
  void dispose() {
    _timer?.cancel();
    if (_recording) _rec.stop();
    _rec.dispose();
    for (final c in [_transcript, _s, _o, _a, _p, _cc]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _toggleRecord() async {
    if (_recording) return _stop();
    if (!_consent) {
      AppFeedback.toast('Tick that the patient agreed to recording first.');
      return;
    }
    if (!await _rec.hasPermission()) {
      AppFeedback.toast('Microphone permission is needed to record.');
      return;
    }
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/consult_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _rec.start(
      const RecordConfig(
          encoder: AudioEncoder.aacLc, sampleRate: 16000, bitRate: 48000, numChannels: 1),
      path: path,
    );
    HapticFeedback.mediumImpact();
    setState(() {
      _recording = true;
      _seconds = 0;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _seconds++);
      if (_seconds >= _maxSeconds) _stop();
    });
  }

  Future<void> _stop() async {
    _timer?.cancel();
    final path = await _rec.stop();
    HapticFeedback.lightImpact();
    setState(() {
      _recording = false;
      _transcribing = path != null;
    });
    if (path == null) return;
    final text = await ClinicService.instance.transcribeConsult(path);
    if (!mounted) return;
    setState(() => _transcribing = false);
    if (text == null || text.isEmpty) {
      AppFeedback.toast("Couldn't transcribe that recording. Try again, or type the notes.");
      return;
    }
    final cur = _transcript.text.trim();
    _transcript.text = cur.isEmpty ? text : '$cur\n$text';
    setState(() {});
  }

  Future<void> _draft() async {
    final t = _transcript.text.trim();
    if (t.length < 20) {
      AppFeedback.toast('Add a bit more of the consultation first.');
      return;
    }
    setState(() => _drafting = true);
    final r = await ClinicService.instance
        .draftConsult(clientId: widget.patient.id, transcript: t);
    if (!mounted) return;
    setState(() => _drafting = false);
    if (r == null) {
      AppFeedback.toast("Couldn't draft the note. Check your connection and try again.");
      return;
    }
    final n = r.note;
    _cc.text = n.chiefComplaint;
    _s.text = n.subjective;
    _o.text = n.objective;
    _a.text = n.assessment;
    _p.text = n.plan;
    setState(() {
      _note = n;
    });
  }

  Future<void> _save() async {
    final n = _note;
    if (n == null || _saving) return;
    n
      ..chiefComplaint = _cc.text
      ..subjective = _s.text
      ..objective = _o.text
      ..assessment = _a.text
      ..plan = _p.text;
    setState(() => _saving = true);
    final ok = await ClinicService.instance
        .saveConsult(clientId: widget.patient.id, text: n.toText());
    if (!mounted) return;
    setState(() => _saving = false);
    if (!ok) {
      AppFeedback.toast("Couldn't save. Check your connection.");
      return;
    }
    HapticFeedback.lightImpact();
    AppFeedback.toast('Consultation saved to ${widget.patient.name}\'s file.');
    await _afterSave(n);
    if (mounted) Navigator.pop(context, true);
  }

  /// One-tap follow-ups the draft found: a prescription and a review date.
  Future<void> _afterSave(SoapNote n) async {
    final meds = n.medications.where((m) => m.name.trim().isNotEmpty).toList();
    final fu = n.followUpDays;
    if (meds.isEmpty && (fu == null || fu <= 0)) return;
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Neon.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 10),
          if (meds.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.medication_rounded),
              title: const Text('Write the prescription'),
              subtitle: Text('${meds.length} medicine${meds.length == 1 ? '' : 's'} from this consult'),
              onTap: () => Navigator.pop(ctx, 'rx'),
            ),
          if (fu != null && fu > 0)
            ListTile(
              leading: const Icon(Icons.event_repeat_rounded),
              title: Text('Schedule review in $fu day${fu == 1 ? '' : 's'}'),
              onTap: () => Navigator.pop(ctx, 'fu'),
            ),
          ListTile(
            leading: const Icon(Icons.close_rounded),
            title: const Text('Not now'),
            onTap: () => Navigator.pop(ctx),
          ),
        ]),
      ),
    );
    if (!mounted) return;
    if (choice == 'rx') {
      await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => PrescriptionScreen(
                patient: widget.patient,
                initialMeds: meds,
                initialDiagnosis: n.assessment,
                initialFollowUpDays: fu,
              )));
    } else if (choice == 'fu') {
      await scheduleFollowUp(context, patient: widget.patient);
    }
  }

  String get _clock =>
      '${(_seconds ~/ 60).toString().padLeft(2, '0')}:${(_seconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Neon.bg,
      appBar: appleAppBar(context, 'Consult — ${widget.patient.name}'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: _note == null ? _captureStep() : _reviewStep(),
      ),
    );
  }

  List<Widget> _captureStep() => [
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _consent,
          onChanged: _recording ? null : (v) => setState(() => _consent = v == true),
          controlAffinity: ListTileControlAffinity.leading,
          title: Text('The patient agreed to this consultation being recorded',
              style: TextStyle(color: Neon.textHi, fontSize: 14.5)),
          subtitle: Text('Audio is transcribed and then deleted. Only the text is kept.',
              style: TextStyle(color: Neon.textLo, fontSize: 12.5)),
        ),
        const SizedBox(height: 10),
        Center(
          child: GestureDetector(
            onTap: _transcribing ? null : _toggleRecord,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _recording
                    ? Neon.error
                    : (_consent ? Neon.violet : Neon.textDim.withValues(alpha: 0.4)),
                boxShadow: _recording ? Neon.glow(Neon.error) : null,
              ),
              child: Icon(_recording ? Icons.stop_rounded : Icons.mic_rounded,
                  color: Colors.white, size: 40),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: Text(
            _transcribing
                ? 'Transcribing…'
                : _recording
                    ? 'Recording  $_clock  — tap to stop'
                    : 'Tap to record the consultation',
            style: TextStyle(
                color: _recording ? Neon.error : Neon.textLo,
                fontSize: 13.5,
                fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _transcript,
          minLines: 6,
          maxLines: 14,
          onChanged: (_) => setState(() {}),
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Consultation transcript or your notes',
            hintText: 'Recordings appear here. You can also type or dictate with the keyboard mic.',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 16),
        ApplePrimaryButton(
          label: _drafting ? 'Drafting the note…' : 'Draft note',
          icon: Icons.auto_awesome_rounded,
          onPressed: _drafting || _recording || _transcribing ||
                  _transcript.text.trim().length < 20
              ? null
              : _draft,
        ),
        if (_drafting) ...[
          const SizedBox(height: 10),
          Text('This can take up to a minute for a long consultation.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Neon.textDim, fontSize: 12)),
        ],
      ];

  List<Widget> _reviewStep() {
    final n = _note!;
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
            child: Text(
              'Draft — check every line before saving. '
              'It records only what was said; edit anything that is wrong.',
              style: TextStyle(color: Neon.textHi, fontSize: 12.5, height: 1.35),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 14),
      _box(_cc, 'Chief complaint', 1),
      _box(_s, 'S — Subjective', 3),
      _box(_o, 'O — Objective', 3),
      _box(_a, 'A — Assessment', 2),
      _box(_p, 'P — Plan', 3),
      if (n.medications.isNotEmpty) ...[
        const SizedBox(height: 6),
        const GroupLabel('Medicines mentioned'),
        GroupedCard(children: [
          for (var i = 0; i < n.medications.length; i++)
            AppleRow(
              leading: IconTile(Icons.medication_rounded, Neon.accentE),
              title: n.medications[i].name,
              subtitle: n.medications[i].line,
              trailing: IconButton(
                tooltip: 'Remove',
                icon: Icon(Icons.close_rounded, color: Neon.textDim),
                onPressed: () => setState(() => n.medications.removeAt(i)),
              ),
            ),
        ]),
      ],
      if (n.redFlags.isNotEmpty) ...[
        const SizedBox(height: 12),
        Text('Warning signs told to patient: ${n.redFlags.join('; ')}',
            style: TextStyle(color: Neon.textLo, fontSize: 13)),
      ],
      if (n.followUpDays != null && n.followUpDays! > 0) ...[
        const SizedBox(height: 8),
        Text('Review in ${n.followUpDays} days',
            style: TextStyle(color: Neon.textHi, fontSize: 14, fontWeight: FontWeight.w600)),
      ],
      const SizedBox(height: 18),
      Row(children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _saving ? null : () => setState(() => _note = null),
            child: const Text('Back'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: ApplePrimaryButton(
            label: _saving ? 'Saving…' : 'Save to patient file',
            onPressed: _saving ? null : _save,
          ),
        ),
      ]),
    ];
  }

  Widget _box(TextEditingController c, String label, int lines) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: c,
          minLines: lines,
          maxLines: lines + 4,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(labelText: label, alignLabelWithHint: true),
        ),
      );
}
