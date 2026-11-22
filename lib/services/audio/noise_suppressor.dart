import 'dart:math' as math;
import 'dart:typed_data';

/// ─────────────────────────────────────────────────────────────────────────
///  BACKGROUND NOISE OUT, HIS WORDS IN — a software noise suppressor for
///  PCM16 mono 16 kHz, run on every microphone frame before it reaches the
///  model (Live) or the transcriber (record mode).
///
///  The phone's own suppressor (RecordConfig.noiseSuppress) is weak or
///  absent on many Android phones, so this one does not rely on it:
///
///  1. STFT: 32 ms windows (512 samples), every 16 ms, sqrt-Hann in and
///     out, so an untouched signal comes back sample for sample.
///  2. THE ROOM'S NOISE, per frequency, learnt continuously (MCRA: the
///     minimum of the smoothed power over ~1.5 s is the noise; a bin far
///     above it holds speech and leaves the estimate alone). A fan, an AC,
///     traffic hum or hiss is learnt within a second or two, and a room
///     that changes is followed.
///  3. A WIENER GAIN per bin from the a-priori SNR (Ephraim–Malah's
///     decision-directed estimate): bins where his voice is stronger than
///     the room pass at full level, bins that are only room are turned
///     down to [floorGain] — never to zero, which sounds robotic and makes
///     speech recognisers worse ("musical noise").
///  4. Rumble under 80 Hz (handling, wind, traffic) is always cut.
///
///  What it does NOT remove: another person talking or a TV's dialogue at
///  the same loudness as him — that is speech too. The TV gate in
///  live_voice.dart and the "say that again" path handle those.
///
///  Latency: one hop (16 ms). Cost: one 512-point FFT pair per 16 ms.
/// ─────────────────────────────────────────────────────────────────────────
class NoiseSuppressor {
  NoiseSuppressor({this.floorGain = 0.12, this.highPassHz = 80});

  static const sampleRate = 16000;
  static const frame = 512;
  static const hop = frame ~/ 2;
  static const bins = frame ~/ 2 + 1;

  /// The least a bin is turned down to (0.12 ≈ −18 dB).
  final double floorGain;

  /// Everything below this is rumble, never speech.
  final double highPassHz;

  // Smoothing constants (per 16 ms frame).
  static const _alphaS = 0.8; // power smoothing for the minimum search
  static const _alphaD = 0.95; // noise update while no speech
  static const _alphaP = 0.2; // speech-presence smoothing
  static const _alphaDD = 0.98; // decision-directed a-priori SNR
  static const _delta = 5.0; // S/Smin above this: speech in the bin
  // The minimum is searched over [_subWindows] pieces of [_subFrames]
  // frames (4 × 24 ≈ 1.5 s): a room that gets louder is followed within
  // ~0.4-1.5 s, not up to 3 s.
  static const _subFrames = 24;
  static const _subWindows = 4;
  static const _bias = 1.5; // the minimum underestimates the mean
  static const _qLow = 1.8; // S/Smin at or under this: surely only room

  static final Float64List _window = () {
    final w = Float64List(frame);
    for (var i = 0; i < frame; i++) {
      // Periodic Hann, square-rooted: analysis × synthesis = Hann, which
      // sums to exactly 1 at a 50 % hop.
      w[i] = math.sqrt(0.5 - 0.5 * math.cos(2 * math.pi * i / frame));
    }
    return w;
  }();

  final _in = Float64List(frame); // the last [frame] input samples
  final _overlap = Float64List(hop); // the synthesis tail
  final _pending = <double>[]; // input not yet a full hop

  final _re = Float64List(frame);
  final _im = Float64List(frame);

  final _noise = Float64List(bins);
  final _smooth = Float64List(bins);
  final _min = Float64List(bins);
  final _tmpMin = Float64List(bins);
  final _subMins = List.generate(_subWindows, (_) => Float64List(bins));
  int _subAt = 0;
  final _presence = Float64List(bins);
  final _prevGain2Snr = Float64List(bins); // G² · γ of the last frame
  final _speechProb = Float64List(bins);
  int _frames = 0;

  /// The room is learnt from scratch (a new conversation, a new place).
  void reset() {
    _in.fillRange(0, frame, 0);
    _overlap.fillRange(0, hop, 0);
    _pending.clear();
    _noise.fillRange(0, bins, 0);
    _smooth.fillRange(0, bins, 0);
    _min.fillRange(0, bins, 0);
    _tmpMin.fillRange(0, bins, 0);
    for (final m in _subMins) {
      m.fillRange(0, bins, 0);
    }
    _subAt = 0;
    _presence.fillRange(0, bins, 0);
    _prevGain2Snr.fillRange(0, bins, 0);
    _speechProb.fillRange(0, bins, 0);
    _frames = 0;
  }

  /// Cleans one chunk of PCM16 little-endian. The output is whole hops
  /// (multiples of 512 bytes) delayed by one hop; over a stream its length
  /// matches the input's. May be empty for a chunk shorter than a hop.
  Uint8List process(Uint8List pcm16) {
    final view = ByteData.sublistView(pcm16);
    final n = pcm16.length ~/ 2;
    for (var i = 0; i < n; i++) {
      _pending.add(view.getInt16(i * 2, Endian.little) / 32768.0);
    }
    final hops = _pending.length ~/ hop;
    if (hops == 0) return Uint8List(0);
    final out = Uint8List(hops * hop * 2);
    final ov = ByteData.sublistView(out);
    var o = 0;
    for (var h = 0; h < hops; h++) {
      // Slide the window by one hop.
      _in.setRange(0, hop, _in, hop);
      for (var i = 0; i < hop; i++) {
        _in[hop + i] = _pending[h * hop + i];
      }
      final y = _processFrame();
      for (var i = 0; i < hop; i++) {
        final s = (y[i] * 32768.0).round().clamp(-32768, 32767);
        ov.setInt16(o, s, Endian.little);
        o += 2;
      }
    }
    _pending.removeRange(0, hops * hop);
    return out;
  }

  /// A whole recording at once (record mode): same filter, the one-hop
  /// delay removed, the same length back.
  Uint8List processAll(Uint8List pcm16) {
    reset();
    final padded = Uint8List(pcm16.length + hop * 2 * 2)..setAll(0, pcm16);
    final y = process(padded);
    const start = hop * 2;
    final end = math.min(start + pcm16.length, y.length);
    return Uint8List.fromList(y.sublist(start, end));
  }

  /// One 512-sample window → the next [hop] output samples.
  Float64List _processFrame() {
    for (var i = 0; i < frame; i++) {
      _re[i] = _in[i] * _window[i];
      _im[i] = 0;
    }
    _fft(_re, _im, false);

    // The very first window is half the silence before the microphone
    // opened: it would teach a room far quieter than this one. It passes
    // untouched and teaches nothing; the next one starts the learning.
    if (_frames == 0) {
      _frames++;
      return _synthesize();
    }
    final first = _frames == 1;
    final cut = (highPassHz * frame / sampleRate).ceil();
    for (var k = 0; k < bins; k++) {
      final p = _re[k] * _re[k] + _im[k] * _im[k];
      if (first) {
        _noise[k] = p;
        _smooth[k] = p;
        _min[k] = p;
        _tmpMin[k] = p;
        for (final m in _subMins) {
          m[k] = p;
        }
      }
      // 2. MCRA noise tracking.
      _smooth[k] = _alphaS * _smooth[k] + (1 - _alphaS) * p;
      _min[k] = math.min(_min[k], _smooth[k]);
      _tmpMin[k] = math.min(_tmpMin[k], _smooth[k]);
      final ratio = _smooth[k] / (_min[k] + 1e-12);
      final speech = ratio > _delta ? 1.0 : 0.0;
      _presence[k] = _alphaP * _presence[k] + (1 - _alphaP) * speech;
      final a = _alphaD + (1 - _alphaD) * _presence[k];
      _noise[k] = a * _noise[k] + (1 - a) * p;
      // Never below what the minimum says the room is, and never far
      // above it: someone who starts talking the moment the microphone
      // opens seeds the estimate with his own voice, and the quiet between
      // his words pulls it back down to the room.
      final floor = _bias * _min[k];
      if (_noise[k] < floor) _noise[k] = floor;
      final ceiling = _delta * _min[k];
      if (_noise[k] > ceiling) _noise[k] = ceiling;

      // 3. Wiener gain from the decision-directed a-priori SNR.
      final lambda = _noise[k] + 1e-12;
      final gamma = p / lambda; // a-posteriori SNR
      final xi = first
          ? math.max(gamma - 1, 0.0)
          : _alphaDD * _prevGain2Snr[k] + (1 - _alphaDD) * math.max(gamma - 1, 0.0);
      var g = xi / (1 + xi);
      if (g < floorGain) g = floorGain;
      _prevGain2Snr[k] = g * g * gamma;
      // How sure this bin holds his voice (soft, 0..1): a bin that is only
      // room goes all the way to the floor, so what is left of the noise
      // is quiet and even instead of a hiss that pops in and out.
      final q = ((ratio - _qLow) / (_delta - _qLow)).clamp(0.0, 1.0);
      // Opens at once (the first consonant of a word is never clipped),
      // lets go over a few frames (nor is its tail).
      _speechProb[k] =
          q > _speechProb[k] ? q : 0.6 * _speechProb[k] + 0.4 * q;
      final sp = _speechProb[k];
      g = (math.pow(g, sp) * math.pow(floorGain, 1 - sp)).toDouble();
      if (k < cut) g = floorGain * 0.25; // 4. rumble

      _re[k] *= g;
      _im[k] *= g;
      // Mirror for a real output.
      if (k > 0 && k < frame ~/ 2) {
        _re[frame - k] = _re[k];
        _im[frame - k] = -_im[k];
      }
    }
    _frames++;
    if (_frames % _subFrames == 0) {
      // A piece of the search is done: it replaces the oldest, and the
      // room's minimum is the least of the last [_subWindows] pieces.
      final done = _subMins[_subAt];
      _subAt = (_subAt + 1) % _subWindows;
      for (var k = 0; k < bins; k++) {
        done[k] = _tmpMin[k];
        var m = _smooth[k];
        for (final w in _subMins) {
          if (w[k] < m) m = w[k];
        }
        _min[k] = m;
        _tmpMin[k] = _smooth[k];
      }
    }
    return _synthesize();
  }

  /// The spectrum in [_re]/[_im] back to time, overlap-added: the next
  /// [hop] output samples.
  Float64List _synthesize() {
    _fft(_re, _im, true);
    final y = Float64List(hop);
    for (var i = 0; i < hop; i++) {
      y[i] = _overlap[i] + _re[i] * _window[i];
      _overlap[i] = _re[hop + i] * _window[hop + i];
    }
    return y;
  }

  /// In-place radix-2 FFT; [inverse] also divides by n.
  static void _fft(Float64List re, Float64List im, bool inverse) {
    final n = re.length;
    for (var i = 1, j = 0; i < n; i++) {
      var bit = n >> 1;
      for (; (j & bit) != 0; bit >>= 1) {
        j ^= bit;
      }
      j ^= bit;
      if (i < j) {
        final tr = re[i];
        re[i] = re[j];
        re[j] = tr;
        final ti = im[i];
        im[i] = im[j];
        im[j] = ti;
      }
    }
    for (var len = 2; len <= n; len <<= 1) {
      final ang = 2 * math.pi / len * (inverse ? 1 : -1);
      final wr = math.cos(ang), wi = math.sin(ang);
      for (var i = 0; i < n; i += len) {
        var cr = 1.0, ci = 0.0;
        for (var j = 0; j < len ~/ 2; j++) {
          final ar = re[i + j + len ~/ 2] * cr - im[i + j + len ~/ 2] * ci;
          final ai = re[i + j + len ~/ 2] * ci + im[i + j + len ~/ 2] * cr;
          re[i + j + len ~/ 2] = re[i + j] - ar;
          im[i + j + len ~/ 2] = im[i + j] - ai;
          re[i + j] += ar;
          im[i + j] += ai;
          final nr = cr * wr - ci * wi;
          ci = cr * wi + ci * wr;
          cr = nr;
        }
      }
    }
    if (inverse) {
      for (var i = 0; i < n; i++) {
        re[i] /= n;
        im[i] /= n;
      }
    }
  }

  /// A WAV recording (PCM16 mono) cleaned; anything else comes back as is.
  static Uint8List cleanWav(Uint8List wav, {NoiseSuppressor? suppressor}) {
    if (wav.length < 44) return wav;
    final b = ByteData.sublistView(wav);
    String tag(int at) => String.fromCharCodes(wav.sublist(at, at + 4));
    if (tag(0) != 'RIFF' || tag(8) != 'WAVE') return wav;
    var at = 12;
    int? channels, bits, rate;
    while (at + 8 <= wav.length) {
      final id = tag(at);
      final size = b.getUint32(at + 4, Endian.little);
      final body = at + 8;
      if (id == 'fmt ' && body + 16 <= wav.length) {
        channels = b.getUint16(body + 2, Endian.little);
        rate = b.getUint32(body + 4, Endian.little);
        bits = b.getUint16(body + 14, Endian.little);
      } else if (id == 'data') {
        if (channels != 1 || bits != 16 || rate != sampleRate) return wav;
        final end = math.min(body + size, wav.length) & ~1;
        final clean = (suppressor ?? NoiseSuppressor())
            .processAll(Uint8List.sublistView(wav, body, end));
        final out = Uint8List.fromList(wav);
        out.setRange(body, body + clean.length, clean);
        return out;
      }
      at = body + size + (size & 1);
    }
    return wav;
  }
}
