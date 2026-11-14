import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../design/apple_kit.dart';
import '../../design/neon_tokens.dart';
import '../../models/client.dart';
import '../../models/clinic.dart';
import '../../models/user_document.dart';
import '../../services/app_feedback.dart';
import '../../services/clinic_service.dart';
import '../../widgets/document_tile.dart' show openDocument;
import 'clinic_settings_screen.dart';

/// ─────────────────────────────────────────────────────────────────────────
///  PRESCRIPTION — dictate it, check it, print it.
///
///  "Paracetamol 650 TDS for 3 days after food, pantoprazole 40 OD before
///  breakfast for 5 days, review in a week" becomes editable rows. The
///  parser transcribes; it never suggests a drug or completes a dose — a
///  field the doctor didn't say stays empty for the doctor to fill.
///
///  "Create" renders the PDF on the doctor's letterhead (Clinic settings →
///  qualifications + registration number), files it in the patient's
///  record, and opens it, ready to share on WhatsApp or print.
/// ─────────────────────────────────────────────────────────────────────────
class PrescriptionScreen extends StatefulWidget {
  const PrescriptionScreen({
    super.key,
    required this.patient,
    this.initialMeds = const [],
    this.initialDiagnosis = '',
    this.initialFollowUpDays,
  });

  final Client patient;
  final List<RxItem> initialMeds;
  final String initialDiagnosis;
  final int? initialFollowUpDays;

  @override
  State<PrescriptionScreen> createState() => _PrescriptionScreenState();
}

class _PrescriptionScreenState extends State<PrescriptionScreen> {
  final _dictation = TextEditingController();
  late final _diagnosis = TextEditingController(text: widget.initialDiagnosis);
  final _advice = TextEditingController();
  late final _followUp = TextEditingController(
      text: widget.initialFollowUpDays?.toString() ?? '');
  final _age = TextEditingController();
  String _sex = '';
  late final List<_MedRow> _rows = [
    for (final m in widget.initialMeds) _MedRow.from(m),
  ];

  final AudioRecorder _rec = AudioRecorder();
  bool _recording = false;
  bool _transcribing = false;
  bool _parsing = false;
  bool _creating = false;
  bool _letterheadMissing = false;

  static const _freq = ['OD', 'BD', 'TDS', 'QID', 'HS', 'SOS', '1-0-1', '1-1-1'];

  @override
  void initState() {
    super.initState();
    _checkLetterhead();
  }

  Future<void> _checkLetterhead() async {
    final p = ClinicService.instance.profile ??
        await ClinicService.instance.loadProfile();
    if (!mounted || p == null) return;
    setState(() => _letterheadMissing = p.regNo.trim().isEmpty);
  }

  @override
  void dispose() {
    if (_recording) _rec.stop();
    _rec.dispose();
    for (final c in [_dictation, _diagnosis, _advice, _followUp, _age]) {
      c.dispose();
    }
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  Future<void> _toggleDictate() async {
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
      final cur = _dictation.text.trim();
      _dictation.text = cur.isEmpty ? text : '$cur, $text';
      await _parse();
      return;
    }
    if (!await _rec.hasPermission()) {
      AppFeedback.toast('Microphone permission is needed to dictate.');
      return;
    }
    final dir = await getTemporaryDirectory();
    await _rec.start(
      const RecordConfig(
          encoder: AudioEncoder.aacLc, sampleRate: 16000, bitRate: 48000, numChannels: 1),
      path: '${dir.path}/rx_${DateTime.now().millisecondsSinceEpoch}.m4a',
    );
    HapticFeedback.mediumImpact();
    setState(() => _recording = true);
  }

  Future<void> _parse() async {
    final t = _dictation.text.trim();
    if (t.isEmpty || _parsing) return;
    setState(() => _parsing = true);
    final r = await ClinicService.instance.parseRx(t);
    if (!mounted) return;
    setState(() => _parsing = false);
    if (r == null) {
      AppFeedback.toast("Couldn't read that. Check your connection, or add the medicines by hand.");
      return;
    }
    setState(() {
      for (final m in r.meds) {
        _rows.add(_MedRow.from(m));
      }
      if (_diagnosis.text.trim().isEmpty) _diagnosis.text = r.diagnosis;
      if (_advice.text.trim().isEmpty) _advice.text = r.advice;
      if (_followUp.text.trim().isEmpty && r.followUpDays != null) {
        _followUp.text = '${r.followUpDays}';
      }
      _dictation.clear();
    });
    if (r.meds.isEmpty) AppFeedback.toast('No medicines found in that — add them below.');
  }

  Future<void> _create() async {
    final meds = _rows.map((r) => r.toItem()).where((m) => m.name.trim().isNotEmpty).toList();
    if (meds.isEmpty && _advice.text.trim().isEmpty) {
      AppFeedback.toast('Add at least one medicine or some advice.');
      return;
    }
    final missingDose = meds.where((m) => m.dose.trim().isEmpty || m.frequency.trim().isEmpty).toList();
    if (missingDose.isNotEmpty) {
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Some fields are empty'),
          content: Text(
              '${missingDose.map((m) => m.name).join(', ')} '
              '${missingDose.length == 1 ? 'has' : 'have'} no dose or frequency. Print anyway?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Fix it')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Print anyway')),
          ],
        ),
      );
      if (go != true) return;
    }
    setState(() => _creating = true);
    final doc = await ClinicService.instance.createRx(
      clientId: widget.patient.id,
      meds: meds,
      diagnosis: _diagnosis.text.trim(),
      advice: _advice.text.trim(),
      followUpDays: int.tryParse(_followUp.text.trim()),
      age: _age.text.trim(),
      sex: _sex,
    );
    if (!mounted) return;
    setState(() => _creating = false);
    if (doc == null) {
      AppFeedback.toast("Couldn't create the prescription. Check your connection.");
      return;
    }
    HapticFeedback.lightImpact();
    _done(doc);
  }

  void _done(UserDocument doc) {
    AppFeedback.toast('Prescription saved to ${widget.patient.name}\'s file.');
    // This screen's context dies with the pop — open from the navigator's.
    final nav = Navigator.of(context);
    nav.pop(true);
    openDocument(nav.context, doc);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Neon.bg,
      appBar: appleAppBar(context, 'Prescription — ${widget.patient.name}'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          if (_letterheadMissing)
            Material(
              color: Neon.warning.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
              child: ListTile(
                leading: Icon(Icons.info_outline_rounded, color: Neon.warning),
                title: const Text('Add your registration number'),
                subtitle: const Text('It goes on every prescription. Clinic settings →'),
                onTap: () async {
                  await Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const ClinicSettingsScreen()));
                  _checkLetterhead();
                },
              ),
            ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _dictation,
                  minLines: 2,
                  maxLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Dictate or type',
                    hintText: 'e.g. Paracetamol 650 TDS 3 days after food, review in a week',
                    alignLabelWithHint: true,
                  ),
                  onSubmitted: (_) => _parse(),
                ),
              ),
              const SizedBox(width: 8),
              Column(children: [
                IconButton.filled(
                  tooltip: _recording ? 'Stop' : 'Dictate',
                  style: IconButton.styleFrom(
                      backgroundColor: _recording ? Neon.error : Neon.violet),
                  onPressed: _transcribing ? null : _toggleDictate,
                  icon: Icon(_recording ? Icons.stop_rounded : Icons.mic_rounded,
                      color: Colors.white),
                ),
                IconButton(
                  tooltip: 'Add from text',
                  onPressed: _parsing ? null : _parse,
                  icon: Icon(Icons.playlist_add_rounded, color: Neon.violet),
                ),
              ]),
            ],
          ),
          if (_recording || _transcribing || _parsing)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                _recording
                    ? 'Listening… tap stop when done'
                    : _transcribing
                        ? 'Transcribing…'
                        : 'Reading the prescription…',
                style: TextStyle(color: Neon.violet, fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
            ),
          const SizedBox(height: 18),
          GroupLabel('Medicines · ${_rows.length}'),
          for (var i = 0; i < _rows.length; i++) _medCard(i),
          TextButton.icon(
            onPressed: () => setState(() => _rows.add(_MedRow.from(RxItem()))),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add medicine'),
          ),
          const SizedBox(height: 10),
          const GroupLabel('Patient & visit'),
          Row(children: [
            SizedBox(
              width: 90,
              child: TextField(
                controller: _age,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Age'),
              ),
            ),
            const SizedBox(width: 12),
            for (final s in const ['M', 'F', 'Other'])
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(s),
                  selected: _sex == s,
                  showCheckmark: false,
                  selectedColor: Neon.violet.withValues(alpha: 0.15),
                  onSelected: (_) => setState(() => _sex = _sex == s ? '' : s),
                ),
              ),
          ]),
          const SizedBox(height: 10),
          TextField(
            controller: _diagnosis,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Diagnosis (optional)'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _advice,
            minLines: 1,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Advice (optional)'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _followUp,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
                labelText: 'Review after (days, optional)'),
          ),
          const SizedBox(height: 20),
          ApplePrimaryButton(
            label: _creating ? 'Creating…' : 'Create prescription PDF',
            icon: Icons.picture_as_pdf_rounded,
            onPressed: _creating || _recording ? null : _create,
          ),
        ],
      ),
    );
  }

  Widget _medCard(int i) {
    final r = _rows[i];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 6, 6, 10),
      decoration: BoxDecoration(
        color: Neon.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Neon.line),
      ),
      child: Column(children: [
        Row(children: [
          Expanded(
            child: TextField(
              controller: r.name,
              textCapitalization: TextCapitalization.words,
              style: const TextStyle(fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                labelText: '${i + 1}. Medicine',
                border: InputBorder.none,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Remove',
            icon: Icon(Icons.delete_outline_rounded, color: Neon.textDim),
            onPressed: () => setState(() {
              _rows.removeAt(i).dispose();
            }),
          ),
        ]),
        // Room for the floating Dose / Frequency / Duration labels.
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _small(r.dose, 'Dose')),
          const SizedBox(width: 8),
          Expanded(child: _small(r.frequency, 'Frequency')),
          const SizedBox(width: 8),
          Expanded(child: _small(r.duration, 'Duration')),
        ]),
        const SizedBox(height: 6),
        SizedBox(
          height: 34,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final f in _freq)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ActionChip(
                    label: Text(f, style: const TextStyle(fontSize: 12)),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => setState(() => r.frequency.text = f),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        _small(r.instructions, 'Instructions (e.g. after food)'),
      ]),
    );
  }

  Widget _small(TextEditingController c, String label) => TextField(
        controller: c,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(labelText: label, isDense: true),
      );
}

class _MedRow {
  final TextEditingController name;
  final TextEditingController dose;
  final TextEditingController frequency;
  final TextEditingController duration;
  final TextEditingController instructions;

  _MedRow.from(RxItem m)
      : name = TextEditingController(text: m.name),
        dose = TextEditingController(text: m.dose),
        frequency = TextEditingController(text: m.frequency),
        duration = TextEditingController(text: m.duration),
        instructions = TextEditingController(text: m.instructions);

  RxItem toItem() => RxItem(
        name: name.text,
        dose: dose.text,
        frequency: frequency.text,
        duration: duration.text,
        instructions: instructions.text,
      );

  void dispose() {
    for (final c in [name, dose, frequency, duration, instructions]) {
      c.dispose();
    }
  }
}
