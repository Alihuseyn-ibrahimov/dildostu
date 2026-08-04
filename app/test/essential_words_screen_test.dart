import 'package:dildostu/src/models/live_message.dart';
import 'package:dildostu/src/ui/accent_colors.dart';
import 'package:dildostu/src/ui/essential_words_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

LiveMessage _msg(String word, String translation) => LiveMessage(
      packId: 'essential',
      word: word,
      translationAz: translation,
      ipa: '/x/',
      example: 'Example.',
      exampleAz: 'Nümunə.',
      aiLine: 'Bu sözü öyrən!',
      level: 1,
      isLive: true,
    );

void main() {
  testWidgets('yüklənərkən göstərici, sonra siyahı + sayğac görünür',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: EssentialWordsScreen(
        loader: (offset) async => (
          words: [_msg('abandon', 'tərk etmək'), _msg('keen', 'həvəskar')],
          total: 168,
          nextOffset: offset + 12,
        ),
        onOpenWord: (_, _) {},
      ),
    ));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();

    expect(find.text('abandon'), findsOneWidget);
    expect(find.text('tərk etmək'), findsOneWidget);
    expect(find.textContaining('/ 168'), findsOneWidget);
  });

  testWidgets('"Növbəti sözlər" düyməsi yeni offset ilə loader-i çağırır',
      (tester) async {
    final offsets = <int>[];
    await tester.pumpWidget(MaterialApp(
      home: EssentialWordsScreen(
        loader: (offset) async {
          offsets.add(offset);
          return (
            words: [_msg('abandon', 'tərk etmək')],
            total: 168,
            nextOffset: offset + 12,
          );
        },
        onOpenWord: (_, _) {},
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Növbəti sözlər'));
    await tester.pumpAndSettle();

    expect(offsets, [0, 12]);
  });

  testWidgets('sözə toxunanda siyahı və indeks ötürülür', (tester) async {
    List<LiveMessage>? passedWords;
    int? passedIndex;
    await tester.pumpWidget(MaterialApp(
      home: EssentialWordsScreen(
        loader: (offset) async => (
          words: [_msg('abandon', 'tərk etmək'), _msg('keen', 'həvəskar')],
          total: 168,
          nextOffset: 12,
        ),
        onOpenWord: (words, index) {
          passedWords = words;
          passedIndex = index;
        },
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('keen'));
    await tester.pumpAndSettle();

    expect(passedIndex, 1);
    expect(passedWords, hasLength(2));
  });

  testWidgets('accent verilibsə AppBar fonu tint-ə dəyişir', (tester) async {
    final accent = accentFor('essential');
    await tester.pumpWidget(MaterialApp(
      home: EssentialWordsScreen(
        loader: (offset) async =>
            (words: [_msg('abandon', 'tərk etmək')], total: 168, nextOffset: 12),
        onOpenWord: (_, _) {},
        accent: accent,
      ),
    ));
    await tester.pumpAndSettle();

    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar.backgroundColor, accent.tint);
  });

  testWidgets('xəta olsa mesaj və yenidən cəhd düyməsi göstərilir',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: EssentialWordsScreen(
        loader: (offset) async => throw StateError('x'),
        onOpenWord: (_, _) {},
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('Yüklənmədi'), findsOneWidget);
    expect(find.text('Yenidən cəhd et'), findsOneWidget);
  });

  testWidgets('yenidən cəhd loader-i eyni offset ilə təkrar çağırır',
      (tester) async {
    var calls = 0;
    await tester.pumpWidget(MaterialApp(
      home: EssentialWordsScreen(
        loader: (offset) async {
          calls++;
          throw StateError('x');
        },
        onOpenWord: (_, _) {},
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Yenidən cəhd et'));
    await tester.pumpAndSettle();

    expect(calls, 2);
  });
}
