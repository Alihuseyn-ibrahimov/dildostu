import 'package:dildostu/src/models/live_message.dart';
import 'package:dildostu/src/services/speaker.dart';
import 'package:dildostu/src/ui/accent_colors.dart';
import 'package:dildostu/src/ui/word_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeSpeaker implements Speaker {
  final spoken = <String>[];

  @override
  Future<void> speak(String text) async => spoken.add(text);
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
}

LiveMessage _msg(String word, {bool isLive = true, int level = 1}) =>
    LiveMessage(
      packId: 'cafe',
      word: word,
      translationAz: '$word-tərcümə',
      ipa: '/x/',
      example: '$word example.',
      exampleAz: '$word nümunə.',
      aiLine: 'İndi kafedəsən!',
      level: level,
      isLive: isLive,
    );

Widget _screen(
  List<LiveMessage> words, {
  int initialIndex = 0,
  Speaker? speaker,
  AccentColor? accent,
  AiWordGenerator? onAiWord,
}) =>
    MaterialApp(
      home: WordDetailScreen(
        title: 'Kafedə',
        words: words,
        initialIndex: initialIndex,
        speaker: speaker ?? FakeSpeaker(),
        accent: accent,
        onAiWord: onAiWord,
      ),
    );

void main() {
  testWidgets('AI sətri, söz və nümunə göstərilir', (tester) async {
    await tester.pumpWidget(_screen([_msg('coffee')]));
    await tester.pumpAndSettle();

    expect(find.text('İndi kafedəsən!'), findsOneWidget);
    expect(find.text('coffee'), findsOneWidget);
    expect(find.text('coffee example.'), findsOneWidget);
    expect(find.byIcon(Icons.cloud_off), findsNothing);
  });

  testWidgets('offline mesaj üçün cloud_off işarəsi göstərir', (tester) async {
    await tester.pumpWidget(_screen([_msg('coffee', isLive: false)]));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.cloud_off), findsOneWidget);
  });

  testWidgets('onAiWord verilməyibsə AI düymələri göstərilmir', (tester) async {
    await tester.pumpWidget(_screen([_msg('coffee')]));
    await tester.pumpAndSettle();

    expect(find.text('Başqa söz'), findsNothing);
    expect(find.text('Daha sadə'), findsNothing);
    expect(find.text('Daha çətin'), findsNothing);
  });

  testWidgets('AI düymələri göstərilir və generate çağırır', (tester) async {
    String? capturedMode;
    await tester.pumpWidget(_screen(
      [_msg('coffee')],
      onAiWord: ({
        required String packId,
        required String mode,
        required List<String> recentWords,
      }) async {
        capturedMode = mode;
        expect(packId, 'cafe');
        expect(recentWords, contains('coffee'));
        return _msg('latte');
      },
    ));
    await tester.pumpAndSettle();

    expect(find.text('Başqa söz'), findsOneWidget);
    await tester.tap(find.text('Daha sadə'));
    await tester.pumpAndSettle();

    expect(capturedMode, 'simpler');
    expect(find.text('latte'), findsOneWidget);
    expect(find.text('Yeni söz hazırdır ✨'), findsOneWidget);
  });

  testWidgets('offline fallback snackbar göstərir', (tester) async {
    await tester.pumpWidget(_screen(
      [_msg('coffee')],
      onAiWord: ({
        required String packId,
        required String mode,
        required List<String> recentWords,
      }) async =>
          _msg('tea', isLive: false),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Başqa söz'));
    await tester.pumpAndSettle();

    expect(find.text('Server əlçatmaz — statik söz göstərildi'), findsOneWidget);
  });

  testWidgets('mövqe göstəricisi düzgündür', (tester) async {
    await tester.pumpWidget(
        _screen([_msg('a'), _msg('b'), _msg('c')], initialIndex: 1));
    await tester.pumpAndSettle();

    expect(find.text('2/3'), findsOneWidget);
  });

  testWidgets('Növbəti düyməsi sonrakı sözə keçir', (tester) async {
    await tester.pumpWidget(_screen([_msg('a'), _msg('b')]));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Növbəti'));
    await tester.pumpAndSettle();

    expect(find.text('2/2'), findsOneWidget);
    expect(find.text('b'), findsOneWidget);
  });

  testWidgets('Əvvəlki düyməsi geri qaytarır', (tester) async {
    await tester
        .pumpWidget(_screen([_msg('a'), _msg('b')], initialIndex: 1));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Əvvəlki'));
    await tester.pumpAndSettle();

    expect(find.text('1/2'), findsOneWidget);
  });

  testWidgets('ilk sözdə Əvvəlki, son sözdə Növbəti sönükdür', (tester) async {
    await tester.pumpWidget(_screen([_msg('a'), _msg('b')]));
    await tester.pumpAndSettle();

    final prev = tester.widget<OutlinedButton>(
        find.ancestor(of: find.text('Əvvəlki'), matching: find.byType(OutlinedButton)));
    expect(prev.onPressed, isNull);

    await tester.tap(find.text('Növbəti'));
    await tester.pumpAndSettle();

    final next = tester.widget<FilledButton>(
        find.ancestor(of: find.text('Növbəti'), matching: find.byType(FilledButton)));
    expect(next.onPressed, isNull);
  });

  testWidgets('Səsləndir cari sözü oxuyur', (tester) async {
    final speaker = FakeSpeaker();
    await tester.pumpWidget(
        _screen([_msg('a'), _msg('b')], initialIndex: 1, speaker: speaker));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Səsləndir'));
    await tester.pumpAndSettle();

    expect(speaker.spoken, ['b']);
  });

  testWidgets('səviyyə nişanı göstərilir', (tester) async {
    await tester.pumpWidget(_screen([_msg('a', level: 3)]));
    await tester.pumpAndSettle();

    expect(find.text('Çətin'), findsOneWidget);
  });

  testWidgets('accent verilibsə AppBar fonu və Səsləndir düyməsi dəyişir',
      (tester) async {
    final accent = accentFor('cafe');
    await tester.pumpWidget(_screen([_msg('coffee')], accent: accent));
    await tester.pumpAndSettle();

    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar.backgroundColor, accent.tint);

    final speakButton = tester.widget<FilledButton>(
      find.ancestor(
          of: find.text('Səsləndir'), matching: find.byType(FilledButton)),
    );
    expect(
        speakButton.style?.backgroundColor?.resolve(<WidgetState>{}),
        accent.tint);
  });

  testWidgets('boş siyahı sınmır', (tester) async {
    await tester.pumpWidget(_screen(const []));
    await tester.pumpAndSettle();

    expect(find.text('Söz yoxdur.'), findsOneWidget);
  });
}
