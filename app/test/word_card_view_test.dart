import 'package:dildostu/src/models/word.dart';
import 'package:dildostu/src/services/speaker.dart';
import 'package:dildostu/src/ui/accent_colors.dart';
import 'package:dildostu/src/ui/word_card_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeSpeaker implements Speaker {
  final List<String> spoken = [];
  @override
  Future<void> speak(String text) async => spoken.add(text);
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
}

const _word = Word(
  word: 'receipt',
  translationAz: 'qəbz',
  ipa: '/rɪˈsiːt/',
  example: 'Could I have the receipt, please?',
  exampleAz: 'Qəbzi verə bilərsiniz?',
  level: 1,
);

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('sözü, IPA-nı, tərcüməni və nümunəni göstərir', (tester) async {
    await tester.pumpWidget(_host(
      WordCardView(word: _word, speaker: FakeSpeaker(), onReview: (_) {}),
    ));
    expect(find.text('receipt'), findsOneWidget);
    expect(find.text('/rɪˈsiːt/'), findsOneWidget);
    expect(find.text('qəbz'), findsOneWidget);
    expect(find.text('Could I have the receipt, please?'), findsOneWidget);
  });

  testWidgets('Səsləndir düyməsi speaker.speak-i sözlə çağırır', (tester) async {
    final speaker = FakeSpeaker();
    await tester.pumpWidget(_host(
      WordCardView(word: _word, speaker: speaker, onReview: (_) {}),
    ));
    await tester.tap(find.text('Səsləndir'));
    await tester.pump();
    expect(speaker.spoken, ['receipt']);
  });

  testWidgets('accent verilibsə Səsləndir düyməsi öz rənginə malikdir',
      (tester) async {
    final accent = accentFor('cafe');
    await tester.pumpWidget(_host(
      WordCardView(
        word: _word,
        speaker: FakeSpeaker(),
        onReview: (_) {},
        accent: accent,
      ),
    ));
    final button = tester.widget<FilledButton>(
      find.ancestor(
          of: find.text('Səsləndir'), matching: find.byType(FilledButton)),
    );
    expect(button.style?.backgroundColor?.resolve(<WidgetState>{}),
        accent.tint);
  });

  testWidgets('Bilirəm/Sonra düymələri düzgün nəticə verir', (tester) async {
    final outcomes = <ReviewOutcome>[];
    await tester.pumpWidget(_host(
      WordCardView(
        word: _word,
        speaker: FakeSpeaker(),
        onReview: outcomes.add,
      ),
    ));
    await tester.tap(find.text('✓ Bilirəm'));
    await tester.tap(find.text('↻ Sonra'));
    await tester.pump();
    expect(outcomes, [ReviewOutcome.known, ReviewOutcome.later]);
  });
}
