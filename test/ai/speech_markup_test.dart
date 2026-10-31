// Delivery marks never reach the screen or the voice (lib/ai/speech_markup.dart).
import 'package:flutter_test/flutter_test.dart';
import 'package:myassistant/ai/speech_markup.dart';

void main() {
  test('the documented form: tone kept aside, expressions spoken only', () {
    final r = SpeechMarkup.parse('<tone: warm and calm> Sure <sigh> I can help.');
    expect(r.tone, 'warm and calm');
    expect(r.display, 'Sure I can help.');
    expect(r.spoken, contains('<sigh>'));
    expect(r.spoken, isNot(contains('tone')));
  });

  test('HTML-style tone notes (seen on screen 2026-10-31)', () {
    final r = SpeechMarkup.parse('<tone>informative</tone> In Pune it is 27 degrees.');
    expect(r.tone, 'informative');
    expect(r.display, 'In Pune it is 27 degrees.');
    expect(r.spoken, 'In Pune it is 27 degrees.');
  });

  test('stray closing and unknown tags are neither shown nor spoken', () {
    final r = SpeechMarkup.parse('</tone><informative> Your shopping list is empty.');
    expect(r.display, 'Your shopping list is empty.');
    expect(r.spoken, 'Your shopping list is empty.');
  });

  test('streaming: a half-written tag is held back, then removed', () {
    expect(SpeechMarkup.stripPartial('Here it is </to'), 'Here it is');
    expect(SpeechMarkup.stripPartial('Here it is <inform'), 'Here it is');
    expect(SpeechMarkup.stripPartial('<tone>informative</tone> Here'), 'Here');
  });

  test('ordinary text with angle brackets is left alone', () {
    expect(SpeechMarkup.strip('x < 5 and y > 2'), 'x < 5 and y > 2');
    expect(SpeechMarkup.strip('love you <3'), 'love you <3');
    expect(SpeechMarkup.stripPartial('is 3 < 4'), 'is 3 < 4');
  });
}
