// Guruji speaks in a natural male voice (owner, 2026-11-23: "I need a male
// voice for Jyotish, like a real one"): Cedar, in a guru's manner, in the
// fast voice and every spoken reply — and only while Guruji is talking.
import 'package:flutter_test/flutter_test.dart';
import 'package:myassistant/ai/assistant_role.dart';
import 'package:myassistant/ai/config.dart';
import 'package:myassistant/ai/live_voice.dart';
import 'package:myassistant/features/jyotish/jyotish_guru.dart';

void main() {
  tearDown(() {
    AssistantRole.current.value = null;
    LiveVoicePrefs.chosenVoice = null;
  });

  const live = AiLive(voice: 'marin', voices: ['marin', 'cedar', 'coral', 'ash']);

  test('Guruji is Cedar, whatever the owner picked for the everyday assistant', () {
    LiveVoicePrefs.chosenVoice = 'coral';
    expect(LiveVoicePrefs.voiceFor(live), 'coral');
    AssistantRole.current.value = guruRole;
    expect(LiveVoicePrefs.voiceFor(live), 'cedar');
    expect(AssistantRole.voiceOr('coral'), 'cedar');
    AssistantRole.current.value = null;
    expect(LiveVoicePrefs.voiceFor(live), 'coral', reason: 'the everyday voice comes back');
    expect(AssistantRole.voiceOr('coral'), 'coral');
  });

  test('a role voice the server does not offer falls back to the owner\'s', () {
    LiveVoicePrefs.chosenVoice = 'coral';
    AssistantRole.current.value = guruRole;
    expect(LiveVoicePrefs.voiceFor(const AiLive(voices: ['marin', 'coral'])), 'coral');
  });

  test('each sentence Guruji says carries his manner once', () {
    AssistantRole.current.value = guruRole;
    final t = AssistantRole.toned('Namaste. Today is a calm day for you.');
    expect(t, startsWith('<tone: deep, calm and unhurried'));
    expect(t, endsWith('Namaste. Today is a calm day for you.'));
    // the model's own marking wins
    expect(AssistantRole.toned('<tone: joyful> Wonderful news!'), '<tone: joyful> Wonderful news!');
    // within the server's 120-character limit for the note
    expect(guruRole.voiceStyle!.length, lessThanOrEqualTo(120));
    AssistantRole.current.value = null;
    expect(AssistantRole.toned('Hello.'), 'Hello.');
  });

  test('the fast voice is told how Guruji speaks', () {
    AssistantRole.current.value = guruRole;
    final system = AssistantRole.apply('BASE');
    expect(system, contains('Guruji'));
    expect(system, contains('Your voice: speak deep, calm and unhurried'));
  });
}
