import 'package:dildostu/src/engine/day_plan_picker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const allPacks = [
    'morning',
    'greetings',
    'cafe',
    'restaurant',
    'evening',
  ];

  test('3 paket seçir', () {
    final picks = pickDayPlanPackIds(allPacks, DateTime(2026, 8, 7, 9));
    expect(picks.length, 3);
    expect(picks.toSet().length, 3);
  });

  test('səhər saatında morning prioritet', () {
    final picks = pickDayPlanPackIds(allPacks, DateTime(2026, 8, 7, 8));
    expect(picks.first, 'morning');
  });

  test('dateKey ISO format', () {
    expect(dayPlanDateKey(DateTime(2026, 8, 7)), '2026-08-07');
  });
}
