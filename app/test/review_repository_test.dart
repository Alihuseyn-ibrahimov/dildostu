import 'package:dildostu/src/data/review_repository.dart';
import 'package:dildostu/src/engine/review_engine.dart';
import 'package:dildostu/src/models/live_message.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime(2026, 7, 21, 10, 0);

  LiveMessage hintFor(String pack, String word) => LiveMessage(
        packId: pack,
        word: word,
        translationAz: 't-$word',
        ipa: '/w/',
        example: 'ex',
        exampleAz: 'nümunə',
        aiLine: 'line',
        level: 1,
        isLive: true,
      );

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

  test('recordExposure ilk baxışda step 1 verir', () async {
    final repo = await ReviewRepository.load();
    await repo.recordExposure('cafe:tea', now: now, hint: hintFor('cafe', 'tea'));

    expect(repo.stateFor('cafe:tea').step, 1);
    expect(repo.wordCount, 1);
    expect(repo.learningCount, 1);
    expect(repo.wordForKey('cafe:tea')?.translationAz, 't-tea');
  });

  test('recordExposure eyni sözü eyni sessiyada təkrar saymır (wordCount)', () async {
    final repo = await ReviewRepository.load();
    await repo.recordExposure('cafe:tea', now: now, hint: hintFor('cafe', 'tea'));
    await repo.recordExposure('cafe:tea', now: now, hint: hintFor('cafe', 'tea'));

    expect(repo.wordCount, 1);
  });

  test('bu gün review olunan sözləri izləyir (axşam quiz üçün)', () async {
    final repo = await ReviewRepository.load();
    await repo.recordReview('cafe:coffee', ReviewOutcome.known, now: now);
    await repo.recordReview('cafe:tea', ReviewOutcome.later, now: now);

    final reviewedToday = repo.reviewedOn(now);
    expect(reviewedToday, containsAll(['cafe:coffee', 'cafe:tea']));
  });

  test('exposure da bu günkü siyahıya düşür', () async {
    final repo = await ReviewRepository.load();
    await repo.recordExposure('cafe:water', now: now, hint: hintFor('cafe', 'water'));

    expect(repo.reviewedOn(now), contains('cafe:water'));
    expect(repo.todayCount(today: now), 1);
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

      expect(repo.masteredCount, 1);
      expect(repo.learningCount, 1);
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
      final day3 = DateTime(2026, 7, 20, 9, 0);
      await repo.recordReview('cafe:coffee', ReviewOutcome.known, now: day1);
      await repo.recordReview('cafe:tea', ReviewOutcome.known, now: day3);

      expect(repo.currentStreak(today: day3), 1);
    });

    test('heç review olmayıbsa streak 0-dır', () async {
      final repo = await ReviewRepository.load();
      expect(repo.currentStreak(today: now), 0);
    });

    test('packBreakdown paket üzrə qruplaşdırır', () async {
      final repo = await ReviewRepository.load();
      await repo.recordExposure('cafe:a', now: now, hint: hintFor('cafe', 'a'));
      await repo.recordExposure('hotel:b', now: now, hint: hintFor('hotel', 'b'));

      final breakdown = repo.packBreakdown();
      expect(breakdown.length, 2);
      expect(breakdown.firstWhere((p) => p.packId == 'cafe').touched, 1);
      expect(breakdown.firstWhere((p) => p.packId == 'hotel').touched, 1);
    });

    test('recentWords son görülənləri qaytarır', () async {
      final repo = await ReviewRepository.load();
      await repo.recordExposure('cafe:first', now: now, hint: hintFor('cafe', 'first'));
      await repo.recordExposure(
        'cafe:second',
        now: now.add(const Duration(minutes: 5)),
        hint: hintFor('cafe', 'second'),
      );

      final recent = repo.recentWords(limit: 2);
      expect(recent.first.word, 'second');
      expect(recent.last.word, 'first');
    });
  });
}
