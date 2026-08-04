import 'package:dildostu/src/models/live_message.dart';
import 'package:dildostu/src/ui/accent_colors.dart';
import 'package:dildostu/src/ui/word_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

LiveMessage _msg(String word, String translation) => LiveMessage(
      packId: 'airport',
      word: word,
      translationAz: translation,
      ipa: '/x/',
      example: 'Example.',
      exampleAz: 'Nümunə.',
      aiLine: 'Aeroportdasan!',
      level: 1,
      isLive: true,
    );

void main() {
  testWidgets('yüklənərkən göstərici, sonra siyahı görünür', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: WordListScreen(
        title: 'Aeroportda',
        loader: () async => [_msg('gate', 'qapı'), _msg('boarding', 'minik')],
        onOpenWord: (_, _) {},
      ),
    ));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();

    expect(find.text('gate'), findsOneWidget);
    expect(find.text('qapı'), findsOneWidget);
    expect(find.text('boarding'), findsOneWidget);
  });

  testWidgets('sıra nömrələri göstərilir', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: WordListScreen(
        title: 'Aeroportda',
        loader: () async => [_msg('gate', 'qapı'), _msg('boarding', 'minik')],
        onOpenWord: (_, _) {},
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('sözə toxunanda siyahı və indeks ötürülür', (tester) async {
    List<LiveMessage>? passedWords;
    int? passedIndex;
    await tester.pumpWidget(MaterialApp(
      home: WordListScreen(
        title: 'Aeroportda',
        loader: () async => [_msg('gate', 'qapı'), _msg('boarding', 'minik')],
        onOpenWord: (words, index) {
          passedWords = words;
          passedIndex = index;
        },
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('boarding'));
    await tester.pumpAndSettle();

    expect(passedIndex, 1);
    expect(passedWords, hasLength(2));
  });

  testWidgets('accent verilibsə AppBar fonu tint-ə dəyişir', (tester) async {
    final accent = accentFor('airport');
    await tester.pumpWidget(MaterialApp(
      home: WordListScreen(
        title: 'Aeroportda',
        loader: () async => [_msg('gate', 'qapı')],
        onOpenWord: (_, _) {},
        accent: accent,
      ),
    ));
    await tester.pumpAndSettle();

    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar.backgroundColor, accent.tint);
  });

  testWidgets('boş siyahıda mesaj və yenidən cəhd düyməsi', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: WordListScreen(
        title: 'Aeroportda',
        loader: () async => const [],
        onOpenWord: (_, _) {},
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('söz tapılmadı'), findsOneWidget);
    expect(find.text('Yenidən cəhd et'), findsOneWidget);
  });

  testWidgets('yenidən cəhd loader-i təkrar çağırır', (tester) async {
    var calls = 0;
    await tester.pumpWidget(MaterialApp(
      home: WordListScreen(
        title: 'Aeroportda',
        loader: () async {
          calls++;
          return const <LiveMessage>[];
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
