import 'package:dildostu/src/models/live_message.dart';
import 'package:dildostu/src/services/speaker.dart';
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
}) =>
    MaterialApp(
      home: WordDetailScreen(
        title: 'Kafedə',
        words: words,
        initialIndex: initialIndex,
        speaker: speaker ?? FakeSpeaker(),
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

  testWidgets('köhnə rejim düymələri artıq yoxdur', (tester) async {
    await tester.pumpWidget(_screen([_msg('coffee')]));
    await tester.pumpAndSettle();

    expect(find.text('Sadələşdir'), findsNothing);
    expect(find.text('Çətinləşdir'), findsNothing);
    expect(find.text('Başqa nümunə'), findsNothing);
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

  testWidgets('boş siyahı sınmır', (tester) async {
    await tester.pumpWidget(_screen(const []));
    await tester.pumpAndSettle();

    expect(find.text('Söz yoxdur.'), findsOneWidget);
  });
}
