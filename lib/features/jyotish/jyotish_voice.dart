// JYOTISH VOICE (2026-11-22) — "Speak my future" and speaking birth details.
//
// Out: the phone's own text-to-speech (flutter_tts) with a language and
// voice picker, play / pause / stop and speed. In: speech_to_text through
// the app's recogniser port (lib/ai/listen.dart). English, Hindi and
// Kannada, as far as the phone has voices for them.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../ai/listen.dart';
import '../../core/log.dart';

/// The reading languages: code sent to the server → (label, speech locale).
const kReadingLanguages = {
  'en': ('English', 'en-IN'),
  'hi': ('हिन्दी', 'hi-IN'),
  'kn': ('ಕನ್ನಡ', 'kn-IN'),
};

enum SpeakState { idle, playing, paused }

class TtsVoice {
  const TtsVoice(this.name, this.locale);
  final String name;
  final String locale;
}

class JyotishSpeaker {
  JyotishSpeaker([FlutterTts? tts]) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;
  final state = ValueNotifier<SpeakState>(SpeakState.idle);
  bool _ready = false;

  /// 0.5 is the platform's normal pace on Android.
  double rate = 0.5;
  TtsVoice? voice;

  Future<void> _init() async {
    if (_ready) return;
    _ready = true;
    _tts.setStartHandler(() => state.value = SpeakState.playing);
    _tts.setCompletionHandler(() => state.value = SpeakState.idle);
    _tts.setCancelHandler(() => state.value = SpeakState.idle);
    _tts.setPauseHandler(() => state.value = SpeakState.paused);
    _tts.setContinueHandler(() => state.value = SpeakState.playing);
    _tts.setErrorHandler((m) {
      AppLog.add('jyotish', 'tts error: $m');
      state.value = SpeakState.idle;
    });
    await _tts.awaitSpeakCompletion(false);
  }

  /// Whether the phone can speak [locale] at all.
  Future<bool> hasLanguage(String locale) async {
    await _init();
    try {
      final ok = await _tts.isLanguageAvailable(locale);
      return ok == true || ok == 1;
    } catch (_) {
      return false;
    }
  }

  /// The phone's voices for a language ("hi-IN" matches "hi-IN" and "hi_IN").
  Future<List<TtsVoice>> voicesFor(String locale) async {
    await _init();
    try {
      final all = await _tts.getVoices;
      final lang = locale.split('-').first.toLowerCase();
      final out = <TtsVoice>[];
      if (all is List) {
        for (final v in all) {
          if (v is! Map) continue;
          final loc = '${v['locale'] ?? ''}'.replaceAll('_', '-');
          if (loc.toLowerCase().split('-').first == lang) {
            out.add(TtsVoice('${v['name'] ?? loc}', loc));
          }
        }
      }
      out.sort((a, b) => a.name.compareTo(b.name));
      return out;
    } catch (_) {
      return const [];
    }
  }

  Future<void> speak(String text, String locale) async {
    await _init();
    if (state.value == SpeakState.paused) {
      // flutter_tts on Android resumes from where it paused on the next speak.
      state.value = SpeakState.playing;
      await _tts.speak(_forSpeech(text));
      return;
    }
    await _tts.stop();
    await _tts.setLanguage(locale);
    final v = voice;
    if (v != null && v.locale.split('-').first == locale.split('-').first) {
      await _tts.setVoice({'name': v.name, 'locale': v.locale});
    }
    await _tts.setSpeechRate(rate);
    state.value = SpeakState.playing;
    await _tts.speak(_forSpeech(text));
  }

  Future<void> pause() async {
    await _tts.pause();
    state.value = SpeakState.paused;
  }

  Future<void> stop() async {
    await _tts.stop();
    state.value = SpeakState.idle;
  }

  Future<void> setRate(double r) async {
    rate = r;
    await _tts.setSpeechRate(r);
  }

  void dispose() {
    unawaited(_tts.stop());
    state.dispose();
  }

  /// Bullets and stray symbols read badly aloud.
  static String _forSpeech(String s) => s
      .replaceAll(RegExp(r'^\s*[-•*]\s*', multiLine: true), '')
      .replaceAll(RegExp(r'[*_#`]'), '')
      .trim();
}

/// Speaking birth details into the chat.
class JyotishListener {
  JyotishListener([RecognizerPort? r]) : _r = r ?? SpeechToTextRecognizer();

  final RecognizerPort _r;
  bool _ready = false;
  final listening = ValueNotifier<bool>(false);

  /// Listens once; [onWords] gets the words as they are heard, [isFinal]
  /// on the last. Returns false when the phone cannot listen.
  Future<bool> listen(String locale,
      void Function(String words, bool isFinal) onWords) async {
    if (!_ready) {
      _ready = await _r.initialize(
        onStatus: (s) {
          if (s == 'done' || s == 'notListening') listening.value = false;
        },
        onError: (e, _) {
          AppLog.add('jyotish', 'stt error: $e');
          listening.value = false;
        },
      );
      if (!_ready) return false;
    }
    final ids = await _r.localeIds();
    final want = locale.replaceAll('-', '_');
    String? id;
    for (final l in ids) {
      if (l.toLowerCase() == want.toLowerCase()) id = l;
    }
    id ??= ids.where((l) => l.toLowerCase().startsWith(want.split('_').first.toLowerCase())).firstOrNull;
    listening.value = true;
    await _r.listen(
      onResult: (w, fin) {
        onWords(w, fin);
        if (fin) listening.value = false;
      },
      localeId: id,
      onDevice: false,
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
    );
    return true;
  }

  Future<void> stop() async {
    await _r.stop();
    listening.value = false;
  }

  void dispose() {
    unawaited(_r.cancel());
    listening.dispose();
  }
}
