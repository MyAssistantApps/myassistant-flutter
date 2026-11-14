import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design/apple_kit.dart';
import '../../design/neon_tokens.dart';
import '../../models/client.dart';
import '../../services/api_service.dart';
import '../../services/app_feedback.dart';
import '../../services/clinic_service.dart';
import '../../services/pro_words.dart';
import '../../services/persona.dart';

/// ─────────────────────────────────────────────────────────────────────────
///  CLINIC SHEETS — the three things a doctor does between patients.
///
///  Every sheet is built for one thumb and a few seconds: the common choice
///  is preselected (10 am, "call the patient the day before", Paid), dates
///  are chips rather than a calendar, and a patient who isn't on file yet
///  can be added inline without leaving the sheet.
/// ─────────────────────────────────────────────────────────────────────────

Future<T?> _sheet<T>(BuildContext context, Widget child) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Neon.surface,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: child,
    ),
  );
}

Widget _handle() => Center(
      child: Container(
        width: 38,
        height: 4,
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
            color: Neon.line, borderRadius: BorderRadius.circular(2)),
      ),
    );

Widget _title(String t) => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Text(t,
          style: TextStyle(
              color: Neon.textHi, fontSize: 19, fontWeight: FontWeight.w700)),
    );

/* ====================================================================== */
/* Patient picker                                                          */
/* ====================================================================== */

Future<Client?> pickPatient(BuildContext context) =>
    _sheet<Client>(context, const _PatientPicker());

class _PatientPicker extends StatefulWidget {
  const _PatientPicker();
  @override
  State<_PatientPicker> createState() => _PatientPickerState();
}

class _PatientPickerState extends State<_PatientPicker> {
  List<Client>? _all;
  bool _failed = false;
  String _q = '';
  bool _adding = false;
  final _phone = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final rows = await ApiService.fetchClients();
      if (mounted) setState(() => _all = rows);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  List<Client> get _matches {
    final q = _q.trim().toLowerCase();
    final rows = _all ?? const <Client>[];
    final m = q.isEmpty
        ? rows
        : rows
            .where((c) =>
                c.name.toLowerCase().contains(q) || c.phone.contains(q))
            .toList();
    return m.take(40).toList();
  }

  Future<void> _create() async {
    final name = _q.trim();
    if (name.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      final c = await ApiService.createClient(
          name: name, kind: Persona.isDoctor ? 'patient' : 'client', phone: _phone.text.trim());
      if (mounted) Navigator.pop(context, c);
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        AppFeedback.toast("Couldn't add the patient. Try again.");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _q.trim();
    final exact = (_all ?? const <Client>[])
        .any((c) => c.name.toLowerCase() == q.toLowerCase());
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.72,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _handle(),
            _title('Choose ${ProWords.current.person.toLowerCase()}'),
            TextField(
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              onChanged: (v) => setState(() {
                _q = v;
                _adding = false;
              }),
              decoration: const InputDecoration(
                hintText: 'Search or type a new name',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: 10),
            if (q.isNotEmpty && !exact) ...[
              if (!_adding)
                AppleRow(
                  leading: IconTile(Icons.person_add_alt_1_rounded, Neon.violet),
                  title: 'Add "$q" as a new ${ProWords.current.person.toLowerCase()}',
                  onTap: () => setState(() => _adding = true),
                )
              else
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _phone,
                      autofocus: true,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone (for reminder calls)',
                        prefixIcon: Icon(Icons.phone_rounded),
                      ),
                      onSubmitted: (_) => _create(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: _busy ? null : _create,
                    child: Text(_busy ? '…' : 'Add'),
                  ),
                ]),
              const SizedBox(height: 8),
            ],
            Expanded(
              child: _failed
                  ? Center(
                      child: TextButton(
                          onPressed: () {
                            setState(() => _failed = false);
                            _load();
                          },
                          child: const Text("Couldn't load patients — retry")))
                  : _all == null
                      ? const Center(
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : ListView(
                          children: [
                            for (final c in _matches)
                              AppleRow(
                                leading: CircleAvatar(
                                  radius: 15,
                                  backgroundColor:
                                      Neon.violet.withValues(alpha: 0.15),
                                  child: Text(
                                      c.name.isEmpty
                                          ? '?'
                                          : c.name[0].toUpperCase(),
                                      style: TextStyle(
                                          color: Neon.violet,
                                          fontWeight: FontWeight.w700)),
                                ),
                                title: c.name,
                                subtitle: c.phone.isNotEmpty
                                    ? c.phone
                                    : (c.summary.isNotEmpty ? c.summary : null),
                                onTap: () => Navigator.pop(context, c),
                              ),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ====================================================================== */
/* Schedule follow-up                                                      */
/* ====================================================================== */

/// Returns true when a follow-up was scheduled.
Future<bool?> scheduleFollowUp(BuildContext context, {Client? patient}) =>
    _sheet<bool>(context, _FollowUpSheet(patient: patient));

class _FollowUpSheet extends StatefulWidget {
  const _FollowUpSheet({this.patient});
  final Client? patient;
  @override
  State<_FollowUpSheet> createState() => _FollowUpSheetState();
}

class _FollowUpSheetState extends State<_FollowUpSheet> {
  late Client? _patient = widget.patient;
  final _note = TextEditingController();
  int? _days = 7; // null = custom date
  DateTime? _customDate;
  TimeOfDay _time = const TimeOfDay(hour: 10, minute: 0);
  bool _callPatient = true;
  bool _busy = false;

  static const _quick = [
    (1, 'Tomorrow'),
    (3, '3 days'),
    (7, '1 week'),
    (14, '2 weeks'),
    (30, '1 month'),
    (90, '3 months'),
    (180, '6 months'),
  ];

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  DateTime get _due {
    final now = DateTime.now();
    final d = _days != null
        ? DateTime(now.year, now.month, now.day).add(Duration(days: _days!))
        : (_customDate ?? now);
    return DateTime(d.year, d.month, d.day, _time.hour, _time.minute);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _customDate ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 730)),
    );
    if (d != null) {
      setState(() {
        _customDate = d;
        _days = null;
      });
    }
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: _time);
    if (t != null) setState(() => _time = t);
  }

  Future<void> _save() async {
    final p = _patient;
    if (p == null || _busy) return;
    if (_due.isBefore(DateTime.now())) {
      AppFeedback.toast('Pick a time in the future.');
      return;
    }
    setState(() => _busy = true);
    final r = await ClinicService.instance.scheduleFollowUp(
      clientId: p.id,
      dueAt: _due,
      note: _note.text.trim(),
      notifyPatient: _callPatient,
    );
    if (!mounted) return;
    if (r == null) {
      setState(() => _busy = false);
      AppFeedback.toast("Couldn't schedule. Check your connection.");
      return;
    }
    HapticFeedback.lightImpact();
    AppFeedback.toast(r.noPhone
        ? 'Follow-up set. No phone on file, so your assistant can\'t call ${p.name}.'
        : 'Follow-up set for ${p.name}, ${_label(_due)}.');
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final p = _patient;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _handle(),
          _title('Schedule follow-up'),
          GroupedCard(children: [
            AppleRow(
              leading: IconTile(Icons.person_rounded, Neon.accentF),
              title: p?.name ?? 'Choose ${ProWords.current.person.toLowerCase()}',
              titleColor: p == null ? Neon.violet : null,
              subtitle: p == null ? null : (p.phone.isEmpty ? 'No phone on file' : p.phone),
              trailing: Icon(Icons.chevron_right_rounded, color: Neon.textDim),
              onTap: () async {
                final c = await pickPatient(context);
                if (c != null) setState(() => _patient = c);
              },
            ),
          ]),
          const SizedBox(height: 18),
          _label2('When'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (d, l) in _quick)
                _chip(l, _days == d, () => setState(() => _days = d)),
              _chip(
                  _days == null && _customDate != null
                      ? _dateOnly(_customDate!)
                      : 'Pick date',
                  _days == null,
                  _pickDate,
                  icon: Icons.event_rounded),
            ],
          ),
          const SizedBox(height: 12),
          Row(children: [
            Icon(Icons.schedule_rounded, size: 18, color: Neon.textLo),
            const SizedBox(width: 8),
            Expanded(
              child: Text(_label(_due),
                  style: TextStyle(
                      color: Neon.textHi,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600)),
            ),
            TextButton(onPressed: _pickTime, child: const Text('Change time')),
          ]),
          const SizedBox(height: 10),
          TextField(
            controller: _note,
            textCapitalization: TextCapitalization.sentences,
            maxLength: 120,
            decoration: const InputDecoration(
              labelText: 'Reason (optional)',
              hintText: 'e.g. BP review, suture removal',
              counterText: '',
              prefixIcon: Icon(Icons.notes_rounded),
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _callPatient,
            onChanged: (v) => setState(() => _callPatient = v),
            title: Text('Remind the patient',
                style: TextStyle(color: Neon.textHi, fontSize: 15)),
            subtitle: Text(
                'Your assistant calls them shortly before the visit',
                style: TextStyle(color: Neon.textLo, fontSize: 12.5)),
          ),
          const SizedBox(height: 12),
          ApplePrimaryButton(
            label: _busy ? 'Saving…' : 'Schedule',
            onPressed: p == null || _busy ? null : _save,
          ),
        ],
      ),
    );
  }
}

/* ====================================================================== */
/* Record payment / due                                                    */
/* ====================================================================== */

/// Returns true when an entry was recorded.
Future<bool?> recordPayment(BuildContext context,
        {Client? patient, int? clientId, String? clientName, bool owes = false}) =>
    _sheet<bool>(
        context,
        _PaymentSheet(
            patient: patient,
            clientId: clientId,
            clientName: clientName,
            owes: owes));

class _PaymentSheet extends StatefulWidget {
  const _PaymentSheet(
      {this.patient, this.clientId, this.clientName, this.owes = false});
  final Client? patient;
  final int? clientId;
  final String? clientName;
  final bool owes;
  @override
  State<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<_PaymentSheet> {
  late int? _id = widget.patient?.id ?? widget.clientId;
  late String? _name = widget.patient?.name ?? widget.clientName;
  late bool _owes = widget.owes;
  final _amount = TextEditingController();
  final _note = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amt = double.tryParse(_amount.text.replaceAll(',', '').trim());
    if (_id == null || amt == null || amt <= 0 || _busy) {
      if (amt == null || amt <= 0) AppFeedback.toast('Enter an amount.');
      return;
    }
    setState(() => _busy = true);
    final bal = await ClinicService.instance.addLedger(
        clientId: _id!,
        amount: amt,
        kind: _owes ? 'due' : 'paid',
        note: _note.text.trim());
    if (!mounted) return;
    if (bal == null) {
      setState(() => _busy = false);
      AppFeedback.toast("Couldn't save. Check your connection.");
      return;
    }
    HapticFeedback.lightImpact();
    AppFeedback.toast(bal > 0
        ? '$_name still owes ₹${bal.toStringAsFixed(bal % 1 == 0 ? 0 : 2)}.'
        : '$_name is all settled.');
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _handle(),
          _title(_owes ? 'Add amount owed' : 'Record payment'),
          GroupedCard(children: [
            AppleRow(
              leading: IconTile(Icons.person_rounded, Neon.accentF),
              title: _name ?? 'Choose ${ProWords.current.person.toLowerCase()}',
              titleColor: _name == null ? Neon.violet : null,
              trailing: Icon(Icons.chevron_right_rounded, color: Neon.textDim),
              onTap: () async {
                final c = await pickPatient(context);
                if (c != null) {
                  setState(() {
                    _id = c.id;
                    _name = c.name;
                  });
                }
              },
            ),
          ]),
          const SizedBox(height: 16),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                  value: false,
                  label: Text('Paid'),
                  icon: Icon(Icons.check_circle_outline_rounded)),
              ButtonSegment(
                  value: true,
                  label: Text('Owes'),
                  icon: Icon(Icons.schedule_rounded)),
            ],
            selected: {_owes},
            onSelectionChanged: (s) => setState(() => _owes = s.first),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amount,
            autofocus: _id != null,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(
                color: Neon.textHi, fontSize: 22, fontWeight: FontWeight.w700),
            decoration: const InputDecoration(
              labelText: 'Amount',
              prefixText: '₹ ',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _note,
            textCapitalization: TextCapitalization.sentences,
            maxLength: 100,
            decoration: const InputDecoration(
              labelText: 'Note (optional)',
              hintText: 'e.g. Consultation, X-ray',
              counterText: '',
            ),
          ),
          const SizedBox(height: 16),
          ApplePrimaryButton(
            label: _busy ? 'Saving…' : 'Save',
            onPressed: _id == null || _busy ? null : _save,
          ),
        ],
      ),
    );
  }
}

/* ====================================================================== */
/* Book appointment                                                        */
/* ====================================================================== */

/// Returns true when an appointment was booked.
Future<bool?> bookAppointment(BuildContext context, {Client? patient}) =>
    _sheet<bool>(context, _BookSheet(patient: patient));

class _BookSheet extends StatefulWidget {
  const _BookSheet({this.patient});
  final Client? patient;
  @override
  State<_BookSheet> createState() => _BookSheetState();
}

class _BookSheetState extends State<_BookSheet> {
  late Client? _patient = widget.patient;
  late DateTime _day = _today;
  List<DateTime>? _slots;
  bool _slotsFailed = false;
  DateTime? _slot;
  final _reason = TextEditingController();
  bool _remind = true;
  bool _busy = false;

  static DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  @override
  void initState() {
    super.initState();
    _loadSlots();
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _loadSlots() async {
    setState(() {
      _slots = null;
      _slotsFailed = false;
      _slot = null;
    });
    final day = _day;
    final s = await ClinicService.instance.slotsOn(day);
    if (!mounted || day != _day) return; // a newer day was picked meanwhile
    setState(() {
      _slots = s;
      _slotsFailed = s == null;
    });
  }

  Future<void> _save() async {
    final p = _patient;
    final s = _slot;
    if (p == null || s == null || _busy) return;
    setState(() => _busy = true);
    final a = await ClinicService.instance.book(
      clientId: p.id,
      startsAt: s,
      reason: _reason.text.trim(),
      remindPatient: _remind,
    );
    if (!mounted) return;
    if (a == null) {
      setState(() => _busy = false);
      AppFeedback.toast("Couldn't book. The slot may have just been taken.");
      _loadSlots();
      return;
    }
    HapticFeedback.lightImpact();
    AppFeedback.toast('${p.name} booked for ${_label(s)}.');
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final p = _patient;
    final days = List.generate(7, (i) => _today.add(Duration(days: i)));
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _handle(),
          _title(ProWords.current.book),
          GroupedCard(children: [
            AppleRow(
              leading: IconTile(Icons.person_rounded, Neon.accentF),
              title: p?.name ?? 'Choose ${ProWords.current.person.toLowerCase()}',
              titleColor: p == null ? Neon.violet : null,
              subtitle: p == null
                  ? null
                  : (p.phone.isEmpty ? 'No phone — no reminder call' : p.phone),
              trailing: Icon(Icons.chevron_right_rounded, color: Neon.textDim),
              onTap: () async {
                final c = await pickPatient(context);
                if (c != null) setState(() => _patient = c);
              },
            ),
          ]),
          const SizedBox(height: 16),
          _label2('Day'),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final d in days)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _chip(
                      d == _today
                          ? 'Today'
                          : d == _today.add(const Duration(days: 1))
                              ? 'Tomorrow'
                              : _dateOnly(d),
                      d == _day,
                      () {
                        setState(() => _day = d);
                        _loadSlots();
                      },
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _label2('Time'),
          _slotGrid(),
          const SizedBox(height: 12),
          TextField(
            controller: _reason,
            textCapitalization: TextCapitalization.sentences,
            maxLength: 120,
            decoration: const InputDecoration(
              labelText: 'Reason (optional)',
              hintText: 'e.g. Fever, review, dressing',
              counterText: '',
              prefixIcon: Icon(Icons.notes_rounded),
            ),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _remind,
            onChanged: (v) => setState(() => _remind = v),
            title: Text('Reminder call',
                style: TextStyle(color: Neon.textHi, fontSize: 15)),
            subtitle: Text(
                'Your assistant calls the patient a few hours before',
                style: TextStyle(color: Neon.textLo, fontSize: 12.5)),
          ),
          const SizedBox(height: 10),
          ApplePrimaryButton(
            label: _busy
                ? 'Booking…'
                : _slot == null
                    ? 'Pick a time'
                    : 'Book ${_hm(_slot!)}',
            onPressed: p == null || _slot == null || _busy ? null : _save,
          ),
        ],
      ),
    );
  }

  Widget _slotGrid() {
    final s = _slots;
    if (_slotsFailed) {
      return TextButton(
          onPressed: _loadSlots,
          child: const Text("Couldn't load free times — retry"));
    }
    if (s == null) {
      return const Padding(
        padding: EdgeInsets.all(14),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (s.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Neon.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Neon.line),
        ),
        child: Text(
          'No free times this day. Check your timings in ${ProWords.current.settings}, or pick another day.',
          style: TextStyle(color: Neon.textLo, fontSize: 13),
        ),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final t in s)
          _chip(_hm(t), _slot == t, () {
            HapticFeedback.selectionClick();
            setState(() => _slot = t);
          }),
      ],
    );
  }
}

/* ====================================================================== */
/* Running late                                                            */
/* ====================================================================== */

/// Asks how late, confirms who will be called, then has the assistant call
/// every patient still to come today.
Future<void> runningLate(BuildContext context, {required int patientsLeft}) =>
    _sheet<void>(context, _LateSheet(patientsLeft: patientsLeft));

class _LateSheet extends StatefulWidget {
  const _LateSheet({required this.patientsLeft});
  final int patientsLeft;
  @override
  State<_LateSheet> createState() => _LateSheetState();
}

class _LateSheetState extends State<_LateSheet> {
  int _min = 30;
  bool _busy = false;

  Future<void> _go() async {
    setState(() => _busy = true);
    final n = await ClinicService.instance.runningLate(_min);
    if (!mounted) return;
    Navigator.pop(context);
    AppFeedback.toast(n == null
        ? "Couldn't call patients — calling may not be set up on the server yet."
        : n == 0
            ? 'No patients with a phone number left today.'
            : 'Calling $n patient${n == 1 ? '' : 's'} to say you\'re $_min minutes late.');
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _handle(),
          _title('Running late'),
          Text(
            widget.patientsLeft == 0
                ? 'There are no more booked patients today.'
                : 'Your assistant will phone the ${widget.patientsLeft} patient'
                    '${widget.patientsLeft == 1 ? '' : 's'} still to come today and '
                    'tell them about the delay.',
            style: TextStyle(color: Neon.textLo, fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 16),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final m in const [15, 30, 45, 60, 90])
              _chip('$m min', _min == m, () => setState(() => _min = m)),
          ]),
          const SizedBox(height: 18),
          ApplePrimaryButton(
            label: _busy ? 'Calling…' : 'Tell them',
            onPressed: widget.patientsLeft == 0 || _busy ? null : _go,
          ),
        ],
      ),
    );
  }
}

/* ---------------- shared bits ---------------- */

Widget _label2(String t) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(t,
          style: TextStyle(
              color: Neon.textHi, fontSize: 15, fontWeight: FontWeight.w600)),
    );

Widget _chip(String label, bool selected, VoidCallback onTap, {IconData? icon}) {
  return ChoiceChip(
    avatar: icon == null
        ? null
        : Icon(icon, size: 16, color: selected ? Neon.violet : Neon.textLo),
    label: Text(label),
    selected: selected,
    showCheckmark: false,
    selectedColor: Neon.violet.withValues(alpha: 0.15),
    backgroundColor: Neon.surface,
    side: BorderSide(color: selected ? Neon.violet : Neon.line),
    labelStyle: TextStyle(
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        color: selected ? Neon.violet : Neon.textLo),
    onSelected: (_) => onTap(),
  );
}

const _wk = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _mo = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];

String _dateOnly(DateTime d) => '${_wk[d.weekday - 1]} ${d.day} ${_mo[d.month - 1]}';

String _hm(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final m = d.minute.toString().padLeft(2, '0');
  return '$h:$m ${d.hour < 12 ? 'am' : 'pm'}';
}

String _label(DateTime d) => '${_dateOnly(d)}, ${_hm(d)}';

/// "Today, 10:00 am" / "Tomorrow, 4:30 pm" / "Mon 17 Nov, 10:00 am" /
/// "3 days overdue" — what a follow-up row says about when.
String followUpWhen(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = day.difference(today).inDays;
  if (diff < 0) {
    return diff == -1 ? 'Yesterday — overdue' : '${-diff} days overdue';
  }
  if (diff == 0) return 'Today, ${_hm(d)}';
  if (diff == 1) return 'Tomorrow, ${_hm(d)}';
  return _label(d);
}
