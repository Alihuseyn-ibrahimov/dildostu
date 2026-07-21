import 'package:dildostu/src/data/manual_context_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime(2026, 7, 21, 14, 0);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('heç nə saxlanmayıbsa null qaytarır', () async {
    final repo = await ManualContextRepository.load();
    expect(repo.currentSignal(now: now), isNull);
  });

  test('set etdikdən sonra siqnalı qaytarır', () async {
    final repo = await ManualContextRepository.load();
    await repo.set('cafe', now: now);
    expect(repo.currentSignal(now: now)?.packId, 'cafe');
  });

  test('2 saatdan sonra siqnal öz-özünə bitir', () async {
    final repo = await ManualContextRepository.load();
    await repo.set('cafe', now: now);
    final later = now.add(const Duration(hours: 2, minutes: 1));
    expect(repo.currentSignal(now: later), isNull);
  });

  test('yenidən yüklənəndə saxlanılan siqnal davam edir', () async {
    final repo = await ManualContextRepository.load();
    await repo.set('hotel', now: now);

    final reloaded = await ManualContextRepository.load();
    expect(reloaded.currentSignal(now: now)?.packId, 'hotel');
  });

  test('clear() siqnalı dərhal ləğv edir', () async {
    final repo = await ManualContextRepository.load();
    await repo.set('cafe', now: now);
    await repo.clear();
    expect(repo.currentSignal(now: now), isNull);
  });
}
