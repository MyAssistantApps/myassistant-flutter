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

  final _frames = ListQueue<(List<int>, int)>();
  int _ms = 0;

  void add(List<int> chunk, int ms) {
    _frames.add((List<int>.from(chunk), ms));
    _ms += ms;
    while (_frames.length > 1 && _ms - _frames.first.$2 >= keepMs) {
      _ms -= _frames.removeFirst().$2;
    }
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
