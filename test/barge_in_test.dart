// Talking over her (owner, 2026-11-24: "when we start speaking, it should
// hold and listen"): the measured check that tells the owner's voice from
// her own, coming back out of the phone's speaker.
import 'package:flutter_test/flutter_test.dart';
import 'package:myassistant/ai/live_voice.dart';
import 'package:myassistant/services/audio/barge_in.dart';
import 'package:myassistant/services/audio/mic_preroll.dart';
import 'package:myassistant/services/audio/mic_stream.dart';

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

  group('his words from their start (2026-11-24: "it only takes the last word")', () {
    test('the buffer gives back the frames from where his speech began', () {
      final r = MicPreRoll(keepMs: 3000);
      for (var i = 0; i < 20; i++) {
        r.add([i], 20); // her echo only: frames 0..19
      }
      for (var i = 20; i < 40; i++) {
        r.add([i], 20, voiced: true); // his first words: 20..39
      }
      for (var i = 40; i < 45; i++) {
        r.add([i], 20); // a short pause between words (100 ms)
      }
      for (var i = 45; i < 60; i++) {
        r.add([i], 20, voiced: true); // more of his words
      }
      final out = r.drainFromSpeech(leadMs: 100, gapMs: 300);
      // From 100 ms before his first voiced frame (20) to the last.
      expect(out.first.single, 15);
      expect(out.last.single, 59);
      expect(out.length, 45);
      expect(r.drain(), isEmpty, reason: 'drained');
    });

    test('a long silence starts a new stretch; nothing voiced gives everything', () {
      final r = MicPreRoll(keepMs: 3000);
      for (var i = 0; i < 10; i++) {
        r.add([i], 20, voiced: true); // an earlier sound
      }
      for (var i = 10; i < 40; i++) {
        r.add([i], 20); // 600 ms quiet
      }
      for (var i = 40; i < 50; i++) {
        r.add([i], 20, voiced: true);
      }
      expect(r.drainFromSpeech(leadMs: 0, gapMs: 300).first.single, 40);
      final q = MicPreRoll(keepMs: 3000);
      for (var i = 0; i < 5; i++) {
        q.add([i], 20);
      }
      expect(q.drainFromSpeech().length, 5);
    });

    test('talking over her keeps all of what he said, not only the last moment', () {
      final over = OwnerOverHer(BargeInDetector());
      var frame = 0;
      List<List<int>>? said;
      void feed(int ms, double mic, {double echo = 0.2}) {
        for (var t = 0; t < ms && said == null; t += 20) {
          said = over.feed([frame++], ms: 20, mic: mic, echo: echo, floor: floor, speechBar: speechBar);
        }
      }

      over.herTurnBegins();
      feed(1200, floor + 0.3 * 0.2); // her voice alone: learnt as echo (frames 0..59)
      expect(said, isNull);
      // He starts softly ("Wait,") — above her echo, not yet enough to stop her…
      final firstWord = frame;
      feed(400, 0.12);
      expect(said, isNull);
      // …then carries on louder, and that confirms it.
      feed(800, 0.4);
      expect(said, isNotNull, reason: 'he is talking over her');
      final frames = said!.map((f) => f.single).toList();
      expect(frames.first, lessThanOrEqualTo(firstWord), reason: 'his first word is kept');
      expect(frames.first, greaterThan(firstWord - 20), reason: 'not a second of her echo');
      expect(frames.last, frame - 1, reason: 'up to the frame that confirmed it');
    });

    test('his softer words over her are not learnt as her echo', () {
      final d = BargeInDetector();
      herVoice(d, 1200);
      final before = d.coupling;
      // A second of him speaking softly over her (not enough to stop her).
      for (var t = 0; t < 1000; t += frame) {
        d.feed(mic: 0.12, echo: 0.2, floor: floor, speechBar: speechBar, ms: frame);
      }
      expect(d.coupling, closeTo(before, 0.01), reason: 'the bar did not rise');
      // So when he speaks up, it still counts as quickly.
      expect(ownerOverHer(d, 500), isTrue);
    });

    test('once he has talked over her, his utterance carries on until he stops', () {
      final vad = VoiceActivityDetector(hangoverMs: 700);
      vad.continueSpeech();
      expect(vad.speaking, isTrue);
      final loud = List<int>.filled(640, 0); // 20 ms of 16 kHz mono
      expect(vad.feed(loud, 0.4), VadEvent.speech, reason: 'no new onset to wait for');
      VadEvent last = VadEvent.speech;
      for (var t = 0; t < 800; t += 20) {
        last = vad.feed(loud, 0.001);
        if (last == VadEvent.end) break;
      }
      expect(last, VadEvent.end, reason: 'his pause after speaking ends the turn');
    });
  });
}
