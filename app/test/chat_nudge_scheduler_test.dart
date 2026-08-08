import 'package:dildostu/src/engine/chat_nudge_scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final day = DateTime(2026, 8, 7);

  test('gündə 3 sabit vaxt: 08:00, 13:00, 22:00', () {
    final times = computeChatNudgeTimes(day);
    expect(times, hasLength(3));
    expect(times[0], DateTime(2026, 8, 7, 8, 0));
    expect(times[1], DateTime(2026, 8, 7, 13, 0));
    expect(times[2], DateTime(2026, 8, 7, 22, 0));
  });

  test('axşamdan sonra açılanda sabah slotları da planlanır', () {
    final now = DateTime(2026, 8, 7, 23, 0);
    final slots = computeUpcomingChatNudgeTimes(now);
    expect(slots, hasLength(3));
    expect(slots.first, DateTime(2026, 8, 8, 8, 0));
  });
}
