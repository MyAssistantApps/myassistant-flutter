import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../design/neon_scaffold.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../design/apple_kit.dart';
import '../../design/neon_tokens.dart';

/// THE GAMES HUB (client, 2026-11-01: "add a Games section within the Hubs,
/// lightweight casual games users can play directly within the app").
/// Three short games of our own, offline, in the app's colours: memory
/// pairs, a 60-second maths sprint, and tic-tac-toe against Maya. Each
/// keeps its best result on the phone.

/// The best result a game keeps, lower-is-better or higher-is-better.
class GameBest {
  static Future<int?> get(String key) async {
    try {
      return (await SharedPreferences.getInstance()).getInt('game_best_$key');
    } catch (_) {
      return null;
    }
  }

  /// Saves [value] when it beats the best; true when it did.
  static Future<bool> offer(String key, int value,
      {required bool lowerWins}) async {
    try {
      final p = await SharedPreferences.getInstance();
      final old = p.getInt('game_best_$key');
      final better = old == null || (lowerWins ? value < old : value > old);
      if (better) await p.setInt('game_best_$key', value);
      return better;
    } catch (_) {
      return false;
    }
  }
}

/// A finished game's panel: the result, the best, and Play again.
class _Result extends StatelessWidget {
  const _Result(
      {required this.title,
      required this.line,
      required this.onAgain,
      this.best});
  final String title;
  final String line;
  final String? best;
  final VoidCallback onAgain;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: Color.lerp(Neon.bg, Colors.black, 0.25),
          border: Border.all(color: Neon.violet.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
                color: Neon.violet.withValues(alpha: 0.25), blurRadius: 24)
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title,
                style: NeonType.manrope(24, FontWeight.w800)
                    .copyWith(color: Neon.textHi)),
            const SizedBox(height: 6),
            Text(line,
                textAlign: TextAlign.center,
                style: TextStyle(color: Neon.textLo, fontSize: 15)),
            if (best != null) ...[
              const SizedBox(height: 4),
              Text(best!,
                  style: TextStyle(
                      color: Neon.cyan,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onAgain,
              icon: const Icon(Icons.replay_rounded),
              label: const Text('Play again'),
            ),
          ],
        ),
      );
}

Widget _stat(String label, String value) => Column(
      children: [
        Text(value,
            style: NeonType.manrope(22, FontWeight.w800)
                .copyWith(color: Neon.textHi, fontFeatures: NeonType.figures)),
        Text(label, style: TextStyle(color: Neon.textLo, fontSize: 12.5)),
      ],
    );

// ─────────────────────────────── memory pairs ───────────────────────────────

class MemoryPairsScreen extends StatefulWidget {
  const MemoryPairsScreen({super.key, this.seed});
  final int? seed;

  @override
  State<MemoryPairsScreen> createState() => _MemoryPairsScreenState();
}

class _MemoryPairsScreenState extends State<MemoryPairsScreen> {
  static const _icons = [
    Icons.favorite_rounded,
    Icons.star_rounded,
    Icons.bolt_rounded,
    Icons.music_note_rounded,
    Icons.local_cafe_rounded,
    Icons.flight_rounded,
    Icons.pets_rounded,
    Icons.wb_sunny_rounded,
  ];
  late List<int> _cards;
  final Set<int> _open = {};
  final Set<int> _done = {};
  int _moves = 0;
  bool _busy = false;
  final _clock = Stopwatch();
  Timer? _tick;
  String? _best;

  @override
  void initState() {
    super.initState();
    _deal();
  }

  void _deal() {
    _cards = [
      for (var i = 0; i < _icons.length; i++) ...[i, i]
    ]..shuffle(math.Random(widget.seed));
    _open.clear();
    _done.clear();
    _moves = 0;
    _best = null;
    _clock
      ..reset()
      ..stop();
    _tick?.cancel();
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _flip(int i) async {
    if (_busy || _open.contains(i) || _done.contains(i)) return;
    HapticFeedback.selectionClick();
    if (!_clock.isRunning) {
      _clock.start();
      _tick = Timer.periodic(
          const Duration(seconds: 1), (_) => mounted ? setState(() {}) : null);
    }
    setState(() => _open.add(i));
    if (_open.length < 2) return;
    _moves++;
    final [a, b] = _open.toList();
    if (_cards[a] == _cards[b]) {
      _done.addAll([a, b]);
      _open.clear();
      if (_done.length == _cards.length) {
        _clock.stop();
        _tick?.cancel();
        HapticFeedback.mediumImpact();
        final better =
            await GameBest.offer('pairs_moves', _moves, lowerWins: true);
        final best = await GameBest.get('pairs_moves');
        if (mounted) {
          setState(() => _best = better ? 'A new best!' : 'Best: $best moves');
        }
      }
      if (mounted) setState(() {});
      return;
    }
    _busy = true;
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() {
      _open.clear();
      _busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final won = _done.length == _cards.length;
    final secs = _clock.elapsed.inSeconds;
    final colors = [Neon.cyan, Neon.violet, Neon.pink];
    return NeonScaffold(
      appBar: appleAppBar(context, 'Memory pairs'),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _stat('moves', '$_moves'),
                  _stat('time',
                      '${secs ~/ 60}:${(secs % 60).toString().padLeft(2, '0')}'),
                  _stat('pairs', '${_done.length ~/ 2}/8')
                ],
              ),
              const SizedBox(height: 18),
              Expanded(
                child: Center(
                  child: won
                      ? _Result(
                          title: 'All pairs found',
                          line: '$_moves moves in ${secs}s.',
                          best: _best,
                          onAgain: () => setState(_deal),
                        )
                      : AspectRatio(
                          aspectRatio: 1,
                          child: GridView.count(
                            crossAxisCount: 4,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            physics: const NeverScrollableScrollPhysics(),
                            children: [
                              for (var i = 0; i < _cards.length; i++)
                                Semantics(
                                  button: true,
                                  label: _open.contains(i) || _done.contains(i)
                                      ? 'Card ${_cards[i] + 1}'
                                      : 'Hidden card',
                                  child: GestureDetector(
                                    onTap: () => _flip(i),
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 220),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(16),
                                        gradient: _open.contains(i) ||
                                                _done.contains(i)
                                            ? null
                                            : LinearGradient(
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                                colors: [
                                                  Neon.violet
                                                      .withValues(alpha: 0.55),
                                                  Neon.cyan
                                                      .withValues(alpha: 0.35)
                                                ],
                                              ),
                                        color: _open.contains(i) ||
                                                _done.contains(i)
                                            ? Color.lerp(
                                                Neon.bg, Colors.black, 0.2)
                                            : null,
                                        border: Border.all(
                                          color: _done.contains(i)
                                              ? Neon.cyan.withValues(alpha: 0.7)
                                              : Colors.white
                                                  .withValues(alpha: 0.12),
                                        ),
                                      ),
                                      child:
                                          _open.contains(i) || _done.contains(i)
                                              ? Icon(_icons[_cards[i]],
                                                  size: 30,
                                                  color: colors[_cards[i] % 3])
                                              : Icon(Icons.auto_awesome_rounded,
                                                  size: 18,
                                                  color: Colors.white
                                                      .withValues(alpha: 0.35)),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────── quick maths ───────────────────────────────

class QuickMathsScreen extends StatefulWidget {
  const QuickMathsScreen({super.key, this.seconds = 60, this.seed});
  final int seconds;
  final int? seed;

  @override
  State<QuickMathsScreen> createState() => _QuickMathsScreenState();
}

class _QuickMathsScreenState extends State<QuickMathsScreen> {
  late final math.Random _rand = math.Random(widget.seed);
  int _left = 0;
  int _score = 0;
  bool _playing = false;
  String _q = '';
  int _answer = 0;
  List<int> _choices = const [];
  int? _wrong;
  Timer? _timer;
  String? _best;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    HapticFeedback.selectionClick();
    setState(() {
      _left = widget.seconds;
      _score = 0;
      _playing = true;
      _best = null;
      _next();
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!mounted) return;
      if (_left <= 1) {
        _timer?.cancel();
        setState(() {
          _left = 0;
          _playing = false;
        });
        final better =
            await GameBest.offer('maths_score', _score, lowerWins: false);
        final best = await GameBest.get('maths_score');
        if (mounted) {
          setState(() => _best =
              better && _score > 0 ? 'A new best!' : 'Best: ${best ?? 0}');
        }
      } else {
        setState(() => _left--);
      }
    });
  }

  void _next() {
    // Harder as the score climbs: bigger numbers, then times.
    final level = 1 + _score ~/ 5;
    final op = _rand.nextInt(level > 2 ? 3 : 2);
    int a = 2 + _rand.nextInt(8 * level), b = 2 + _rand.nextInt(8 * level);
    if (op == 2) {
      a = 2 + _rand.nextInt(9 + level);
      b = 2 + _rand.nextInt(9);
    }
    if (op == 1 && b > a) {
      final t = a;
      a = b;
      b = t;
    }
    _answer = switch (op) { 0 => a + b, 1 => a - b, _ => a * b };
    _q = '$a ${['+', '−', '×'][op]} $b';
    final set = <int>{_answer};
    while (set.length < 4) {
      final d = 1 + _rand.nextInt(math.max(3, _answer.abs() ~/ 4 + 2));
      set.add(_rand.nextBool() ? _answer + d : math.max(0, _answer - d));
    }
    _choices = set.toList()..shuffle(_rand);
    _wrong = null;
  }

  void _pick(int v) {
    if (!_playing) return;
    if (v == _answer) {
      HapticFeedback.selectionClick();
      setState(() {
        _score++;
        _next();
      });
    } else {
      HapticFeedback.heavyImpact();
      setState(() => _wrong = v);
    }
  }

  @override
  Widget build(BuildContext context) {
    return NeonScaffold(
      appBar: appleAppBar(context, 'Quick maths'),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _stat('seconds', '$_left'),
                  _stat('correct', '$_score')
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: widget.seconds == 0 ? 0 : _left / widget.seconds,
                  minHeight: 6,
                  color: Neon.cyan,
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                ),
              ),
              Expanded(
                child: Center(
                  child: !_playing
                      ? (_best == null
                          ? _Result(
                              title: 'Quick maths',
                              line:
                                  'As many sums as you can in ${widget.seconds} seconds. A wrong answer costs nothing but time.',
                              onAgain: _start,
                            )
                          : _Result(
                              title: 'Time!',
                              line: '$_score correct.',
                              best: _best,
                              onAgain: _start))
                      : SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_q,
                                  style: NeonType.manrope(52, FontWeight.w800)
                                      .copyWith(
                                          color: Neon.textHi,
                                          fontFeatures: NeonType.figures)),
                              const SizedBox(height: 28),
                              GridView.count(
                                crossAxisCount: 2,
                                shrinkWrap: true,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                childAspectRatio: 2.2,
                                physics: const NeverScrollableScrollPhysics(),
                                children: [
                                  for (final c in _choices)
                                    Material(
                                      color: c == _wrong
                                          ? Neon.pink.withValues(alpha: 0.25)
                                          : Colors.white
                                              .withValues(alpha: 0.07),
                                      borderRadius: BorderRadius.circular(18),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(18),
                                        onTap: () => _pick(c),
                                        child: Center(
                                          child: Text('$c',
                                              style: NeonType.manrope(
                                                      26, FontWeight.w800)
                                                  .copyWith(
                                                      color: Neon.textHi,
                                                      fontFeatures:
                                                          NeonType.figures)),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────── tic-tac-toe ───────────────────────────────

/// The board's winner: 'X', 'O', 'draw' or null.
String? ticWinner(List<String?> b) {
  const lines = [
    [0, 1, 2],
    [3, 4, 5],
    [6, 7, 8],
    [0, 3, 6],
    [1, 4, 7],
    [2, 5, 8],
    [0, 4, 8],
    [2, 4, 6]
  ];
  for (final l in lines) {
    final v = b[l[0]];
    if (v != null && v == b[l[1]] && v == b[l[2]]) return v;
  }
  return b.every((c) => c != null) ? 'draw' : null;
}

/// Maya's move: win if she can, block if she must, else centre, a corner,
/// anything — and now and then a plain random move, so she can be beaten.
int mayaMove(List<String?> b, math.Random rand, {double slip = 0.15}) {
  final free = [
    for (var i = 0; i < 9; i++)
      if (b[i] == null) i
  ];
  if (rand.nextDouble() < slip) return free[rand.nextInt(free.length)];
  for (final who in ['O', 'X']) {
    for (final i in free) {
      final t = [...b]..[i] = who;
      if (ticWinner(t) == who) return i;
    }
  }
  if (b[4] == null) return 4;
  final corners = [0, 2, 6, 8].where((i) => b[i] == null).toList();
  if (corners.isNotEmpty) return corners[rand.nextInt(corners.length)];
  return free[rand.nextInt(free.length)];
}

class TicTacToeScreen extends StatefulWidget {
  const TicTacToeScreen({super.key, this.seed});
  final int? seed;

  @override
  State<TicTacToeScreen> createState() => _TicTacToeScreenState();
}

class _TicTacToeScreenState extends State<TicTacToeScreen> {
  late final math.Random _rand = math.Random(widget.seed);
  List<String?> _b = List.filled(9, null);
  bool _thinking = false;
  int _you = 0, _maya = 0, _draws = 0;

  void _reset() => setState(() => _b = List.filled(9, null));

  Future<void> _tap(int i) async {
    if (_b[i] != null || _thinking || ticWinner(_b) != null) return;
    HapticFeedback.selectionClick();
    setState(() => _b[i] = 'X');
    if (_end()) return;
    setState(() => _thinking = true);
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;
    setState(() {
      _b[mayaMove(_b, _rand)] = 'O';
      _thinking = false;
    });
    _end();
  }

  bool _end() {
    final w = ticWinner(_b);
    if (w == null) return false;
    setState(() {
      if (w == 'X') _you++;
      if (w == 'O') _maya++;
      if (w == 'draw') _draws++;
    });
    HapticFeedback.mediumImpact();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final w = ticWinner(_b);
    final line = switch (w) {
      'X' => 'You win! Again?',
      'O' => 'Maya wins this one.',
      'draw' => "A draw. Nobody's giving in.",
      _ => _thinking ? 'Maya is thinking…' : 'Your move. You are X.',
    };
    return NeonScaffold(
      appBar: appleAppBar(context, 'Tic-tac-toe with Maya'),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _stat('you', '$_you'),
                  _stat('draws', '$_draws'),
                  _stat('Maya', '$_maya')
                ],
              ),
              const SizedBox(height: 18),
              Text(line,
                  style: NeonType.manrope(17, FontWeight.w700)
                      .copyWith(color: Neon.textHi)),
              const SizedBox(height: 18),
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: GridView.count(
                      crossAxisCount: 3,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        for (var i = 0; i < 9; i++)
                          Semantics(
                            button: true,
                            label: 'Square ${i + 1}: ${_b[i] ?? 'empty'}',
                            child: GestureDetector(
                              onTap: () => _tap(i),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(18),
                                  color: Colors.white.withValues(alpha: 0.06),
                                  border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.12)),
                                ),
                                alignment: Alignment.center,
                                child: _b[i] == null
                                    ? null
                                    : Text(_b[i]!,
                                        style: NeonType.manrope(
                                                46, FontWeight.w800)
                                            .copyWith(
                                          color: _b[i] == 'X'
                                              ? Neon.cyan
                                              : Neon.pink,
                                          shadows: [
                                            Shadow(
                                                color: (_b[i] == 'X'
                                                        ? Neon.cyan
                                                        : Neon.pink)
                                                    .withValues(alpha: 0.6),
                                                blurRadius: 16)
                                          ],
                                        )),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (w != null)
                FilledButton.icon(
                    onPressed: _reset,
                    icon: const Icon(Icons.replay_rounded),
                    label: const Text('New game')),
            ],
          ),
        ),
      ),
    );
  }
}
