import 'package:dildostu/src/engine/time_context_rule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const packIds = [
    'morning',
    'greetings',
    'cafe',
    'restaurant',
    'market',
    'airport',
    'hotel',
    'transport',
    'pharmacy',
    'evening',
  ];

  test('günün ilk bildirişi morning paketini seçir', () {
    expect(pickPackForSlot(0, 7, packIds), 'morning');
  });

  test('günün son bildirişi evening paketini seçir', () {
    expect(pickPackForSlot(6, 7, packIds), 'evening');
  });

  test('ortadakı slotlar morning/evening xaricində fırlanır', () {
    final middlePacks =
        List.generate(5, (i) => pickPackForSlot(i + 1, 7, packIds));
    expect(middlePacks.every((p) => p != 'morning' && p != 'evening'), isTrue);
  });

  test('yalnız bir slot varsa morning seçir', () {
    expect(pickPackForSlot(0, 1, packIds), 'morning');
  });

  test('bilinməyən pack siyahısı ilə xəta atmır (boşdursa exception)', () {
    expect(() => pickPackForSlot(0, 5, const []), throwsArgumentError);
  });
}
