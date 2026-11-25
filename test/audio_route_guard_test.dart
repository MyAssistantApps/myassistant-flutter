// OTHER APPS' AUDIO STAYS AS IT WAS (issue #6, 2026-11-25). Opening the app
// lowered the volume of music playing in other apps: the global audio
// context switched the phone's speakerphone on at every start, and the
// recorded opening left the phone in call mode after the conversation.
// These checks keep both from coming back.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _code(String path) => File(path)
    .readAsStringSync()
    .replaceAll('\r', '')
    .split('\n')
    .map((l) => l.replaceFirst(RegExp(r'//.*$'), ''))
    .join('\n');

void main() {
  const kotlin = 'android/app/src/main/kotlin/com/myassistant/myassistant';

  test('no Dart code switches the phone speakerphone on', () {
    final hits = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      if (RegExp(r'isSpeakerphoneOn:\s*true').hasMatch(_code(f.path))) {
        hits.add(f.path);
      }
    }
    expect(hits, isEmpty,
        reason: 'An audio context with speakerphone on re-routes every app on '
            'the phone the moment it is applied (issue #6).');
  });

  test('the recorded opening hands the phone its audio mode back', () {
    final clip = _code('$kotlin/VoiceClip.kt');
    expect(clip, contains('fun releaseRoute('));
    expect(clip, contains('modeBefore'));
    expect(clip, contains('clearCommunicationDevice()'));

    final activity = _code('$kotlin/MainActivity.kt');
    // Released when the conversation gives back the focus, and when the
    // screen closes for good.
    expect(RegExp(r'VoiceClip\.releaseRoute\(').allMatches(activity).length,
        greaterThanOrEqualTo(2));
    expect(activity, contains('override fun onDestroy()'));
  });
}
