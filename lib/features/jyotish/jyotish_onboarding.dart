// JYOTISH ONBOARDING (2026-11-22) — tell the AI when and where you were
// born, in your own words (typed or spoken); it fills the form below, asks
// for what is missing, and you confirm. The form also works on its own.
//
// THE MIC IS GURUJI (2026-11-23): a tap starts the assistant's voice
// conversation as Guruji (guruFormRole), who asks for the details one at a
// time and fills the form as they are spoken — two local tools lent to the
// brain while the form is open, the same way as the booking forms
// (voice_booking.dart). Typing still goes through /jyotish/extract.

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../ai/local_tools.dart';
import '../../ai/types.dart' show AiToolSpec;
import '../../core/log.dart';
import '../../design/neon_tokens.dart';
import '../../widgets/role_mic_orb.dart';
import '../assistant/state/assistant_engine.dart';
import 'jyotish_guru.dart';
import 'jyotish_models.dart';
import 'jyotish_service.dart';
import 'jyotish_theme.dart';
import 'jyotish_voice.dart';

typedef CastChart = Future<bool> Function(Birth birth, {required bool save});

class JyotishOnboarding extends StatefulWidget {
  const JyotishOnboarding({
    super.key,
    required this.service,
    required this.listener,
    required this.onCast,
    this.initial,
    this.extracted,
    this.tools,
    this.orb,
  });

  final JyotishService service;
  final JyotishListener listener;
  final CastChart onCast;
  final Birth? initial;

  /// What an uploaded horoscope was read as (2026-11-23): the form starts
  /// filled with it, for the person to check.
  final Extracted? extracted;

  /// Where the voice tools are lent (the main brain's by default; tests
  /// pass their own).
  final LocalToolRegistry? tools;

  /// For tests: what stands in for the Guruji mic.
  final Widget? orb;

  @override
  State<JyotishOnboarding> createState() => _JyotishOnboardingState();
}

class _Msg {
  const _Msg(this.role, this.text);
  final String role; // user | assistant
  final String text;
}

class _JyotishOnboardingState extends State<JyotishOnboarding> {
  static const _greeting =
      'Namaste! Tell me when and where you were born — for example, "14 March 2004, around 6:30 in the morning, in Udupi". You can type, or tap the mic and I will fill in the form as you speak.';

  final _messages = <_Msg>[const _Msg('assistant', _greeting)];
  final _input = TextEditingController();
  final _name = TextEditingController();
  final _place = TextEditingController();
  final _scroll = ScrollController();
  final _composerKey = GlobalKey();
  final _formKey = GlobalKey();
  final _removers = <void Function()>[];

  DateTime? _date;
  TimeOfDay? _time;
  bool _timeUnknown = false;
  String? _gender;
  List<PlaceOption> _places = const [];
  PlaceOption? _picked;
  bool _save = true;

  bool _thinking = false;
  bool _searching = false;
  bool _casting = false;
  String? _placeError;
  String? _formError;

  LocalToolRegistry get _tools => widget.tools ?? AssistantEngine.instance.brain.localTools;

  @override
  void initState() {
    super.initState();
    _lendVoiceTools();
    final b = widget.initial;
    if (b != null) {
      _name.text = b.name ?? '';
      _date = DateTime.tryParse(b.date);
      _time = _parseTime(b.time);
      _timeUnknown = b.time == null;
      _place.text = b.place ?? '';
      _picked = PlaceOption(name: b.place ?? '', lat: b.lat, lng: b.lng, tz: b.tz);
      _places = [_picked!];
      _gender = b.gender;
    }
    final e = widget.extracted;
    if (e != null) {
      _applyFields(e);
      _messages.add(_Msg(
          'assistant',
          e.complete
              ? 'I have read your horoscope${e.name != null ? ', ${e.name}' : ''}. Check the details below${_picked == null && _places.length > 1 ? ', choose your birth place from the list,' : ''} and tap "Cast my chart".'
              : e.followUp ?? 'I could read only part of your horoscope. Please fill in what is missing below.'));
    }
  }

  /// What a reading found — typed, spoken or an uploaded horoscope — into
  /// the form.
  void _applyFields(Extracted out) {
    if (out.name != null) _name.text = out.name!;
    if (out.date != null) _date = DateTime.tryParse(out.date!);
    if (out.time != null) {
      _time = _parseTime(out.time);
      _timeUnknown = false;
    }
    if (out.timeUnknown) {
      _time = null;
      _timeUnknown = true;
    }
    if (out.gender != null) _gender = out.gender;
    if (out.place != null && out.place != _place.text) {
      _place.text = out.place!;
      _places = out.places;
      _picked = out.places.length == 1 ? out.places.first : null;
      _placeError = out.places.isEmpty ? 'No match found. Try adding the district or state.' : null;
    }
  }

  @override
  void dispose() {
    for (final r in _removers) {
      r();
    }
    _input.dispose();
    _name.dispose();
    _place.dispose();
    _scroll.dispose();
    unawaited(widget.listener.stop());
    super.dispose();
  }

  static TimeOfDay? _parseTime(String? hm) {
    if (hm == null) return null;
    final p = hm.split(':');
    final h = int.tryParse(p.first), m = p.length > 1 ? int.tryParse(p[1]) : 0;
    return h == null || m == null ? null : TimeOfDay(hour: h, minute: m);
  }

  /// Keeps the composer near the bottom of the view, the newest messages just above it.
  void _scrollDown() => WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _composerKey.currentContext;
        if (ctx != null && ctx.mounted) {
          Scrollable.ensureVisible(ctx,
              alignment: 0.85, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
        }
      });

  Future<void> _send([String? spoken]) async {
    final text = (spoken ?? _input.text).trim();
    if (text.isEmpty || _thinking) return;
    _input.clear();
    setState(() {
      _messages.add(_Msg('user', text));
      _thinking = true;
    });
    _scrollDown();
    final history = [
      for (final m in _messages.skip(1)) (role: m.role, text: m.text),
    ];
    final out = await widget.service.extract(history.length > 20 ? history.sublist(history.length - 20) : history);
    if (!mounted) return;
    setState(() {
      _thinking = false;
      if (out == null) {
        _messages.add(const _Msg('assistant',
            "I couldn't read that just now. You can fill in the form below, or try again."));
        return;
      }
      _applyFields(out);
      final reply = out.followUp ??
          (out.complete
              ? 'Got it${out.name != null ? ', ${out.name}' : ''}! Check the details below${_picked == null && _places.length > 1 ? ', choose your birth place from the list,' : ''} and tap "Cast my chart".'
              : 'Thanks! Anything else you can tell me?');
      _messages.add(_Msg('assistant', reply));
    });
    _scrollDown();
  }

  // ── Guruji fills the form (2026-11-23) ────────────────────────────────

  void _lendVoiceTools() {
    _removers
      ..add(_tools.register(LocalTool(
        spec: const AiToolSpec(
          name: fillBirthTool,
          description: 'Fill in the birth details form on screen. Pass ONLY what the owner said. '
              'Returns what changed, the whole form, what is still missing, and the matching '
              'places when the place needs choosing.',
          parameters: {
            'type': 'object',
            'properties': {
              'name': {'type': 'string', 'description': 'The person\'s name.'},
              'date': {'type': 'string', 'description': 'Date of birth, YYYY-MM-DD.'},
              'time': {'type': 'string', 'description': 'Time of birth, 24-hour HH:MM.'},
              'time_unknown': {'type': 'boolean', 'description': 'True when they do not know the birth time.'},
              'place': {
                'type': 'string',
                'description': 'Place of birth: town and state, or one of the places the last call listed, exactly.'
              },
            },
          },
        ),
        available: () => mounted,
        handler: _voiceFill,
      )))
      ..add(_tools.register(LocalTool(
        spec: const AiToolSpec(
          name: castBirthTool,
          description: 'Cast the chart from the birth details form as it is now (and save the profile '
              'when it has a name). Only after the owner said yes.',
          parameters: {'type': 'object', 'properties': {}},
        ),
        available: () => mounted,
        handler: (_) => _voiceCast(),
      )));
  }

  /// What the form still needs before the chart can be cast.
  List<String> _missing() => [
        if (_date == null) 'date of birth',
        if (_time == null && !_timeUnknown) 'time of birth (or that it is unknown)',
        if (_picked == null) _places.length > 1 ? 'which of the listed places' : 'place of birth',
      ];

  Map<String, Object?> _formState() => {
        'name': _name.text.trim(),
        'date': _date == null ? null : ymd(_date!),
        'time': _timeUnknown
            ? 'unknown'
            : _time == null
                ? null
                : '${_time!.hour.toString().padLeft(2, '0')}:${_time!.minute.toString().padLeft(2, '0')}',
        'place': _picked?.name,
      };

  Future<LocalToolResult> _voiceFill(LocalToolCall call) async {
    if (!mounted) return const LocalToolResult.failed('The form is closed.');
    String? arg(String k) {
      final v = call.args[k]?.toString().trim();
      return v == null || v.isEmpty || v == 'null' ? null : v;
    }

    final changed = <String>[];
    final problems = <String>[];
    setState(() {
      _formError = null;
      if (arg('name') case final n?) {
        _name.text = n;
        changed.add('name');
      }
      if (arg('date') case final d?) {
        final day = DateTime.tryParse(d);
        if (day == null || day.isAfter(DateTime.now())) {
          problems.add('"$d" is not a date of birth; use YYYY-MM-DD, not in the future.');
        } else {
          _date = DateTime(day.year, day.month, day.day);
          changed.add('date');
        }
      }
      if (call.args['time_unknown'] == true) {
        _time = null;
        _timeUnknown = true;
        changed.add('time unknown');
      } else if (arg('time') case final t?) {
        final tm = _parseTime(t);
        if (tm == null || tm.hour > 23 || tm.minute > 59) {
          problems.add('"$t" is not a time; use 24-hour HH:MM.');
        } else {
          _time = tm;
          _timeUnknown = false;
          changed.add('time');
        }
      }
    });
    if (arg('place') case final q?) {
      final want = q.toLowerCase();
      PlaceOption? hit;
      for (final p in _places) {
        if (p.name.toLowerCase() == want) hit = p;
      }
      if (hit != null) {
        setState(() {
          _picked = hit;
          _place.text = hit!.name;
          _placeError = null;
        });
      } else {
        _place.text = q;
        await _searchPlace();
      }
      if (!mounted) return const LocalToolResult.failed('The form is closed.');
      if (_picked != null) changed.add('place');
      if (_placeError != null) problems.add(_placeError!);
    }
    AppLog.add('voicefill', 'jyotish ${changed.isEmpty ? '(no change)' : changed.join(', ')}');
    if (changed.isNotEmpty) {
      HapticFeedback.selectionClick();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _formKey.currentContext;
        if (ctx != null && ctx.mounted) {
          Scrollable.ensureVisible(ctx, alignment: 0.1, duration: const Duration(milliseconds: 250));
        }
      });
    }
    final missing = _missing();
    return LocalToolResult(result: {
      'changed': changed,
      'form': _formState(),
      'missing': missing,
      if (problems.isNotEmpty) 'problems': problems,
      if (_picked == null && _places.length > 1) 'places': [for (final p in _places) p.name],
      if (missing.isEmpty) 'next': 'Read the details back and ask whether to cast the chart.',
    });
  }

  Future<LocalToolResult> _voiceCast() async {
    if (!mounted) return const LocalToolResult.failed('The form is closed.');
    final missing = _missing();
    if (missing.isNotEmpty) {
      return LocalToolResult(ok: false, error: 'Still missing: ${missing.join(', ')}.', result: {'missing': missing});
    }
    final saving = _save && _name.text.trim().isNotEmpty;
    await _cast();
    if (mounted && _formError != null) return LocalToolResult.failed(_formError!);
    return LocalToolResult(result: {'cast': true, 'saved': saving});
  }

  Future<void> _searchPlace() async {
    final q = _place.text.trim();
    if (q.length < 2) {
      setState(() => _placeError = 'Type at least two letters of the place.');
      return;
    }
    setState(() {
      _searching = true;
      _placeError = null;
    });
    final found = await widget.service.places(q);
    if (!mounted) return;
    setState(() {
      _searching = false;
      if (found == null) {
        _placeError = 'Unable to look up places right now. Please try again.';
        return;
      }
      _places = found;
      _picked = found.length == 1 ? found.first : null;
      if (found.isEmpty) _placeError = 'No match found. Try adding the district or state.';
    });
  }

  // EASIER DATE OF BIRTH (owner, 2026-11-23: "filling the date of birth
  // should be easier"): scroll wheels — day, month, year; hour, minute,
  // AM / PM — instead of a calendar paged a month at a time back to the
  // birth year.

  /// A bottom sheet with [title], a Done button and a wheel [picker]; true
  /// when Done was tapped.
  Future<bool> _wheelSheet(String title, Widget picker) async {
    final done = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: const Color(0xFF1B1245),
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 16, 4),
            child: Row(children: [
              Expanded(child: Text(title, style: Cosmic.title())),
              FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Done')),
            ]),
          ),
          SizedBox(
            height: 216,
            child: CupertinoTheme(
              data: const CupertinoThemeData(
                brightness: Brightness.dark,
                textTheme: CupertinoTextThemeData(
                  dateTimePickerTextStyle: TextStyle(color: Cosmic.ink, fontSize: 21),
                ),
              ),
              child: picker,
            ),
          ),
        ]),
      ),
    );
    return done == true;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    var chosen = _date ?? DateTime(now.year - 25, 1, 1);
    if (chosen.isAfter(now)) chosen = now;
    final ok = await _wheelSheet(
      'Date of Birth',
      CupertinoDatePicker(
        mode: CupertinoDatePickerMode.date,
        dateOrder: DatePickerDateOrder.dmy,
        initialDateTime: chosen,
        minimumDate: DateTime(1900),
        maximumDate: now,
        onDateTimeChanged: (d) => chosen = d,
      ),
    );
    if (ok && mounted) setState(() => _date = DateTime(chosen.year, chosen.month, chosen.day));
  }

  Future<void> _pickTime() async {
    final t = _time ?? const TimeOfDay(hour: 6, minute: 0);
    var chosen = DateTime(2000, 1, 1, t.hour, t.minute);
    final ok = await _wheelSheet(
      'Time of Birth',
      CupertinoDatePicker(
        mode: CupertinoDatePickerMode.time,
        initialDateTime: chosen,
        onDateTimeChanged: (d) => chosen = d,
      ),
    );
    if (ok && mounted) {
      setState(() {
        _time = TimeOfDay(hour: chosen.hour, minute: chosen.minute);
        _timeUnknown = false;
      });
    }
  }

  Future<void> _cast() async {
    String? err;
    if (_date == null) {
      err = 'Choose the date of birth.';
    } else if (_picked == null) {
      err = _places.length > 1 ? 'Choose the birth place from the list.' : 'Search for the birth place and choose it.';
    } else if (_time == null && !_timeUnknown) {
      err = 'Set the birth time, or switch on "I don\'t know my birth time".';
    }
    setState(() => _formError = err);
    if (err != null) return;
    final t = _time;
    final birth = Birth(
      name: _name.text.trim().isEmpty ? null : _name.text.trim(),
      date: ymd(_date!),
      time: _timeUnknown || t == null
          ? null
          : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}',
      place: _picked!.name,
      lat: _picked!.lat,
      lng: _picked!.lng,
      tz: _picked!.tz,
      gender: _gender,
    );
    setState(() => _casting = true);
    final ok = await widget.onCast(birth, save: _save && birth.name != null);
    if (!mounted) return;
    setState(() {
      _casting = false;
      if (!ok) _formError = 'Unable to calculate the chart. Please check the details and try again.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        for (final m in _messages) _bubble(m),
        if (_thinking) _typing(),
        const SizedBox(height: 8),
        _composer(),
        const SectionTitle('Your birth details'),
        _form(),
      ],
    );
  }

  Widget _bubble(_Msg m) {
    final me = m.role == 'user';
    return Align(
      alignment: me ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 320),
        decoration: BoxDecoration(
          color: me ? Cosmic.gold.withValues(alpha: 0.18) : Cosmic.card,
          border: Border.all(color: me ? Cosmic.gold.withValues(alpha: 0.4) : Cosmic.edge),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(me ? 18 : 4),
            bottomRight: Radius.circular(me ? 4 : 18),
          ),
        ),
        child: Semantics(
          label: '${me ? 'You' : 'Jyotish'} said',
          child: Text(m.text, style: Cosmic.body()),
        ),
      ),
    );
  }

  Widget _typing() => Align(
        alignment: Alignment.centerLeft,
        child: Semantics(
          liveRegion: true,
          label: 'Reading your details',
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(color: Cosmic.card, borderRadius: BorderRadius.circular(18)),
            child: const SizedBox(
                width: 36, height: 12, child: LinearProgressIndicator(color: Cosmic.gold, backgroundColor: Cosmic.edge)),
          ),
        ),
      );

  Widget _composer() => Row(key: _composerKey, children: [
        Expanded(
          child: TextField(
            controller: _input,
            minLines: 1,
            maxLines: 4,
            maxLength: 1000,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _send(),
            decoration: const InputDecoration(
              hintText: 'When and where were you born?',
              counterText: '',
              isDense: true,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Send',
          onPressed: _thinking ? null : _send,
          icon: const Icon(Icons.send_rounded, color: Cosmic.gold),
        ),
        const SizedBox(width: 2),
        // The mic: Guruji asks for the details and fills the form as they
        // are spoken. The everyday assistant is back when the talk ends.
        widget.orb ??
            const RoleMicOrb(
              role: guruFormRole,
              tint: Cosmic.sky,
              size: 44,
              showLabel: false,
              // The composer scrolls away as the form fills; that is not
              // the talk ending (as on the Home card).
              endOnDispose: false,
              resetRoleWhenDone: true,
              topic: 'your birth details',
              openingNote: _formMicNote,
            ),
      ]);

  static String? _formMicNote() => jyotishFormMicNote;

  Widget _form() {
    return CosmicCard(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _name,
            maxLength: 80,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Name', counterText: ''),
          ),
          const SizedBox(height: 12),
          _pickerRow(
            icon: Icons.cake_rounded,
            label: 'Date of birth',
            value: _date == null ? 'Choose a date' : prettyDay(_date),
            onTap: _pickDate,
          ),
          const SizedBox(height: 8),
          _pickerRow(
            icon: Icons.schedule_rounded,
            label: 'Time of birth',
            value: _timeUnknown
                ? 'Unknown'
                : _time == null
                    ? 'Choose a time'
                    : prettyTime('${_time!.hour.toString().padLeft(2, '0')}:${_time!.minute.toString().padLeft(2, '0')}'),
            onTap: _timeUnknown ? null : _pickTime,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _timeUnknown,
            onChanged: (v) => setState(() {
              _timeUnknown = v;
              if (v) _time = null;
            }),
            title: Text("I don't know my birth time", style: Cosmic.body()),
            subtitle: Text('Moon sign, nakshatra, dasha and transits still work; the lagna and houses need the time.',
                style: Cosmic.label(NeonType.caption)),
          ),
          const SizedBox(height: 4),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _place,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _searchPlace(),
                onChanged: (_) {
                  if (_picked != null) setState(() => _picked = null);
                },
                decoration: InputDecoration(labelText: 'Place of birth', errorText: _placeError),
              ),
            ),
            const SizedBox(width: 6),
            IconButton.filledTonal(
              tooltip: 'Find the place',
              onPressed: _searching ? null : _searchPlace,
              icon: _searching
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.travel_explore_rounded),
            ),
          ]),
          if (_places.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(_places.length > 1 ? 'Choose the right place:' : 'Place found:', style: Cosmic.label()),
            for (final p in _places) _placeTile(p),
          ],
          const SizedBox(height: 10),
          DropdownButtonFormField<String?>(
            initialValue: _gender,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Gender (optional)'),
            items: const [
              DropdownMenuItem(value: null, child: Text('Prefer not to say')),
              DropdownMenuItem(value: 'female', child: Text('Female')),
              DropdownMenuItem(value: 'male', child: Text('Male')),
              DropdownMenuItem(value: 'other', child: Text('Other')),
            ],
            onChanged: (v) => setState(() => _gender = v),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _save,
            onChanged: (v) => setState(() => _save = v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            title: Text('Save this profile', style: Cosmic.body()),
            subtitle: _name.text.trim().isEmpty
                ? Text('Add a name to save it.', style: Cosmic.label(NeonType.caption))
                : null,
          ),
          if (_formError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Semantics(
                liveRegion: true,
                child: Text(_formError!, style: Cosmic.body().copyWith(color: Cosmic.rose)),
              ),
            ),
          FilledButton.icon(
            onPressed: _casting ? null : _cast,
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
            icon: _casting
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.auto_awesome_rounded),
            label: Text(_casting ? 'Calculating…' : 'Cast my chart'),
          ),
        ],
      ),
    );
  }

  Widget _pickerRow({required IconData icon, required String label, required String value, VoidCallback? onTap}) {
    return Semantics(
      button: onTap != null,
      label: '$label: $value',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Cosmic.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Cosmic.edge),
          ),
          child: Row(children: [
            Icon(icon, color: Cosmic.gold, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: Cosmic.label(NeonType.caption)),
                Text(value, style: Cosmic.body().copyWith(color: onTap == null ? Cosmic.faint : Cosmic.ink)),
              ]),
            ),
            if (onTap != null) const Icon(Icons.edit_calendar_rounded, color: Cosmic.dim, size: 18),
          ]),
        ),
      ),
    );
  }

  Widget _placeTile(PlaceOption p) {
    final on = identical(p, _picked) || (_picked != null && _picked!.lat == p.lat && _picked!.lng == p.lng);
    return Semantics(
      selected: on,
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _picked = p),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(children: [
            Icon(on ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                color: on ? Cosmic.gold : Cosmic.dim, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.name, style: Cosmic.body(NeonType.footnote), maxLines: 2, overflow: TextOverflow.ellipsis),
                Text('${p.lat.toStringAsFixed(3)}, ${p.lng.toStringAsFixed(3)}${p.tz != null ? ' · ${p.tz}' : ''}',
                    style: Cosmic.label(NeonType.caption)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
