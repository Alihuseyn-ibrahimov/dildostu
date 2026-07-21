import 'package:dildostu/src/data/review_repository.dart';
import 'package:dildostu/src/engine/review_engine.dart';
import 'package:dildostu/src/ui/stats_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('sayları düzgün göstərir', (tester) async {
    final repo = await ReviewRepository.load();
    final now = DateTime(2026, 7, 21, 10, 0);
    await repo.recordReview('cafe:coffee', ReviewOutcome.known, now: now);
    await repo.recordReview('cafe:tea', ReviewOutcome.known, now: now);

    await tester.pumpWidget(MaterialApp(home: StatsScreen(reviewRepository: repo)));

    expect(find.text('2'), findsOneWidget); // Toxunulan söz
    expect(find.text('Toxunulan söz'), findsOneWidget);
    expect(find.text('Mənimsənilmiş söz'), findsOneWidget);
    expect(find.text('Ardıcıl gün'), findsOneWidget);
  });
}
