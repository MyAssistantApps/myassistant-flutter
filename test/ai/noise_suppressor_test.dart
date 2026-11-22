// The software noise suppressor: a steady room is turned down, a voice
// over it is kept, nothing is lost or added in length, and a clean signal
// is not mangled.
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:myassistant/services/audio/noise_suppressor.dart';

const _rate = NoiseSuppressor.sampleRate;

Uint8List _pcm(List<double> x) {
  final out = Uint8List(x.length * 2);
  final b = ByteData.sublistView(out);
  for (var i = 0; i < x.length; i++) {
    b.setInt16(i * 2, (x[i] * 32767).round().clamp(-32768, 32767), Endian.little);
  }
  return out;
}

List<double> _samples(Uint8List pcm) {
  final b = ByteData.sublistView(pcm);
  return [for (var i = 0; i + 1 < pcm.length; i += 2) b.getInt16(i, Endian.little) / 32768.0];
}

double _rms(List<double> x, int from, int to) {
  var s = 0.0;
  for (var i = from; i < to; i++) {
    s += x[i] * x[i];
  }
  return math.sqrt(s / (to - from));
}

double _db(double a, double b) => 20 * math.log(a / b) / math.ln10;

/// A voice-like sound: a 140 Hz buzz with harmonics up to 3.5 kHz, in
/// syllables (~4 a second) with short gaps between them, as speech has.
double _voice(int i) {
  final t = i / _rate;
  final env = math.pow(math.max(0.0, math.sin(2 * math.pi * 2 * t)), 0.5).toDouble();
  var v = 0.0;
  for (var h = 1; h * 140 < 3500; h++) {
    v += math.sin(2 * math.pi * 140 * h * t) / h;
  }
  return 0.25 * env * v;
}

void main() {
  final rnd = math.Random(7);
  double noise() => (rnd.nextDouble() * 2 - 1) * 0.08; // a steady fan / hiss

  test('steady noise alone is turned down by more than 12 dB', () {
    const n = _rate * 4;
    final x = [for (var i = 0; i < n; i++) noise()];
    final y = _samples(NoiseSuppressor().processAll(_pcm(x)));
    expect(y.length, x.length);
    // After the room is learnt (the first 1.5 s).
    final drop = _db(_rms(x, _rate * 2, n), _rms(y, _rate * 2, n));
    expect(drop, greaterThan(12));
  });

  test('a voice over the noise keeps its level and gains SNR', () {
    const n = _rate * 6;
    // 3 s of room, then 3 s of him talking over it.
    final v = [for (var i = 0; i < n; i++) i >= _rate * 3 ? _voice(i) : 0.0];
    final r = [for (var i = 0; i < n; i++) noise()];
    final x = [for (var i = 0; i < n; i++) v[i] + r[i]];
    final y = _samples(NoiseSuppressor().processAll(_pcm(x)));

    final roomIn = _rms(x, _rate * 2, _rate * 3);
    final roomOut = _rms(y, _rate * 2, _rate * 3);
    final talkIn = _rms(x, _rate * 4, n);
    final talkOut = _rms(y, _rate * 4, n);
    // His words: within 3 dB of what went in.
    expect(_db(talkIn, talkOut).abs(), lessThan(3));
    // Speech-to-room contrast: at least 10 dB better than the input's.
    final before = _db(talkIn, roomIn);
    final after = _db(talkOut, roomOut);
    expect(after - before, greaterThan(10));
  });

  test('streaming in odd-sized chunks gives the same length back', () {
    final s = NoiseSuppressor();
    final x = _pcm([for (var i = 0; i < _rate; i++) noise()]);
    var out = 0;
    for (var at = 0; at < x.length; at += 1282) {
      final end = math.min(at + 1282, x.length);
      out += s.process(Uint8List.sublistView(x, at, end)).length;
    }
    // Everything but the last partial hop has come out.
    expect(x.length - out, lessThan(NoiseSuppressor.hop * 2));
    expect(out % (NoiseSuppressor.hop * 2), 0);
  });

  test('a clean voice with no room is not mangled', () {
    const n = _rate * 3;
    final x = [for (var i = 0; i < n; i++) _voice(i)];
    final y = _samples(NoiseSuppressor().processAll(_pcm(x)));
    expect(_db(_rms(x, _rate, n), _rms(y, _rate, n)).abs(), lessThan(3));
  });

  test('a WAV is cleaned in place; anything else passes untouched', () {
    final pcm = _pcm([for (var i = 0; i < _rate * 3; i++) noise()]);
    final header = ByteData(44)
      ..setUint32(0, 0x46464952, Endian.little) // RIFF
      ..setUint32(4, 36 + pcm.length, Endian.little)
      ..setUint32(8, 0x45564157, Endian.little) // WAVE
      ..setUint32(12, 0x20746d66, Endian.little) // fmt
      ..setUint32(16, 16, Endian.little)
      ..setUint16(20, 1, Endian.little)
      ..setUint16(22, 1, Endian.little)
      ..setUint32(24, _rate, Endian.little)
      ..setUint32(28, _rate * 2, Endian.little)
      ..setUint16(32, 2, Endian.little)
      ..setUint16(34, 16, Endian.little)
      ..setUint32(36, 0x61746164, Endian.little) // data
      ..setUint32(40, pcm.length, Endian.little);
    final wav = Uint8List.fromList([...header.buffer.asUint8List(), ...pcm]);
    final clean = NoiseSuppressor.cleanWav(wav);
    expect(clean.length, wav.length);
    expect(clean.sublist(0, 44), wav.sublist(0, 44));
    final before = _rms(_samples(pcm), _rate * 2, _rate * 3);
    final after = _rms(_samples(clean.sublist(44)), _rate * 2, _rate * 3);
    expect(_db(before, after), greaterThan(12));

    final notWav = Uint8List.fromList(List.filled(100, 7));
    expect(identical(NoiseSuppressor.cleanWav(notWav), notWav), isTrue);
  });
}
