import 'package:dildostu/src/data/review_repository.dart';
import 'package:dildostu/src/engine/review_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime(2026, 7, 21, 10, 0);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('naməlum söz üçün initial state qaytarır', () async {
    final repo = await ReviewRepository.load();
    final state = repo.stateFor('cafe:coffee');
    expect(state.step, 0);
    expect(state.isDue(now), isTrue);
  });

  test('recordReview vəziyyəti yeniləyir və saxlayır', () async {
    final repo = await ReviewRepository.load();
    await repo.recordReview('cafe:coffee', ReviewOutcome.known, now: now);

    final reloaded = await ReviewRepository.load();
    final state = reloaded.stateFor('cafe:coffee');
    expect(state.step, 1);
    expect(state.isDue(now), isFalse);
  });

  test('bu gün review olunan sözləri izləyir (axşam quiz üçün)', () async {
    final repo = await ReviewRepository.load();
    await repo.recordReview('cafe:coffee', ReviewOutcome.known, now: now);
    await repo.recordReview('cafe:tea', ReviewOutcome.later, now: now);

    final reviewedToday = repo.reviewedOn(now);
    expect(reviewedToday, containsAll(['cafe:coffee', 'cafe:tea']));
  });

  test('fərqli gündə review olunanlar bugünkü siyahıya düşmür', () async {
    final repo = await ReviewRepository.load();
    final yesterday = now.subtract(const Duration(days: 1));
    await repo.recordReview('cafe:coffee', ReviewOutcome.known, now: yesterday);

    expect(repo.reviewedOn(now), isEmpty);
    expect(repo.reviewedOn(yesterday), contains('cafe:coffee'));
  });

  group('statistika', () {
    test('toxunulan söz sayı (wordCount)', () async {
      final repo = await ReviewRepository.load();
      await repo.recordReview('cafe:coffee', ReviewOutcome.known, now: now);
      await repo.recordReview('cafe:tea', ReviewOutcome.known, now: now);
      expect(repo.wordCount, 2);
    });

    test('mənimsənilmiş söz sayı (step >= 3)', () async {
      final repo = await ReviewRepository.load();
      var t = now;
      for (var i = 0; i < 3; i++) {
        await repo.recordReview('cafe:coffee', ReviewOutcome.known, now: t);
        t = repo.stateFor('cafe:coffee').dueAt;
      }
      await repo.recordReview('cafe:tea', ReviewOutcome.known, now: now);

      expect(repo.masteredCount, 1); // yalnız coffee 3 addıma çatıb
    });

    test('ardıcıl gün streak-i hesablanır', () async {
      final repo = await ReviewRepository.load();
      final day1 = DateTime(2026, 7, 19, 9, 0);
      final day2 = DateTime(2026, 7, 20, 9, 0);
      final day3 = DateTime(2026, 7, 21, 9, 0);
      await repo.recordReview('cafe:coffee', ReviewOutcome.known, now: day1);
      await repo.recordReview('cafe:coffee', ReviewOutcome.known, now: day2);
      await repo.recordReview('cafe:coffee', ReviewOutcome.known, now: day3);

      expect(repo.currentStreak(today: day3), 3);
    });

    test('bir gün buraxılarsa streak kəsilir', () async {
      final repo = await ReviewRepository.load();
      final day1 = DateTime(2026, 7, 18, 9, 0);
      final day3 = DateTime(2026, 7, 20, 9, 0); // day2 buraxılıb
      await repo.recordReview('cafe:coffee', ReviewOutcome.known, now: day1);
      await repo.recordReview('cafe:tea', ReviewOutcome.known, now: day3);

      expect(repo.currentStreak(today: day3), 1);
    });

    test('heç review olmayıbsa streak 0-dır', () async {
      final repo = await ReviewRepository.load();
      expect(repo.currentStreak(today: now), 0);
    });
  });
}
