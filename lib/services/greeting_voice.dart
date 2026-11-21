import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart' show MethodChannel;
import 'package:path_provider/path_provider.dart';

import '../ai/config.dart';
import '../ai/live_voice.dart' show LiveVoicePrefs;
import '../ai/speech.dart' show AudioSink;
import '../core/log.dart';
import 'api_service.dart';
import 'audio/pcm_player.dart';

/// THE GREETING IN THE ASSISTANT'S OWN VOICE.
///
/// His call, 2026-09-20: "I want the agent's own voice… let the API say
/// it, or record the same voice instead of playing some low quality
/// audio." So the backend SYNTHESISES IT ONCE in the live voice the
/// assistant talks in (GET /ai/voices/:voice/greeting-v6), it is cached on
/// disk, and played through the app's PCM player on every later tap: one
/// fetch per voice, instant and identical after that. No model writes it —
/// the words are fixed.
///
/// IT NEVER FALLS BACK TO THE DEVICE VOICE. A greeting that sounds wrong
/// is what he asked to remove, so an uncached greeting is simply silent
/// (the listening chime still marks the moment) and warms itself for next
/// time.
class GreetingVoice {
  GreetingVoice({
    AudioSink? sink,
    AiConfig Function()? config,
    Future<Directory> Function()? directory,
  })  : _sinkOverride = sink,
        _config = config ?? (() => AiConfigStore.instance.current),
        _directory = directory ?? getApplicationSupportDirectory;

  static final GreetingVoice instance = GreetingVoice();

  final AudioSink? _sinkOverride;
  final AiConfig Function() _config;
  final Future<Directory> Function() _directory;
  final Set<String> _prewarming = {};

  AudioSink get _sink => _sinkOverride ?? PcmPlayer.instance;

  static const _magic = [0x50, 0x43, 0x4D, 0x31]; // "PCM1", then the rate

  /// THE VOICE SHE TALKS IN: the one picked in Settings (or the server's
  /// default) for the OpenAI Realtime voice. The greeting is made once per
  /// voice by the backend and cached on each phone. It was fixed to
  /// "marin" before, so the hello never matched a pick.
  String _liveVoice() => LiveVoicePrefs.voiceFor(_config().live);

  /// One file per wording AND voice: a new voice is a new greeting.
  Future<File> _fileFor(String text) async {
    final live = _liveVoice();
    // The 'gptlive' prefix is a historical name kept so cached greetings
    // stay valid. v6: the faster hello (2026-11-04).
    final key = sha1
        .convert(utf8.encode('gptlive-v6|$live|$text'))
        .toString()
        .substring(0, 16);
    return File('${(await _directory()).path}/greet_$key.pcm');
  }

  /// Synthesise and cache, if it is not already there. Safe to call often.
  Future<void> prewarm(String text) async {
    final line = text.trim();
    if (line.isEmpty || !_prewarming.add(line)) return;
    try {
      final f = await _fileFor(line);
      // A truncated or empty file is worse than none — make it again.
      if (await f.exists() && await f.length() > 2000) return;
      final live = _liveVoice();
      final wav = await ApiService.getBytes(
          '/ai/voices/$live/greeting-v6?line=${Uri.encodeQueryComponent(line)}');
      if (wav == null ||
          wav.length < 2044 ||
          utf8.decode(wav.sublist(0, 4), allowMalformed: true) != 'RIFF') {
        return;
      }
      final rate =
          ByteData.sublistView(wav, 24, 28).getUint32(0, Endian.little);
      final head = ByteData(8);
      for (var i = 0; i < 4; i++) {
        head.setUint8(i, _magic[i]);
      }
      head.setUint32(4, rate, Endian.little);
      await f.writeAsBytes([...head.buffer.asUint8List(), ...wav.sublist(44)],
          flush: true);
      AppLog.add('greeting', 'cached "$line" in the live voice $live');
    } catch (e) {
      AppLog.add('greeting', 'prewarm failed: $e');
    } finally {
      _prewarming.remove(line);
    }
  }

  /// Plays the cached greeting. False when nothing was cached — the caller
  /// stays silent rather than using another voice.
  Future<bool> play(String text) async {
    if (text.trim().isEmpty) return false;
    try {
      final f = await _fileFor(text);
      if (!await f.exists() || await f.length() < 2000) {
        unawaited(prewarm(text)); // ready for the next tap
        return false;
      }
      final bytes = await f.readAsBytes();
      final ok = bytes.length > 8 &&
          [for (var i = 0; i < 4; i++) bytes[i]].join() == _magic.join();
      if (!ok) return false;
      final rate =
          ByteData.sublistView(bytes, 4, 8).getUint32(0, Endian.little);
      await _sink.play(Uint8List.sublistView(bytes, 8), sampleRate: rate);
      return true;
    } catch (e) {
      AppLog.add('greeting', 'play failed: $e');
      return false;
    }
  }

  static const _device = MethodChannel('hari/device');

  /// Stops a recorded opening that is still playing.
  Future<void> stopOnCall() async {
    try {
      await _device.invokeMethod<bool>('stopVoiceClip');
    } catch (_) {}
  }

  /// Drop every cached greeting — called when the user picks a different
  /// voice, so the next tap is greeted in the voice they just chose.
  Future<void> clear() async {
    try {
      final dir = await _directory();
      for (final e in dir.listSync()) {
        final name = e.uri.pathSegments.isEmpty ? '' : e.uri.pathSegments.last;
        if (e is File &&
            name.startsWith('greet_') &&
            (name.endsWith('.pcm') || name.endsWith('.wav'))) {
          try {
            await e.delete();
          } catch (_) {/* best effort */}
        }
      }
      AppLog.add('greeting', 'cache cleared');
    } catch (_) {/* nothing cached is a fine outcome */}
  }
}
