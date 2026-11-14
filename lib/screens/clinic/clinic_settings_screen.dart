import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design/apple_kit.dart';
import '../../design/neon_tokens.dart';
import '../../design/neon_widgets.dart';
import '../../models/clinic.dart';
import '../../services/app_feedback.dart';
import '../../services/clinic_service.dart';
import '../../services/pro_words.dart';
import '../../services/persona.dart';

/// ─────────────────────────────────────────────────────────────────────────
///  CLINIC SETTINGS — set once, used everywhere.
///
///  The timings drive the free slots (booking sheet AND the phone
///  receptionist); name, address, fee and timings are what the receptionist
///  may tell callers; qualification and registration number go on every
///  prescription letterhead. Each day is a row with up to two sessions,
///  because an Indian OPD is usually "morning + evening".
/// ─────────────────────────────────────────────────────────────────────────
class ClinicSettingsScreen extends StatefulWidget {
  const ClinicSettingsScreen({super.key});

  @override
  State<ClinicSettingsScreen> createState() => _ClinicSettingsScreenState();
}

class _ClinicSettingsScreenState extends State<ClinicSettingsScreen> {
  ClinicProfile? _p;
  bool _failed = false;
  bool _saving = false;
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _phone = TextEditingController();
  final _fee = TextEditingController();
  final _qual = TextEditingController();
  final _reg = TextEditingController();

  static const _dayLabel = {
    'mon': 'Monday', 'tue': 'Tuesday', 'wed': 'Wednesday', 'thu': 'Thursday',
    'fri': 'Friday', 'sat': 'Saturday', 'sun': 'Sunday',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [_name, _address, _phone, _fee, _qual, _reg]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final p = await ClinicService.instance.loadProfile();
    if (!mounted) return;
    if (p == null) {
      setState(() => _failed = true);
      return;
    }
    _name.text = p.clinicName;
    _address.text = p.address;
    _phone.text = p.phone;
    _fee.text = p.fee > 0 ? p.fee.toStringAsFixed(p.fee % 1 == 0 ? 0 : 2) : '';
    _qual.text = p.qualification;
    _reg.text = p.regNo;
    setState(() => _p = p);
  }

  Future<void> _save() async {
    final p = _p;
    if (p == null || _saving) return;
    p
      ..clinicName = _name.text.trim()
      ..address = _address.text.trim()
      ..phone = _phone.text.trim()
      ..fee = double.tryParse(_fee.text.trim()) ?? 0
      ..qualification = _qual.text.trim()
      ..regNo = _reg.text.trim();
    setState(() => _saving = true);
    final ok = await ClinicService.instance.saveProfile(p);
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      HapticFeedback.lightImpact();
      AppFeedback.toast('Clinic settings saved.');
      Navigator.pop(context, true);
    } else {
      AppFeedback.toast("Couldn't save. Check your connection.");
    }
  }

  Future<String?> _pickTime(String current) async {
    final parts = current.split(':');
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
          hour: int.tryParse(parts.first) ?? 10,
          minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0),
    );
    if (t == null) return null;
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  String _fmt(String hm) {
    final p = hm.split(':');
    final h = int.tryParse(p[0]) ?? 0;
    final m = p.length > 1 ? p[1] : '00';
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return '$h12:$m ${h < 12 ? 'am' : 'pm'}';
  }

  @override
  Widget build(BuildContext context) {
    final p = _p;
    return Scaffold(
      backgroundColor: Neon.bg,
      appBar: appleAppBar(context, ProWords.current.settings, actions: [
        TextButton(
          onPressed: p == null || _saving ? null : _save,
          child: Text(_saving ? 'Saving…' : 'Save',
              style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      ]),
      body: _failed
          ? NeonErrorState(
              message: "Couldn't load your clinic settings.",
              onRetry: () {
                setState(() => _failed = false);
                _load();
              })
          : p == null
              ? const Center(child: NeonLoader())
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 60),
                  children: [
                    GroupLabel(ProWords.current.workspace),
                    _field(_name, ProWords.current.placeName, Icons.business_rounded),
                    _field(_address, 'Address', Icons.place_outlined, lines: 2),
                    _field(_phone, 'Clinic phone', Icons.phone_outlined,
                        type: TextInputType.phone),
                    if (ProWords.current.feeLabel != null)
                    _field(_fee, ProWords.current.feeLabel!, Icons.currency_rupee_rounded,
                        type: TextInputType.number),
                    const SizedBox(height: 18),
                    GroupLabel(Persona.isDoctor
                        ? 'On your prescriptions'
                        : Persona.value == 'advocate'
                            ? 'On your letterhead'
                            : 'On your invoices'),
                    _field(_qual, ProWords.current.qualification, Icons.school_outlined),
                    _field(_reg, ProWords.current.regNo, Icons.verified_outlined),
                    const SizedBox(height: 18),
                    const GroupLabel('Timings'),
                    GroupedCard(children: [
                      for (final d in clinicDays) _dayRow(p, d),
                    ]),
                    const SizedBox(height: 14),
                    Text('${ProWords.current.appointment[0].toUpperCase()}${ProWords.current.appointment.substring(1)} length',
                        style: TextStyle(
                            color: Neon.textHi,
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, children: [
                      for (final m in const [10, 15, 20, 30])
                        ChoiceChip(
                          label: Text('$m min'),
                          selected: p.slotMin == m,
                          showCheckmark: false,
                          selectedColor: Neon.violet.withValues(alpha: 0.15),
                          onSelected: (_) => setState(() => p.slotMin = m),
                        ),
                    ]),
                    const SizedBox(height: 22),
                    const GroupLabel('Phone receptionist'),
                    GroupedCard(children: [
                      SwitchListTile.adaptive(
                        value: p.receptionistBooks,
                        onChanged: (v) => setState(() => p.receptionistBooks = v),
                        title: Text('Book ${ProWords.current.appointments.toLowerCase()} on calls',
                            style: TextStyle(color: Neon.textHi, fontSize: 15)),
                        subtitle: Text(
                            ProWords.current.receptionist,
                            style: TextStyle(color: Neon.textLo, fontSize: 12.5, height: 1.35)),
                      ),
                    ]),
                  ],
                ),
    );
  }

  Widget _field(TextEditingController c, String label, IconData icon,
      {int lines = 1, TextInputType? type}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c,
        minLines: lines,
        maxLines: lines,
        keyboardType: type,
        textCapitalization: type == null
            ? TextCapitalization.words
            : TextCapitalization.none,
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      ),
    );
  }

  Widget _dayRow(ClinicProfile p, String d) {
    final sessions = p.hours[d] ?? [];
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_dayLabel[d]!,
                  style: TextStyle(
                      color: Neon.textHi,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600)),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (sessions.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('Closed',
                        style: TextStyle(color: Neon.textDim, fontSize: 14)),
                  ),
                for (var i = 0; i < sessions.length; i++)
                  Row(children: [
                    TextButton(
                      onPressed: () async {
                        final t = await _pickTime(sessions[i][0]);
                        if (t != null) setState(() => sessions[i][0] = t);
                      },
                      child: Text(_fmt(sessions[i][0])),
                    ),
                    Text('–', style: TextStyle(color: Neon.textLo)),
                    TextButton(
                      onPressed: () async {
                        final t = await _pickTime(sessions[i][1]);
                        if (t != null) setState(() => sessions[i][1] = t);
                      },
                      child: Text(_fmt(sessions[i][1])),
                    ),
                    IconButton(
                      tooltip: 'Remove session',
                      icon: Icon(Icons.close_rounded, size: 18, color: Neon.textDim),
                      onPressed: () => setState(() => sessions.removeAt(i)),
                    ),
                  ]),
              ],
            ),
          ),
          if (sessions.length < 2)
            IconButton(
              tooltip: 'Add session',
              icon: Icon(Icons.add_circle_outline_rounded, color: Neon.violet),
              onPressed: () => setState(() {
                p.hours[d] = [
                  ...sessions,
                  sessions.isEmpty ? ['10:00', '13:00'] : ['17:00', '20:00'],
                ];
              }),
            ),
        ],
      ),
    );
  }
}
