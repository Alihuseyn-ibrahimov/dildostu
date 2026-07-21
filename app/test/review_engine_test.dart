import 'package:dildostu/src/engine/review_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 7, 21, 10, 0);

  group('yeni söz (heç review olunmayıb)', () {
    test('ilkin state 0-cı addımdadır və dərhal due-dur', () {
      final state = ReviewState.initial();
      expect(state.step, 0);
      expect(state.isDue(now), isTrue);
    });
  });

  group('"bilirəm" cavabı', () {
    test('addımı irəli aparır və dueDate-i uzaqlaşdırır', () {
      final state = ReviewState.initial();
      final next = state.apply(ReviewOutcome.known, now: now);
      expect(next.step, 1);
      expect(next.dueAt.isAfter(now), isTrue);
    });

    test('hər ardıcıl "bilirəm" intervalı artırır (SM-2 light)', () {
      var state = ReviewState.initial();
      final intervals = <Duration>[];
      var t = now;
      for (var i = 0; i < 4; i++) {
        final next = state.apply(ReviewOutcome.known, now: t);
        intervals.add(next.dueAt.difference(t));
        state = next;
        t = next.dueAt;
      }
      // hər interval əvvəlkindən böyük olmalıdır (artan aralıq)
      for (var i = 1; i < intervals.length; i++) {
        expect(intervals[i], greaterThan(intervals[i - 1]));
      }
    });

    test('maksimum addımdan sonra interval sabit qalır (sonsuz böyümür)', () {
      var state = ReviewState.initial();
      var t = now;
      for (var i = 0; i < 20; i++) {
        state = state.apply(ReviewOutcome.known, now: t);
        t = state.dueAt;
      }
      expect(state.step, lessThanOrEqualTo(ReviewState.maxStep));
    });
  });

  group('"sonra" cavabı', () {
    test('addımı sıfırlayır', () {
      final learned = ReviewState.initial().apply(ReviewOutcome.known, now: now);
      final reset = learned.apply(ReviewOutcome.later, now: now);
      expect(reset.step, 0);
    });

    test('dueAt-i çox yaxın vaxta təyin edir (tezliklə yenidən göstər)', () {
      final state = ReviewState.initial().apply(ReviewOutcome.later, now: now);
      expect(state.dueAt.difference(now), lessThan(const Duration(hours: 1)));
    });
  });

  group('isDue', () {
    test('dueAt keçməyibsə false qaytarır', () {
      final state = ReviewState.initial().apply(ReviewOutcome.known, now: now);
      expect(state.isDue(now), isFalse);
    });

    test('dueAt keçibsə true qaytarır', () {
      final state = ReviewState.initial().apply(ReviewOutcome.known, now: now);
      expect(state.isDue(state.dueAt.add(const Duration(minutes: 1))), isTrue);
    });
  });

  group('serialization', () {
    test('toJson/fromJson round-trip', () {
      final state = ReviewState.initial().apply(ReviewOutcome.known, now: now);
      final restored = ReviewState.fromJson(state.toJson());
      expect(restored.step, state.step);
      expect(restored.dueAt, state.dueAt);
    });
  });
}
