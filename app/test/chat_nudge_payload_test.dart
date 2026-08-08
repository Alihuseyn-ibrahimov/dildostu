import 'package:dildostu/src/engine/chat_nudge_payload.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('encode/decode roundtrip', () {
    const prompt = 'Aeroportda check-in necə deyilir?';
    final payload = encodeChatNudgePayload(prompt);
    expect(isChatNudgePayload(payload), isTrue);
    expect(decodeChatNudgePrompt(payload), prompt);
  });

  test('pack payload chat deyil', () {
    expect(isChatNudgePayload('cafe'), isFalse);
    expect(decodeChatNudgePrompt('cafe'), isNull);
  });
}
