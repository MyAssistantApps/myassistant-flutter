// JYOTISH PREDICTIONS (2026-11-22) — a reading for a period and a part of
// life, written as it streams in, in English, Hindi or Kannada, and read
// aloud on request ("Speak my future").

import 'dart:async';

import 'package:flutter/material.dart';

import '../../design/neon_tokens.dart';
import 'jyotish_models.dart';
import 'jyotish_service.dart';
import 'jyotish_theme.dart';
import 'jyotish_voice.dart';

const kRanges = {
  'today': 'Today',
  'week': 'This week',
  'month': 'This month',
  'year': 'This year',
  'custom': 'Pick a date',
};

const kCategories = {
  'overall': ('Overall', Icons.auto_awesome_rounded),
  'career': ('Career', Icons.work_rounded),
  'love': ('Love', Icons.favorite_rounded),
  'money': ('Money', Icons.savings_rounded),
  'health': ('Health', Icons.spa_rounded),
  'education': ('Education', Icons.school_rounded),
};

class JyotishPredict extends StatefulWidget {
  const JyotishPredict({super.key, required this.birth, required this.service, required this.speaker});

  final Birth birth;
  final JyotishService service;
  final JyotishSpeaker speaker;

  @override
  State<JyotishPredict> createState() => _JyotishPredictState();
}

class _JyotishPredictState extends State<JyotishPredict> {
  String _range = 'today';
  String _category = 'overall';
  String _lang = 'en';
  DateTime? _custom;

  String _text = '';
  bool _busy = false;
  bool _cached = false;
  bool _fallback = false;
  String? _error;
  String? _disclaimer;
  StreamSubscription<ReadingEvent>? _sub;

  List<TtsVoice> _voices = const [];
  bool _langMissing = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadVoices());
  }

  @override
  void didUpdateWidget(JyotishPredict old) {
    super.didUpdateWidget(old);
    if (old.birth != widget.birth) {
      unawaited(_sub?.cancel());
      unawaited(widget.speaker.stop());
      setState(() {
        _text = '';
        _error = null;
        _busy = false;
      });
    }
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    unawaited(widget.speaker.stop());
    super.dispose();
  }

  Future<void> _loadVoices() async {
    final locale = kReadingLanguages[_lang]!.$2;
    final has = await widget.speaker.hasLanguage(locale);
    final voices = await widget.speaker.voicesFor(locale);
    if (!mounted) return;
    setState(() {
      _voices = voices;
      _langMissing = !has && voices.isEmpty;
      if (widget.speaker.voice != null && !voices.any((v) => v.name == widget.speaker.voice!.name)) {
        widget.speaker.voice = null;
      }
    });
  }

  Future<void> _get() async {
    if (_range == 'custom' && _custom == null) {
      await _pickCustom();
      if (_custom == null) return;
    }
    await _sub?.cancel();
    await widget.speaker.stop();
    setState(() {
      _busy = true;
      _text = '';
      _error = null;
      _cached = false;
      _fallback = false;
    });
    final stream = widget.service.predict(
      birth: widget.birth,
      range: _range,
      category: _category,
      language: _lang,
      date: _range == 'custom' ? _custom : null,
    );
    _sub = stream.listen(
      (ev) {
        if (!mounted) return;
        setState(() {
          switch (ev) {
            case ReadingMeta m:
              _cached = m.cached;
              _disclaimer = m.disclaimer;
            case ReadingText t:
              _text += t.text;
            case ReadingFallback _:
              _fallback = true;
            case ReadingError e:
              _error = e.message;
          }
        });
      },
      onDone: () {
        if (!mounted) return;
        setState(() {
          _busy = false;
          if (_text.trim().isEmpty && _error == null) _error = 'No reading came back. Please try again.';
        });
      },
    );
  }

  Future<void> _pickCustom() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _custom ?? now.add(const Duration(days: 30)),
      firstDate: now,
      lastDate: DateTime(2100),
      helpText: 'Reading for which date?',
    );
    if (d != null && mounted) setState(() => _custom = d);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
      children: [
        const SectionTitle('When'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final e in kRanges.entries)
            ChoiceChip(
              label: Text(e.key == 'custom' && _custom != null ? prettyDay(_custom) : e.value),
              selected: _range == e.key,
              onSelected: (_) async {
                setState(() => _range = e.key);
                if (e.key == 'custom') await _pickCustom();
              },
            ),
        ]),
        const SectionTitle('About'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final e in kCategories.entries)
            ChoiceChip(
              avatar: Icon(e.value.$2, size: 16, color: _category == e.key ? Cosmic.gold : Cosmic.dim),
              label: Text(e.value.$1),
              selected: _category == e.key,
              onSelected: (_) => setState(() => _category = e.key),
            ),
        ]),
        const SectionTitle('Language'),
        SegmentedButton<String>(
          segments: [
            for (final e in kReadingLanguages.entries) ButtonSegment(value: e.key, label: Text(e.value.$1)),
          ],
          selected: {_lang},
          onSelectionChanged: (s) {
            setState(() => _lang = s.first);
            unawaited(widget.speaker.stop());
            unawaited(_loadVoices());
          },
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: _busy ? null : _get,
          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
          icon: _busy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.auto_awesome_rounded),
          label: Text(_busy ? 'Reading the stars…' : 'Get my reading'),
        ),
        const SizedBox(height: 16),
        _readingCard(),
        const SizedBox(height: 12),
        Disclaimer(text: _disclaimer),
      ],
    );
  }

  Widget _readingCard() {
    if (_error != null && _text.isEmpty) {
      return CosmicCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.cloud_off_rounded, color: Cosmic.rose),
            const SizedBox(width: 8),
            Expanded(child: Text(_error!, style: Cosmic.body())),
          ]),
          const SizedBox(height: 8),
          TextButton.icon(onPressed: _get, icon: const Icon(Icons.refresh_rounded), label: const Text('Try again')),
        ]),
      );
    }
    if (_text.isEmpty && !_busy) {
      return CosmicCard(
        child: Row(children: [
          const Icon(Icons.nights_stay_rounded, color: Cosmic.dim),
          const SizedBox(width: 10),
          Expanded(
            child: Text('Choose a period and a topic, then tap "Get my reading".', style: Cosmic.label()),
          ),
        ]),
      );
    }
    return CosmicCard(
      glow: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (_fallback)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('A short reading from your chart, while the full one is unavailable.',
                style: Cosmic.label(NeonType.caption).copyWith(color: Cosmic.warn)),
          ),
        if (_busy && _text.isEmpty)
          const LinearProgressIndicator(color: Cosmic.gold, backgroundColor: Cosmic.edge)
        else
          Semantics(
            liveRegion: _busy,
            child: SelectableText(_text.trim(), style: Cosmic.body(NeonType.callout)),
          ),
        if (_cached)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('Saved reading for this period', style: Cosmic.label(NeonType.caption)),
          ),
        if (!_busy && _text.trim().isNotEmpty) ...[
          const Divider(height: 24),
          _speakControls(),
        ],
      ]),
    );
  }

  Widget _speakControls() {
    final sp = widget.speaker;
    final locale = kReadingLanguages[_lang]!.$2;
    return ValueListenableBuilder<SpeakState>(
      valueListenable: sp.state,
      builder: (context, st, _) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child: FilledButton.tonalIcon(
              onPressed: _langMissing
                  ? null
                  : () => st == SpeakState.playing ? sp.pause() : sp.speak(_text, locale),
              icon: Icon(st == SpeakState.playing ? Icons.pause_rounded : Icons.record_voice_over_rounded),
              label: Text(st == SpeakState.playing
                  ? 'Pause'
                  : st == SpeakState.paused
                      ? 'Resume'
                      : 'Speak my future'),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.outlined(
            tooltip: 'Stop',
            onPressed: st == SpeakState.idle ? null : sp.stop,
            icon: const Icon(Icons.stop_rounded),
          ),
        ]),
        if (_langMissing)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
                'This phone has no ${kReadingLanguages[_lang]!.$1} voice. Install one in Settings › Text-to-speech, or choose another language.',
                style: Cosmic.label(NeonType.caption).copyWith(color: Cosmic.warn)),
          ),
        const SizedBox(height: 8),
        Row(children: [
          const Icon(Icons.speed_rounded, size: 18, color: Cosmic.dim),
          Expanded(
            child: Slider(
              value: sp.rate,
              min: 0.25,
              max: 1.0,
              divisions: 6,
              label: '${(sp.rate * 2).toStringAsFixed(1)}×',
              semanticFormatterCallback: (v) => 'Speed ${(v * 2).toStringAsFixed(1)} times',
              onChanged: (v) => setState(() => unawaited(sp.setRate(v))),
            ),
          ),
        ]),
        if (_voices.length > 1)
          DropdownButtonFormField<String>(
            initialValue: sp.voice?.name,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Voice', isDense: true),
            items: [
              for (final v in _voices)
                DropdownMenuItem(value: v.name, child: Text(v.name, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (name) => setState(() {
              sp.voice = _voices.firstWhere((v) => v.name == name);
              unawaited(sp.stop());
            }),
          ),
      ]),
    );
  }
}
