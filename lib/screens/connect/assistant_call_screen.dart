import 'dart:async';
import 'dart:math' as math;

import 'package:firebase_ai/firebase_ai.dart' show FunctionResponse;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../ai/live_voice.dart';
import '../../ai/openai_live.dart';
import '../../core/log.dart';
import '../../design/neon_tokens.dart';
import '../../design/neon_widgets.dart';
import '../../services/api_service.dart';
import '../../services/audio/mic_stream.dart';
import '../../services/audio/pcm_player.dart';
import '../../services/connect_service.dart';

/// ─────────────────────────────────────────────────────────────────────────
///  A LIVE CALL WITH SOMEONE ELSE'S ASSISTANT (owner, 2026-11-21).
///
///  "Connect me to Alan's assistant": this screen opens a realtime voice
///  session in which the model IS Alan's assistant — the server sets Alan's
///  assistant name, Alan's voice and the guest instructions and tools
///  (POST /connect/:id/secret). The orb holds Alan's photo; the assistant
///  introduces itself by the name Alan gave it.
///
///  It can take a message, pass on something urgent, say when Alan is free
///  and book an appointment — each a tool the server runs for Alan
///  (POST /connect/:id/tool). When the call ends, Alan gets a two-line
///  summary (POST /connect/:id/end).
///
///  Audio is half-duplex: the mic is not sent while the assistant speaks,
///  so the phone's own speaker cannot talk over it.
/// ─────────────────────────────────────────────────────────────────────────
class AssistantCallScreen extends StatefulWidget {
  const AssistantCallScreen({super.key, required this.hostId, this.preview});

  final int hostId;

  /// What the list already knows, so the orb shows the right face at once.
  final AssistantContact? preview;

  @override
  State<AssistantCallScreen> createState() => _AssistantCallScreenState();
}

enum _Phase { connecting, listening, working, speaking, ended, failed }

class _AssistantCallScreenState extends State<AssistantCallScreen>
    with SingleTickerProviderStateMixin {
  late AssistantContact? _host = widget.preview;
  _Phase _phase = _Phase.connecting;
  String? _error;
  bool _muted = false;
  double _level = 0;
  String _caption = '';
  final List<Map<String, String>> _transcript = [];
  final StringBuffer _turn = StringBuffer();

  LiveSessionPort? _session;
  StreamSubscription<LiveIn>? _sub;
  final MicStream _mic = MicStream();
  final PcmPlayer _player = PcmPlayer();
  late final AnimationController _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1600))
    ..repeat();
  final Stopwatch _clock = Stopwatch();
  Timer? _ticker;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _player.playingListenable.addListener(_onPlaying);
    unawaited(_start());
  }

  @override
  void dispose() {
    _player.playingListenable.removeListener(_onPlaying);
    _ticker?.cancel();
    _pulse.dispose();
    // Back mid-call still tells the host what was said (2+ turns only).
    unawaited(_teardown(summary: true));
    super.dispose();
  }

  void _onPlaying() {
    if (!mounted || _phase == _Phase.ended || _phase == _Phase.failed) return;
    setState(() {
      if (_player.playing) {
        _phase = _Phase.speaking;
      } else if (_phase == _Phase.speaking) {
        _phase = _Phase.listening;
      }
    });
  }

  Future<void> _start() async {
    if (!await Permission.microphone.request().isGranted) {
      _fail('Microphone permission is needed to talk to the assistant.');
      return;
    }
    final minted = await ConnectService.mint(widget.hostId);
    if (!mounted) return;
    if (minted == null) {
      _fail(ConnectService.lastError ?? 'Unable to reach the assistant.');
      return;
    }
    final card = minted['card'];
    if (card is Map) {
      setState(() =>
          _host = AssistantContact.fromJson(card.cast<String, dynamic>()));
    }
    try {
      // The key is already minted with the host's voice, instructions and
      // tools; the connector only opens the socket with it.
      final connector = OpenAiLiveConnector(mintSecret: (_) async => minted);
      final session = await connector.connect(LiveSetup(
        model: (minted['model'] ?? '').toString(),
        voice: _host?.voice ?? '',
        system: '',
      ));
      if (!mounted) {
        await session.close();
        return;
      }
      _session = session;
      _sub = session.messages.listen(_onMessage, onDone: () {
        if (mounted && !_closing) _hangUp();
      });
      final ok = await _mic.start((pcm, level) {
        if (_muted || _player.playing || _session == null) return;
        _session!.sendAudio(pcm);
        if (level != null && mounted) {
          final l = level.clamp(0.0, 1.0);
          if ((l - _level).abs() > 0.04) setState(() => _level = l);
        }
      }, onLost: (_) => _fail('The microphone stopped.'));
      if (!ok) {
        _fail(
            'The microphone is busy. Close other apps using it and try again.');
        return;
      }
      _clock.start();
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
      setState(() => _phase = _Phase.listening);
      // The assistant speaks first: it introduces itself.
      session.sendText(
          (minted['greeting'] ?? '[SYSTEM] Introduce yourself now.')
              .toString());
      HapticFeedback.mediumImpact();
    } catch (e) {
      AppLog.add('connect', 'session failed: ${e.runtimeType}');
      _fail('Unable to connect. Please try again.');
    }
  }

  void _onMessage(LiveIn m) {
    switch (m) {
      case LiveInContent():
        for (final (Uint8List pcm, int rate) in m.audio) {
          unawaited(_player.play(pcm, sampleRate: rate));
        }
        if (m.heard != null && m.heard!.trim().isNotEmpty) {
          _transcript.add({'role': 'user', 'text': m.heard!.trim()});
        }
        if (m.said != null) {
          _turn.write(m.said);
          setState(() => _caption = _turn.toString());
        }
        if (m.turnComplete) {
          final said = _turn.toString().trim();
          if (said.isNotEmpty) {
            _transcript.add({'role': 'assistant', 'text': said});
          }
          _turn.clear();
        }
      case LiveInToolCall():
        unawaited(_runTools(m));
      default:
        break;
    }
  }

  Future<void> _runTools(LiveInToolCall m) async {
    if (mounted) setState(() => _phase = _Phase.working);
    var ends = false;
    final answers = <FunctionResponse>[];
    for (final c in m.calls) {
      final r = await ConnectService.tool(
          widget.hostId, c.name, Map<String, dynamic>.from(c.args));
      if (r.ends) ends = true;
      answers.add(FunctionResponse(c.name, r.json, id: c.id));
    }
    _session?.sendToolResponses(answers);
    if (mounted && _phase == _Phase.working) {
      setState(() => _phase = _Phase.listening);
    }
    if (ends) {
      // Let the goodbye finish playing, then hang up.
      await Future<void>.delayed(const Duration(milliseconds: 600));
      await _player
          .drained()
          .timeout(const Duration(seconds: 8), onTimeout: () {});
      if (mounted) _hangUp();
    }
  }

  /// A chip tapped: said to the assistant as if spoken, so it starts that
  /// task (asks for the message, checks the calendar…) out loud.
  void _askFor(String request) {
    final s = _session;
    if (s == null) return;
    HapticFeedback.selectionClick();
    // Whatever it was saying stops; the new request is answered at once.
    if (s is CancellableReply) (s as CancellableReply).cancelReply();
    unawaited(_player.stop());
    _transcript.add({'role': 'user', 'text': request});
    _turn.clear();
    setState(() {
      _caption = '';
      if (_muted) _muted = false; // they want to talk now
    });
    s.sendText(request);
  }

  void _fail(String why) {
    if (!mounted) return;
    setState(() {
      _phase = _Phase.failed;
      _error = why;
    });
    unawaited(_teardown(summary: false));
  }

  Future<void> _hangUp() async {
    if (_closing) return;
    HapticFeedback.lightImpact();
    setState(() => _phase = _Phase.ended);
    await _teardown(summary: true);
    if (mounted) Navigator.of(context).maybePop();
  }

  Future<void> _teardown({required bool summary}) async {
    if (_closing) return;
    _closing = true;
    _ticker?.cancel();
    _clock.stop();
    try {
      await _mic.stop();
    } catch (_) {}
    try {
      await _player.stop();
    } catch (_) {}
    await _sub?.cancel();
    try {
      await _session?.close();
    } catch (_) {}
    _session = null;
    final said = _turn.toString().trim();
    if (said.isNotEmpty) _transcript.add({'role': 'assistant', 'text': said});
    if (summary && _transcript.length >= 2) {
      unawaited(ConnectService.end(widget.hostId, List.of(_transcript)));
    }
  }

  String get _status => switch (_phase) {
        _Phase.connecting => 'Connecting…',
        _Phase.listening => _muted ? 'Muted' : 'Listening',
        _Phase.working => 'Working on it…',
        _Phase.speaking => 'Speaking',
        _Phase.ended => 'Call Ended',
        _Phase.failed => 'Unable to Connect',
      };

  String get _elapsed {
    final s = _clock.elapsed.inSeconds;
    return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final h = _host;
    final owner = h?.firstName ?? 'Contact';
    return NeonScaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: Row(children: [
                IconButton(
                  tooltip: 'Back',
                  icon: Icon(Icons.keyboard_arrow_down_rounded,
                      color: Neon.textHi, size: 30),
                  onPressed: _hangUp,
                ),
                const Spacer(),
                if (_clock.isRunning)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Neon.surface,
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(color: Neon.line),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                              color: Neon.success, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Text(_elapsed,
                          style: TextStyle(
                              color: Neon.textHi,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ])),
                    ]),
                  ),
                const SizedBox(width: 12),
              ]),
            ),
            const Spacer(),
            _Orb(
              size: (MediaQuery.sizeOf(context).height * 0.21)
                  .clamp(140.0, 200.0),
              host: h,
              pulse: _pulse,
              phase: _phase,
              level: _phase == _Phase.listening ? _level : 0,
            ),
            const SizedBox(height: 16),
            Text(h?.assistantName ?? 'Assistant',
                textAlign: TextAlign.center,
                style: GoogleFonts.interTight(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Neon.textHi,
                    letterSpacing: -0.6)),
            const SizedBox(height: 4),
            Text("$owner's Assistant",
                style: TextStyle(
                    color: Neon.textLo,
                    fontSize: 15,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 10),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(_status,
                  key: ValueKey(_status),
                  style: TextStyle(
                      color: _phase == _Phase.failed ? Neon.error : Neon.violet,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2)),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: SizedBox(
                height: 62,
                child: Text(
                  _error ?? _caption,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.fade,
                  style: TextStyle(
                      color: _error != null
                          ? Neon.error
                          : Neon.textHi.withValues(alpha: 0.85),
                      fontSize: 15,
                      height: 1.4),
                ),
              ),
            ),
            const Spacer(),
            _abilities(owner),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _RoundButton(
                  icon: _muted ? Icons.mic_off_rounded : Icons.mic_rounded,
                  label: _muted ? 'Unmute' : 'Mute',
                  color: _muted ? Neon.warning : Neon.surface,
                  ink: _muted ? Colors.black : Neon.textHi,
                  onTap: _phase == _Phase.failed
                      ? null
                      : () {
                          HapticFeedback.selectionClick();
                          setState(() => _muted = !_muted);
                        },
                ),
                const SizedBox(width: 36),
                _RoundButton(
                  icon: _phase == _Phase.failed
                      ? Icons.close_rounded
                      : Icons.call_end_rounded,
                  label: _phase == _Phase.failed ? 'Close' : 'End',
                  color: Neon.error,
                  ink: Colors.white,
                  big: true,
                  onTap: _phase == _Phase.failed
                      ? () => Navigator.of(context).maybePop()
                      : _hangUp,
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  /// What this assistant can do, so the caller knows what to ask.
  Widget _abilities(String owner) {
    final live = _session != null &&
        _phase != _Phase.connecting &&
        _phase != _Phase.ended &&
        _phase != _Phase.failed;
    Widget chip(IconData i, String t, String ask) => Material(
          color: Neon.surface,
          shape: StadiumBorder(side: BorderSide(color: Neon.line)),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: live ? () => _askFor(ask) : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(i, size: 15, color: live ? Neon.violet : Neon.textDim),
                const SizedBox(width: 6),
                Text(t,
                    style: TextStyle(
                        color: live ? Neon.textHi : Neon.textDim,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        );
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        chip(Icons.mail_rounded, 'Leave a Message',
            'I would like to leave a message for $owner. Please ask me what it is.'),
        chip(Icons.priority_high_rounded, 'Urgent Alert',
            'I have something urgent for $owner. Please ask me what it is and alert them.'),
        chip(Icons.event_available_rounded, 'Check Availability',
            'When is $owner free today and tomorrow?'),
        chip(Icons.edit_calendar_rounded, 'Book a Time',
            'I would like to book a time with $owner. Please help me choose one.'),
      ],
    );
  }
}

/// The host's photo inside rings that breathe while the assistant speaks
/// and follow the caller's voice while it listens.
class _Orb extends StatelessWidget {
  const _Orb(
      {required this.size,
      required this.host,
      required this.pulse,
      required this.phase,
      required this.level});

  final double size;
  final AssistantContact? host;
  final Animation<double> pulse;
  final _Phase phase;
  final double level;

  @override
  Widget build(BuildContext context) {
    final speaking = phase == _Phase.speaking;
    final working = phase == _Phase.working || phase == _Phase.connecting;
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return SizedBox(
      width: size + 70,
      height: size + 70,
      child: AnimatedBuilder(
        animation: pulse,
        builder: (context, child) {
          final t = still ? 0.0 : pulse.value;
          return Stack(
            alignment: Alignment.center,
            children: [
              for (var i = 0; i < 3; i++)
                _ring(
                  size,
                  phase: (t + i / 3) % 1,
                  strength: speaking
                      ? 1
                      : working
                          ? 0.55
                          : 0.25 + level * 0.9,
                ),
              Container(
                width: size + 14 + level * 16,
                height: size + 14 + level * 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SweepGradient(
                    transform: GradientRotation(still ? 0 : t * 2 * math.pi),
                    colors: [Neon.violet, Neon.pink, Neon.cyan, Neon.violet],
                  ),
                  boxShadow: Neon.halo(Neon.violet),
                ),
              ),
              child!,
            ],
          );
        },
        child: Container(
          width: size,
          height: size,
          decoration:
              BoxDecoration(shape: BoxShape.circle, color: Neon.surface),
          clipBehavior: Clip.antiAlias,
          child: host?.hasPhoto == true
              ? Image.network(
                  host!.photoUrl,
                  headers: ApiService.authHeaders,
                  fit: BoxFit.cover,
                  alignment: const Alignment(0, -0.35),
                  filterQuality: FilterQuality.high,
                  errorBuilder: (_, __, ___) => _initials(),
                )
              : _initials(),
        ),
      ),
    );
  }

  Widget _ring(double size, {required double phase, required double strength}) {
    final grow = size + 16 + phase * 54 * strength.clamp(0.2, 1.0);
    return Container(
      width: grow,
      height: grow,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Neon.violet
              .withValues(alpha: (1 - phase) * 0.35 * strength.clamp(0.2, 1.0)),
          width: 2,
        ),
      ),
    );
  }

  Widget _initials() {
    final n = (host?.ownerName ?? '').trim();
    final parts = n
        .replaceAll(RegExp(r'[^\p{L}\s]', unicode: true), ' ')
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    final ini = parts.isEmpty
        ? '?'
        : (parts.first[0] + (parts.length > 1 ? parts.last[0] : ''))
            .toUpperCase();
    return Container(
      decoration: BoxDecoration(gradient: Neon.gBrand),
      alignment: Alignment.center,
      child: Text(ini,
          style: GoogleFonts.interTight(
              fontSize: 64, fontWeight: FontWeight.w700, color: Neon.onBrand)),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.ink,
    required this.onTap,
    this.big = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color ink;
  final VoidCallback? onTap;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final d = big ? 72.0 : 60.0;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Material(
        color: color,
        shape: CircleBorder(side: BorderSide(color: Neon.line)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
              width: d,
              height: d,
              child: Icon(icon, color: ink, size: big ? 32 : 26)),
        ),
      ),
      const SizedBox(height: 8),
      Text(label,
          style: TextStyle(
              color: Neon.textLo, fontSize: 12.5, fontWeight: FontWeight.w600)),
    ]);
  }
}
