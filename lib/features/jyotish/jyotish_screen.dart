// JYOTISH (2026-11-22) — the Vedic horoscope, opened from the last card on
// Home. It opens on Guruji (owner, 2026-11-23; jyotish_guru.dart): a voice
// that gives today's bhavishya from the saved chart, or asks for the birth
// details and casts one. The chart itself — Kundli (North / South drawing,
// yogas, doshas, gochar), Planets, Dasha and Predictions — opens from "View
// Your Kundli"; typing the details stays as a fallback. People can be saved
// and switched.

import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../ai/assistant_role.dart';
import '../../design/neon_tokens.dart';
import '../../services/auth_service.dart';
import '../../widgets/photo_source_sheet.dart';
import '../assistant/state/assistant_engine.dart';
import 'jyotish_guru.dart';
import 'jyotish_models.dart';
import 'jyotish_onboarding.dart';
import 'jyotish_predict.dart';
import 'jyotish_service.dart';
import 'jyotish_theme.dart';
import 'jyotish_voice.dart';
import 'kundli_chart.dart';

class JyotishScreen extends StatefulWidget {
  const JyotishScreen({
    super.key,
    this.service = const JyotishService(),
    this.speaker,
    this.listener,
    this.music,
    this.autoStartGuru = true,
    this.startWithUpload = false,
  });

  final JyotishService service;

  /// Test seams: the phone's voice out and in, and the background music.
  final JyotishSpeaker? speaker;
  final JyotishListener? listener;
  final JyotishMusic? music;

  /// Guruji speaks as the screen opens (off in tests).
  final bool autoStartGuru;

  /// Opened from the card's camera: straight to uploading a horoscope
  /// (Guruji waits until it is read).
  final bool startWithUpload;

  @override
  State<JyotishScreen> createState() => _JyotishScreenState();
}

class _JyotishScreenState extends State<JyotishScreen> with WidgetsBindingObserver {
  late final JyotishSpeaker _speaker = widget.speaker ?? JyotishSpeaker();
  late final JyotishListener _listener = widget.listener ?? JyotishListener();
  late final JyotishMusic _music = widget.music ?? JyotishMusic();

  bool _loading = true;
  String? _loadError;
  List<SavedProfile> _profiles = const [];
  ChartResult? _result;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_music.start());
    unawaited(_start());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_music.dispose());
    if (widget.speaker == null) _speaker.dispose();
    if (widget.listener == null) _listener.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _music.resume();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _music.pause();
    }
  }

  /// The most recent saved person's chart, ready for "View Your Kundli".
  Future<void> _start() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    final list = await widget.service.profiles();
    if (!mounted) return;
    if (list == null) {
      setState(() {
        _loading = false;
        _loadError = 'Unable to load your saved profiles.';
      });
      return;
    }
    _profiles = list;
    if (list.isNotEmpty) {
      _result = await widget.service.chart(list.first.birth);
      if (!mounted) return;
    }
    setState(() => _loading = false);
    if (widget.startWithUpload && !_uploadOffered) {
      _uploadOffered = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_upload());
      });
    }
  }

  bool _uploadOffered = false;

  // ── A horoscope, uploaded (owner, 2026-11-23) ──────────────────────

  /// A photo (camera or gallery) or a PDF of the horoscope; null when the
  /// person closes the picker.
  Future<({List<int> bytes, String mime, String filename})?> _pickHoroscope() async {
    final from = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF1B1245),
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text('Upload Your Horoscope', style: Cosmic.title()),
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera_rounded, color: Mandir.gold),
            title: Text('Take a Photo', style: Cosmic.body()),
            onTap: () => Navigator.of(ctx).pop('camera'),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_rounded, color: Mandir.gold),
            title: Text('Choose a Photo', style: Cosmic.body()),
            onTap: () => Navigator.of(ctx).pop('gallery'),
          ),
          ListTile(
            leading: const Icon(Icons.picture_as_pdf_rounded, color: Mandir.gold),
            title: Text('Choose a PDF', style: Cosmic.body()),
            onTap: () => Navigator.of(ctx).pop('pdf'),
          ),
        ]),
      ),
    );
    if (from == null || !mounted) return null;
    if (from == 'pdf') {
      try {
        final picked = await FilePicker.platform
            .pickFiles(type: FileType.custom, allowedExtensions: const ['pdf'], withData: true);
        final f = picked == null || picked.files.isEmpty ? null : picked.files.first;
        final bytes = f?.bytes;
        if (bytes == null) return null;
        return (bytes: bytes.toList(), mime: 'application/pdf', filename: f!.name);
      } catch (_) {
        return null;
      }
    }
    try {
      final photo = await PhotoSourceSheet.pick(context, from);
      if (photo == null) return null;
      return (bytes: photo.bytes.toList(), mime: photo.mime, filename: 'horoscope.jpg');
    } on PhotoAccessDenied {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(from == 'camera'
                ? 'Camera access is off for this app. Allow it in Settings, then try again.'
                : 'Photo access is off for this app. Allow it in Settings, then try again.')));
      }
      return null;
    }
  }

  /// Upload → read → the details filled in to check → cast and saved →
  /// Guruji explains it.
  Future<void> _upload() async {
    final file = await _pickHoroscope();
    if (file == null || !mounted) return;
    final nav = Navigator.of(context, rootNavigator: true);
    unawaited(showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1B1245),
        content: Row(children: [
          const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Mandir.gold, strokeWidth: 2.5)),
          const SizedBox(width: 16),
          Expanded(child: Text('Reading your horoscope…', style: Cosmic.body())),
        ]),
      ),
    ));
    final r = await widget.service.readHoroscope(file.bytes, filename: file.filename, mimeType: file.mime);
    if (!mounted) return;
    nav.pop(); // the "Reading…" dialog
    final read = r.result;
    if (read == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(r.error ?? 'Unable to read the horoscope. Please try again.')));
      return;
    }
    _typeDetails(extracted: read, uploaded: true);
  }

  /// Guruji, started from here with [note] as his first words.
  Future<void> _startGuru(String note) async {
    final e = AssistantEngine.instance;
    if (!widget.autoStartGuru) return;
    if (e.starting || e.inlineVoice || e.liveActive) {
      // Guruji already talking: he starts again, on the horoscope just read.
      // Another conversation is left alone.
      if (AssistantRole.current.value != guruRole) return;
      await e.endInlineConversation();
    }
    await e.useRole(guruRole);
    await e.beginInlineConversation(name: AuthService.instance.user?.name, openingNote: note);
  }

  /// Guruji saved a chart by voice: pick it up without leaving the page
  /// (the conversation goes on).
  Future<void> _refresh() async {
    final list = await widget.service.profiles();
    if (!mounted || list == null || list.isEmpty) return;
    final r = await widget.service.chart(list.first.birth);
    if (!mounted) return;
    setState(() {
      _profiles = list;
      if (r != null) _result = r;
    });
  }

  Future<bool> _cast(Birth birth, {required bool save}) async {
    final r = await widget.service.chart(birth);
    if (r == null || !mounted) return false;
    if (save && birth.name != null) {
      final ok = await widget.service.saveProfile(birth.name!, birth);
      final list = await widget.service.profiles();
      if (!mounted) return true;
      if (list != null) _profiles = list;
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('The chart is ready, but the profile could not be saved.')));
      }
    }
    setState(() => _result = r);
    return true;
  }

  /// The details typed instead of spoken (also "Edit Birth Details"), or
  /// [extracted] from an uploaded horoscope to check.
  void _typeDetails({Birth? from, Extracted? extracted, bool uploaded = false}) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (ctx) => _JyotishPage(
        title: uploaded ? 'Check Your Details' : 'Birth Details',
        child: JyotishOnboarding(
          key: ValueKey(from ?? extracted),
          service: widget.service,
          listener: _listener,
          initial: from,
          extracted: extracted,
          onCast: (birth, {required save}) async {
            final ok = await _cast(birth, save: save);
            if (ok && ctx.mounted) {
              Navigator.of(ctx).pop();
              if (!mounted) return ok;
              if (uploaded) {
                // Back on Guruji's page: he explains the horoscope just read.
                unawaited(_startGuru(guruUploadedNote(birth.name ?? 'me')));
              } else {
                _viewKundli();
              }
            }
            return ok;
          },
        ),
      ),
    ));
  }

  void _viewKundli() {
    final r = _result;
    if (r == null) return;
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => _ChartPage(result: r, service: widget.service, speaker: _speaker),
    ));
  }

  Future<void> _open(SavedProfile p) async {
    Navigator.of(context).pop();
    final r = await widget.service.chart(p.birth);
    if (!mounted) return;
    if (r == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Unable to open that profile. Please try again.')));
      return;
    }
    setState(() => _result = r);
    _viewKundli();
  }

  Future<void> _delete(SavedProfile p) async {
    final ok = await widget.service.deleteProfile(p.id);
    final list = await widget.service.profiles();
    if (!mounted) return;
    setState(() => _profiles = list ?? _profiles.where((x) => x.id != p.id).toList());
    if (!ok) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Unable to delete the profile. Please try again.')));
    }
  }

  void _showProfiles() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1B1245),
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: ListView(shrinkWrap: true, padding: const EdgeInsets.only(bottom: 16), children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('Saved People', style: Cosmic.title()),
            ),
            if (_profiles.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text('No one is saved yet. Tell Guruji your birth details to save yours.',
                    style: Cosmic.label()),
              ),
            for (final p in _profiles)
              ListTile(
                leading: const Icon(Icons.person_rounded, color: Mandir.gold),
                title: Text(p.name, style: Cosmic.body()),
                subtitle: Text('${prettyDate(p.birth.date)} · ${prettyTime(p.birth.time)}${p.birth.place != null ? ' · ${p.birth.place}' : ''}',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: Cosmic.label(NeonType.caption)),
                onTap: () => _open(p),
                trailing: IconButton(
                  tooltip: 'Delete ${p.name}',
                  icon: const Icon(Icons.delete_outline_rounded, color: Cosmic.dim),
                  onPressed: () async {
                    await _delete(p);
                    setSheet(() {});
                  },
                ),
              ),
            ListTile(
              leading: const Icon(Icons.person_add_alt_1_rounded, color: Mandir.saffron),
              title: Text('New Person', style: Cosmic.body()),
              onTap: () {
                Navigator.of(ctx).pop();
                _typeDetails();
              },
            ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    return Theme(
      data: Cosmic.theme(context),
      child: TempleDoodle(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            foregroundColor: Cosmic.ink,
            title: Text('Jyotish', style: Cosmic.title(NeonType.title3)),
            actions: [
              ValueListenableBuilder<bool>(
                valueListenable: _music.on,
                builder: (_, on, __) => IconButton(
                  tooltip: on ? 'Turn Music Off' : 'Turn Music On',
                  icon: Icon(on ? Icons.music_note_rounded : Icons.music_off_rounded),
                  onPressed: _music.toggle,
                ),
              ),
              if (r != null)
                IconButton(
                  tooltip: 'Edit Birth Details',
                  icon: const Icon(Icons.edit_rounded),
                  onPressed: () => _typeDetails(from: r.birth),
                ),
              IconButton(
                tooltip: 'Saved People',
                icon: const Icon(Icons.people_alt_rounded),
                onPressed: _loading ? null : _showProfiles,
              ),
            ],
          ),
          body: SafeArea(top: false, child: _body()),
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return Center(
        child: Semantics(label: 'Loading', child: const CircularProgressIndicator(color: Mandir.gold)),
      );
    }
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off_rounded, color: Cosmic.rose, size: 40),
            const SizedBox(height: 12),
            Text(_loadError!, style: Cosmic.title(), textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text('Check your internet connection and try again.', style: Cosmic.label(), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Wrap(spacing: 8, children: [
              FilledButton(onPressed: _start, child: const Text('Try Again')),
              OutlinedButton(onPressed: _typeDetails, child: const Text('Enter Details')),
            ]),
          ]),
        ),
      );
    }
    final r = _result;
    final saved = _profiles.isEmpty ? null : (r?.birth.name ?? _profiles.first.name);
    return GuruPage(
      savedName: saved,
      music: _music,
      autoStart: widget.autoStartGuru && !widget.startWithUpload,
      onChartSaved: _refresh,
      actions: [
        if (r != null)
          FilledButton.icon(
            onPressed: _viewKundli,
            style: FilledButton.styleFrom(
              backgroundColor: Mandir.gold,
              foregroundColor: const Color(0xFF3A1206),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            ),
            icon: const Icon(Icons.auto_awesome_rounded, size: 18),
            label: const Text('View Your Kundli'),
          ),
        OutlinedButton.icon(
          onPressed: _upload,
          style: OutlinedButton.styleFrom(
            foregroundColor: Mandir.gold,
            side: BorderSide(color: Mandir.gold.withValues(alpha: 0.7)),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          ),
          icon: const Icon(Icons.photo_camera_rounded, size: 18),
          label: const Text('Upload Horoscope'),
        ),
        TextButton.icon(
          onPressed: () => _typeDetails(from: r?.birth),
          style: TextButton.styleFrom(foregroundColor: Mandir.sandal),
          icon: const Icon(Icons.keyboard_rounded, size: 18),
          label: Text(r == null ? 'Type the Details Instead' : 'Type New Details'),
        ),
      ],
    );
  }
}

/// A pushed Jyotish page on the same dusk and temple drawing.
class _JyotishPage extends StatelessWidget {
  const _JyotishPage({required this.title, required this.child, this.bottom});
  final String title;
  final Widget child;
  final PreferredSizeWidget? bottom;

  @override
  Widget build(BuildContext context) => Theme(
        data: Cosmic.theme(context),
        child: TempleDoodle(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              foregroundColor: Cosmic.ink,
              title: Text(title, style: Cosmic.title(NeonType.title3)),
              bottom: bottom,
            ),
            body: child,
          ),
        ),
      );
}

/// "View Your Kundli": the chart in four tabs.
class _ChartPage extends StatelessWidget {
  const _ChartPage({required this.result, required this.service, required this.speaker});
  final ChartResult result;
  final JyotishService service;
  final JyotishSpeaker speaker;

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 4,
        child: _JyotishPage(
          title: result.birth.name ?? 'Your Kundli',
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Kundli'),
              Tab(text: 'Planets'),
              Tab(text: 'Dasha'),
              Tab(text: 'Predictions'),
            ],
          ),
          child: TabBarView(children: [
            _KundliTab(result: result, service: service),
            _PlanetsTab(result: result),
            _DashaTab(chart: result.chart),
            JyotishPredict(birth: result.birth, service: service, speaker: speaker),
          ]),
        ),
      );
}

// ── Kundli ─────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.result});
  final ChartResult result;

  @override
  Widget build(BuildContext context) {
    final b = result.birth;
    final c = result.chart;
    final (md, ad) = c.dashaAt(DateTime.now());
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(b.name ?? 'Your chart', style: Cosmic.title(NeonType.title3)),
      const SizedBox(height: 2),
      Text('${prettyDate(b.date)} · ${prettyTime(b.time)}${b.place != null ? ' · ${b.place}' : ''}',
          style: Cosmic.label(), maxLines: 2, overflow: TextOverflow.ellipsis),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, children: [
        FactChip(label: 'Lagna', value: c.lagna?.signName ?? 'Needs birth time',
            color: c.lagna == null ? Cosmic.faint : Cosmic.gold),
        FactChip(label: 'Moon sign', value: c.rashi, color: Cosmic.sky),
        FactChip(label: 'Nakshatra', value: '${c.nakshatra} ${c.pada}${c.moonUncertain ? ' ?' : ''}', color: Cosmic.sky),
        if (md != null) FactChip(label: 'Dasha now', value: '${md.lord}${ad != null ? ' / ${ad.lord}' : ''}', color: Cosmic.rose),
      ]),
    ]);
  }
}

class _KundliTab extends StatefulWidget {
  const _KundliTab({required this.result, required this.service});
  final ChartResult result;
  final JyotishService service;

  @override
  State<_KundliTab> createState() => _KundliTabState();
}

class _KundliTabState extends State<_KundliTab> with AutomaticKeepAliveClientMixin {
  KundliStyle _style = KundliStyle.north;
  late Transits _transits = widget.result.transits;
  DateTime? _transitDate;
  bool _loadingTransits = false;
  bool _transitError = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void didUpdateWidget(_KundliTab old) {
    super.didUpdateWidget(old);
    if (old.result != widget.result) {
      _transits = widget.result.transits;
      _transitDate = null;
    }
  }

  Future<void> _pickTransitDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _transitDate ?? now,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
      helpText: 'Transits on which date?',
    );
    if (d == null || !mounted) return;
    setState(() {
      _transitDate = d;
      _loadingTransits = true;
      _transitError = false;
    });
    final r = await widget.service.chart(widget.result.birth, transitDate: d);
    if (!mounted) return;
    setState(() {
      _loadingTransits = false;
      if (r == null) {
        _transitError = true;
      } else {
        _transits = r.transits;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final c = widget.result.chart;
    return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 40), children: [
      _Header(result: widget.result),
      const SizedBox(height: 16),
      if (!c.timeKnown)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: CosmicCard(
            child: Row(children: [
              const Icon(Icons.schedule_rounded, color: Cosmic.warn),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                    'Birth time needed for the lagna, houses and Raj Yoga. This is the Moon chart (Chandra kundli); dasha and transits are complete.${c.moonUncertain ? ' The nakshatra could differ by birth time.' : ''}',
                    style: Cosmic.label()),
              ),
            ]),
          ),
        ),
      Center(
        child: SegmentedButton<KundliStyle>(
          segments: const [
            ButtonSegment(value: KundliStyle.north, label: Text('North Indian')),
            ButtonSegment(value: KundliStyle.south, label: Text('South Indian')),
          ],
          selected: {_style},
          onSelectionChanged: (s) => setState(() => _style = s.first),
        ),
      ),
      const SizedBox(height: 14),
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: KundliChart(chart: c, style: _style, colors: Cosmic.kundli),
      ),
      const SizedBox(height: 6),
      Text('Numbers are signs (1 = Aries). R = retrograde.', style: Cosmic.label(NeonType.caption), textAlign: TextAlign.center),
      const SectionTitle('Saturn and the Moon'),
      _saturnCard(c.saturn),
      const SectionTitle('Yogas'),
      CosmicCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(children: [for (final y in c.yogas) _yogaRow(y)]),
      ),
      const SectionTitle('Manglik dosha'),
      _manglikCard(c.manglik),
      SectionTitle(
        'Gochar (transits)',
        trailing: TextButton.icon(
          onPressed: _loadingTransits ? null : _pickTransitDate,
          icon: const Icon(Icons.event_rounded, size: 18),
          label: Text(_transitDate == null ? 'Today' : prettyDay(_transitDate)),
        ),
      ),
      if (_loadingTransits)
        const LinearProgressIndicator(color: Cosmic.gold, backgroundColor: Cosmic.edge)
      else if (_transitError)
        Text('Unable to load transits for that date. Please try again.', style: Cosmic.body().copyWith(color: Cosmic.rose))
      else
        _transitTable(_transits, c.timeKnown),
    ]);
  }

  Widget _saturnCard(SaturnStatus s) {
    final lines = <(IconData, Color, String)>[];
    if (s.sadeSati) {
      lines.add((Icons.brightness_3_rounded, Cosmic.warn,
          'Sade Sati is running — ${s.phase ?? ''} phase (about ${prettyDate(s.sadeStart)} to ${prettyDate(s.sadeEnd)}).'));
    } else {
      lines.add((Icons.check_circle_outline_rounded, Cosmic.good,
          'No Sade Sati now.${s.sadeNext != null ? ' The next begins about ${prettyDate(s.sadeNext)}.' : ''}'));
    }
    if (s.ashtama) {
      lines.add((Icons.brightness_3_rounded, Cosmic.warn,
          'Ashtama Shani: Saturn is 8th from your Moon (about ${prettyDate(s.ashtamaStart)} to ${prettyDate(s.ashtamaEnd)}).'));
    }
    if (s.houseFromMoon != null) {
      lines.add((Icons.public_rounded, Cosmic.dim, 'Saturn is transiting house ${s.houseFromMoon} from your Moon.'));
    }
    return CosmicCard(
      child: Column(children: [
        for (final (icon, color, text) in lines)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(text, style: Cosmic.body())),
            ]),
          ),
      ]),
    );
  }

  Widget _yogaRow(Yoga y) {
    final (icon, color, status) = switch (y.present) {
      true => (Icons.star_rounded, Cosmic.gold, 'Present'),
      false => (Icons.remove_circle_outline_rounded, Cosmic.faint, 'Not present'),
      null => (Icons.schedule_rounded, Cosmic.faint, 'Birth time needed'),
    };
    return Semantics(
      label: '${y.name}: $status${y.present == true && y.reason != null ? '. ${y.reason}' : ''}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(y.name, style: Cosmic.body().copyWith(color: y.present == true ? Cosmic.ink : Cosmic.dim)),
              if (y.present == true && y.reason != null) Text(y.reason!, style: Cosmic.label(NeonType.caption)),
              if (y.present != true) Text(status, style: Cosmic.label(NeonType.caption).copyWith(color: Cosmic.faint)),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _manglikCard(Manglik m) {
    final verdict = !m.present
        ? 'Not Manglik'
        : m.mitigated
            ? 'Manglik, with mitigation'
            : 'Manglik';
    return CosmicCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(verdict, style: Cosmic.title(NeonType.body).copyWith(color: m.present ? Cosmic.warn : Cosmic.good)),
        const SizedBox(height: 4),
        Text(
          'Mars is in house ${m.fromMoonHouse} from the Moon'
          '${m.fromLagnaHouse != null ? ' and house ${m.fromLagnaHouse} from the lagna' : ''}.'
          '${m.partial ? ' Checked from the Moon only — the birth time is needed for the lagna.' : ''}',
          style: Cosmic.label(),
        ),
        for (final x in m.mitigations) Text('• $x', style: Cosmic.label()),
      ]),
    );
  }

  Widget _transitTable(Transits t, bool timeKnown) {
    return CosmicCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(children: [
        _row(['Planet', 'Sign', 'From Moon', if (timeKnown) 'From lagna'], header: true),
        for (final p in t.planets)
          _row([
            '${p.name}${p.showRetro ? ' R' : ''}',
            p.signName,
            '${p.houseFromMoon ?? '—'}',
            if (timeKnown) '${p.houseFromLagna ?? '—'}',
          ]),
      ]),
    );
  }
}

Widget _row(List<String> cells, {bool header = false, bool highlight = false}) {
  final style = header
      ? Cosmic.label(NeonType.caption).copyWith(fontWeight: FontWeight.w700)
      : Cosmic.body(NeonType.footnote).copyWith(color: highlight ? Cosmic.gold : Cosmic.ink);
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(children: [
      for (var i = 0; i < cells.length; i++)
        Expanded(
          flex: i == 0 ? 3 : 2,
          child: Text(cells[i], style: style, textAlign: i == 0 ? TextAlign.start : TextAlign.center),
        ),
    ]),
  );
}

// ── Planets ────────────────────────────────────────────────────────────

class _PlanetsTab extends StatelessWidget {
  const _PlanetsTab({required this.result});
  final ChartResult result;

  @override
  Widget build(BuildContext context) {
    final c = result.chart;
    return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 40), children: [
      _Header(result: result),
      const SectionTitle('Planet positions (sidereal, Lahiri)'),
      CosmicCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(children: [
          _row(['Planet', 'Sign', 'Degree', 'Nakshatra', if (c.timeKnown) 'House'], header: true),
          if (c.lagna != null)
            _row(['Lagna', c.lagna!.signName, c.lagna!.dms, '${c.lagna!.nakshatra} ${c.lagna!.pada}', if (c.timeKnown) '1'],
                highlight: true),
          for (final p in c.planets)
            _row([
              '${p.name}${p.showRetro ? ' R' : ''}',
              p.signName,
              p.dms,
              '${p.nakshatra} ${p.pada}',
              if (c.timeKnown) '${p.house ?? '—'}',
            ]),
        ]),
      ),
      const SizedBox(height: 10),
      Text('R = retrograde. Rahu and Ketu are the mean lunar nodes and always move backwards.',
          style: Cosmic.label(NeonType.caption)),
      if (!c.timeKnown)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text('Houses need the birth time.', style: Cosmic.label(NeonType.caption).copyWith(color: Cosmic.warn)),
        ),
    ]);
  }
}

// ── Dasha ──────────────────────────────────────────────────────────────

class _DashaTab extends StatelessWidget {
  const _DashaTab({required this.chart});
  final Chart chart;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final (md, ad) = chart.dashaAt(now);
    if (chart.dashas.isEmpty) {
      return Center(child: Text('No dasha timeline for this chart.', style: Cosmic.label()));
    }
    return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 40), children: [
      if (md != null)
        CosmicCard(
          glow: true,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Running now', style: Cosmic.label()),
            const SizedBox(height: 4),
            Text('${md.lord} mahadasha', style: Cosmic.title(NeonType.title3).copyWith(color: Cosmic.gold)),
            Text('${prettyDay(md.start)} – ${prettyDay(md.end)}', style: Cosmic.label()),
            if (ad != null) ...[
              const SizedBox(height: 8),
              Text('${ad.lord} antardasha', style: Cosmic.title(NeonType.body)),
              Text('${prettyDay(ad.start)} – ${prettyDay(ad.end)}', style: Cosmic.label()),
              const SizedBox(height: 8),
              _progress(ad, now),
            ],
          ]),
        ),
      if (chart.balanceLord != null)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(
              'Balance at birth: ${chart.balanceLord} ${chart.balanceYears?.toStringAsFixed(2) ?? ''} years (Vimshottari, from the Moon\'s nakshatra).',
              style: Cosmic.label(NeonType.caption)),
        ),
      const SectionTitle('Vimshottari timeline'),
      for (final m in chart.dashas)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: CosmicCard(
            padding: EdgeInsets.zero,
            glow: identical(m, md),
            child: ExpansionTile(
              initiallyExpanded: identical(m, md),
              shape: const Border(),
              collapsedShape: const Border(),
              iconColor: Cosmic.gold,
              collapsedIconColor: Cosmic.dim,
              title: Text('${m.lord} mahadasha', style: Cosmic.body().copyWith(color: identical(m, md) ? Cosmic.gold : Cosmic.ink)),
              subtitle: Text('${prettyDay(m.start)} – ${prettyDay(m.end)}', style: Cosmic.label(NeonType.caption)),
              children: [
                for (final a in m.sub)
                  Semantics(
                    label: '${a.lord} antardasha, ${prettyDay(a.start)} to ${prettyDay(a.end)}${identical(a, ad) ? ', running now' : ''}',
                    excludeSemantics: true,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: Row(children: [
                        Icon(identical(a, ad) ? Icons.play_arrow_rounded : Icons.circle, size: identical(a, ad) ? 18 : 6,
                            color: identical(a, ad) ? Cosmic.gold : Cosmic.faint),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text('${m.lord} / ${a.lord}',
                              style: Cosmic.body(NeonType.footnote).copyWith(color: identical(a, ad) ? Cosmic.gold : Cosmic.ink)),
                        ),
                        Text('${prettyDay(a.start)} – ${prettyDay(a.end)}', style: Cosmic.label(NeonType.caption)),
                      ]),
                    ),
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
    ]);
  }

  Widget _progress(DashaPeriod p, DateTime now) {
    if (p.start == null || p.end == null) return const SizedBox.shrink();
    final total = p.end!.difference(p.start!).inMinutes;
    final done = now.difference(p.start!).inMinutes;
    final f = total <= 0 ? 0.0 : (done / total).clamp(0.0, 1.0);
    return Semantics(
      label: '${(f * 100).round()} percent of this antardasha has passed',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(value: f, minHeight: 6, color: Cosmic.gold, backgroundColor: Cosmic.edge),
      ),
    );
  }
}
