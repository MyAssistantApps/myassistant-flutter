// Play my day starts at once (client, 2026-11-01: "too slow"): Home fetches
// the script ahead, the tap uses it instead of waiting for the server.
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:myassistant/features/briefing/brief_player.dart';
import 'package:myassistant/models/brief.dart';

class _Host extends BriefHost {
  int fetches = 0;
  @override
  Future<BriefScript?> fetch() async {
    fetches++;
    return BriefScript.fromJson({
      'script': 'Good morning. You have two things today.',
      'sentences': ['Good morning.', 'You have two things today.'],
    });
  }

  @override
  bool get talking => false;
  @override
  bool get answering => false;
  @override
  bool get userStarted => false;
  @override
  Future<void> leaveConversation() async {}
}

class _Silent implements BriefVoice, BriefAudio {
  @override
  Future<BriefClip?> make(String text) async => null;
  @override
  void cancel() {}
  @override
  Future<void> play(Uint8List pcm16, {required int sampleRate}) async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> drained() async {}
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('warming twice fetches once; the tap uses it without fetching again', () async {
    final host = _Host();
    final silent = _Silent();
    final p = BriefPlayer(voice: silent, audio: silent, host: host);
    await p.prewarm();
    await p.prewarm();
    expect(host.fetches, 1, reason: 'one fetch for both');
    await p.play();
    expect(host.fetches, 1, reason: 'the tap used the script fetched ahead');
    expect(p.script?.script, startsWith('Good morning'));
  });
}
