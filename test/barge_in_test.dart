// Talking over her (owner, 2026-11-24: "when we start speaking, it should
// hold and listen"): the measured check that tells the owner's voice from
// her own, coming back out of the phone's speaker.
import 'package:flutter_test/flutter_test.dart';
import 'package:myassistant/ai/live_voice.dart';
import 'package:myassistant/services/audio/barge_in.dart';

void main() {
  const floor = 0.01, speechBar = 0.03, frame = 20;

  /// [ms] of her voice alone: the microphone hears 30% of her (her echo).
  bool herVoice(BargeInDetector d, int ms, {double level = 0.2}) {
    var any = false;
    for (var t = 0; t < ms; t += frame) {
      any |= d.feed(mic: floor + 0.3 * level, echo: level, floor: floor, speechBar: speechBar, ms: frame);
    }
    return any;
  }

  /// [ms] of the owner talking over her, clearly louder than her echo.
  bool ownerOverHer(BargeInDetector d, int ms, {double level = 0.2}) {
    var any = false;
    for (var t = 0; t < ms; t += frame) {
      any |= d.feed(mic: 0.4, echo: level, floor: floor, speechBar: speechBar, ms: frame);
    }
    return any;
  }

  test('interruption by voice is on', () {
    expect(LiveVoice.autoBargeIn, isTrue);
  });

  test('her own voice coming back never counts as the owner', () {
    final d = BargeInDetector();
    expect(herVoice(d, 4000), isFalse);
    expect(d.warm, isTrue);
    expect(d.coupling, closeTo(0.3, 0.01), reason: 'the leak is learnt');
    // Louder passages of her own voice still do not count.
    expect(herVoice(d, 2000, level: 0.5), isFalse);
  });

  test('the owner talking over her stops her after a word, not a cough', () {
    final d = BargeInDetector();
    herVoice(d, 1000);
    // A cough or a clink: too short.
    expect(ownerOverHer(d, 120), isFalse);
    expect(herVoice(d, 200), isFalse);
    // Words: held long enough, it counts.
    expect(ownerOverHer(d, 500), isTrue);
  });

  test('before it knows this phone\'s echo, nothing counts', () {
    final d = BargeInDetector();
    expect(ownerOverHer(d, 1000), isFalse, reason: 'not warm yet');
  });
}
