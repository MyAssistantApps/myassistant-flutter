import 'package:flutter_test/flutter_test.dart';
import 'package:myassistant/features/assistant/state/assistant_state.dart';
import 'package:myassistant/services/screen_awake.dart';

void main() {
  test('the screen stays on whenever the assistant is busy or talking', () {
    expect(ScreenAwake.assistantBusy(true, AssistantPhase.idle), isTrue);
    for (final p in [
      AssistantPhase.listening,
      AssistantPhase.thinking,
      AssistantPhase.searching,
      AssistantPhase.speaking,
      AssistantPhase.inCall,
    ]) {
      expect(ScreenAwake.assistantBusy(false, p), isTrue, reason: '$p');
    }
  });

  test('idle, done or failed lets the phone sleep as usual', () {
    for (final p in [
      AssistantPhase.idle,
      AssistantPhase.completed,
      AssistantPhase.error,
    ]) {
      expect(ScreenAwake.assistantBusy(false, p), isFalse, reason: '$p');
    }
  });
}
