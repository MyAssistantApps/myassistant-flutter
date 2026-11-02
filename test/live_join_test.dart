// Her words joined across two responses (review, 2026-11-01: "I'll
// check.Here are the headlines" ran together).
import 'package:flutter_test/flutter_test.dart';
import 'package:myassistant/ai/live_voice.dart';

void main() {
  String join(List<String> pieces) {
    var all = '';
    for (final p in pieces) {
      all += LiveVoice.joinPiece(all, p);
    }
    return all;
  }

  test('a new sentence after a finished one gets its space', () {
    expect(join(['One moment, I will check the key ones.', 'Sorry, search is down.']),
        'One moment, I will check the key ones. Sorry, search is down.');
    expect(join(['Done!', 'Anything else?']), 'Done! Anything else?');
  });
  test('words inside a sentence, numbers and initials are left alone', () {
    expect(join(['It costs 3.', '5 lakh']), 'It costs 3.5 lakh');
    expect(join(['Hel', 'lo there.']), 'Hello there.');
    expect(join(['the U.', 'S. election']), 'the U.S. election');
    expect(join(['Okay. ', 'Next']), 'Okay. Next');
  });
}
