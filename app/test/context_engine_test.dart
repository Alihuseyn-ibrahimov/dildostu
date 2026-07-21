import 'package:dildostu/src/engine/context_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 7, 21, 14, 0);

  test('manual siqnal həmişə üstündür (məkan və vaxtdan asılı olmayaraq)', () {
    final result = resolveContextPack(
      now: now,
      timeBasedPackId: 'restaurant',
      manualSignal: const ManualSignal(packId: 'cafe'),
      locationSignal: LocationSignal(packId: 'airport', resolvedAt: now),
    );
    expect(result, 'cafe');
  });

  test('manual yoxdursa, təzə məkan siqnalı vaxt qaydasından üstündür', () {
    final result = resolveContextPack(
      now: now,
      timeBasedPackId: 'restaurant',
      manualSignal: null,
      locationSignal: LocationSignal(packId: 'airport', resolvedAt: now),
    );
    expect(result, 'airport');
  });

  test('məkan siqnalı köhnəlmişdirsə (30 dəqiqədən çox) nəzərə alınmır', () {
    final stale = now.subtract(const Duration(minutes: 31));
    final result = resolveContextPack(
      now: now,
      timeBasedPackId: 'restaurant',
      manualSignal: null,
      locationSignal: LocationSignal(packId: 'airport', resolvedAt: stale),
    );
    expect(result, 'restaurant');
  });

  test('məkan siqnalı düz 30 dəqiqədədirsə hələ təzədir (sərhəd daxili)', () {
    final boundary = now.subtract(const Duration(minutes: 30));
    final result = resolveContextPack(
      now: now,
      timeBasedPackId: 'restaurant',
      manualSignal: null,
      locationSignal: LocationSignal(packId: 'airport', resolvedAt: boundary),
    );
    expect(result, 'airport');
  });

  test('nə manual, nə məkan yoxdursa vaxt qaydasına düşür', () {
    final result = resolveContextPack(
      now: now,
      timeBasedPackId: 'restaurant',
      manualSignal: null,
      locationSignal: null,
    );
    expect(result, 'restaurant');
  });
}
