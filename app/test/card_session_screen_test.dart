import 'package:dildostu/src/data/review_repository.dart';
import 'package:dildostu/src/models/word.dart';
import 'package:dildostu/src/services/speaker.dart';
import 'package:dildostu/src/ui/accent_colors.dart';
import 'package:dildostu/src/ui/card_session_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeSpeaker implements Speaker {
  @override
  Future<void> speak(String text) async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
}

const _word = Word(
  word: 'coffee',
  translationAz: 'qəhvə',
  ipa: '/k/',
  example: 'A coffee.',
  exampleAz: 'Bir qəhvə.',
  level: 1,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('accent verilibsə AppBar fonu dəyişir', (tester) async {
    final reviews = await ReviewRepository.load();
    final accent = accentFor('cafe');
    await tester.pumpWidget(MaterialApp(
      home: CardSessionScreen(
        title: 'Kafedə',
        entries: [const SessionEntry(wordKey: 'cafe:coffee', word: _word)],
        speaker: FakeSpeaker(),
        reviewRepository: reviews,
        accent: accent,
      ),
    ));

    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar.backgroundColor, accent.tint);
  });

  testWidgets('accent verilməyibsə AppBar fonu dəyişmir', (tester) async {
    final reviews = await ReviewRepository.load();
    await tester.pumpWidget(MaterialApp(
      home: CardSessionScreen(
        title: 'Axşam təkrarı',
        entries: [const SessionEntry(wordKey: 'cafe:coffee', word: _word)],
        speaker: FakeSpeaker(),
        reviewRepository: reviews,
      ),
    ));

    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar.backgroundColor, isNull);
  });
}
