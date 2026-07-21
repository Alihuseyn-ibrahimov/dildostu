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
}
