import 'dart:collection';

/// THE MOMENT BEFORE THE USER SPEAKS.
///
/// The real audio of the last few hundred milliseconds is kept here and
/// replayed the instant speech is confirmed: onset takes a moment to
/// confirm, and without this lead-in the first syllable of every sentence
/// would be clipped.
class MicPreRoll {
  MicPreRoll({this.keepMs = 450});

  /// How much lead-in to keep. Onset takes 200 ms to confirm, and the
  /// first consonant starts before the level crosses the bar.
  final int keepMs;

  final _frames = ListQueue<(List<int>, int, bool)>();
  int _ms = 0;

  /// [voiced]: the frame sounds like someone speaking (see [drainFromSpeech]).
  void add(List<int> chunk, int ms, {bool voiced = false}) {
    _frames.add((List<int>.from(chunk), ms, voiced));
    _ms += ms;
    while (_frames.length > 1 && _ms - _frames.first.$2 >= keepMs) {
      _ms -= _frames.removeFirst().$2;
    }
  }

  /// THE OWNER'S WORDS FROM THEIR START (2026-11-24, the owner: "it only
  /// takes the last word that I spoke"). The frames from where the latest
  /// stretch of voiced frames began — pauses up to [gapMs] between words
  /// bridged — with [leadMs] before it, so the first syllable's soft start
  /// is kept. Everything held when nothing was voiced. Then empty.
  List<List<int>> drainFromSpeech({int leadMs = 250, int gapMs = 350}) {
    final f = _frames.toList();
    var last = f.length - 1;
    while (last >= 0 && !f[last].$3) {
      last--;
    }
    if (last < 0) return drain();
    var start = last;
    var gap = 0;
    for (var i = last - 1; i >= 0; i--) {
      if (f[i].$3) {
        start = i;
        gap = 0;
      } else {
        gap += f[i].$2;
        if (gap > gapMs) break;
      }
    }
    var lead = 0;
    while (start > 0 && lead < leadMs) {
      start--;
      lead += f[start].$2;
    }
    final out = [for (final x in f.skip(start)) x.$1];
    clear();
    return out;
  }

  /// Everything held, oldest first, and empties the buffer.
  List<List<int>> drain() {
    final out = _frames.map((f) => f.$1).toList();
    clear();
    return out;
  }

  void clear() {
    _frames.clear();
    _ms = 0;
  }
}
