import 'package:dildostu/src/data/word_lookup_client.dart';
import 'package:dildostu/src/models/audiobook.dart';
import 'package:dildostu/src/services/audio_player_service.dart';
import 'package:dildostu/src/ui/accent_colors.dart';
import 'package:dildostu/src/ui/audiobook_player_screen.dart';
import 'package:dildostu/src/ui/audiobooks_screen.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// `buildTappableWordSpans` sözləri ayrıca `TextSpan`-lara böldüyü üçün
/// `find.text('Fox')` onları tapmır (RichText-in daxili span-ları `Text`
/// widget-i deyil) — recognizer-i birbaşa çağırırıq (real toxunuşu simulyasiya).
void _tapWordSpan(WidgetTester tester, String word) {
  final richTexts = tester.widgetList<RichText>(
    find.descendant(
      of: find.byKey(const Key('chapter-text')),
      matching: find.byType(RichText),
    ),
  );
  for (final richText in richTexts) {
    void walk(InlineSpan span) {
      if (span is TextSpan) {
        if (span.text == word && span.recognizer is TapGestureRecognizer) {
          (span.recognizer as TapGestureRecognizer).onTap!();
          return;
        }
        span.children?.forEach(walk);
      }
    }
    walk(richText.text!);
  }
}

AudiobookChapter _ch(String id, String title, int sec) => AudiobookChapter(
      chapterId: id,
      titleEn: title,
      duration: Duration(seconds: sec),
      sizeBytes: 1000,
      text: '$title mətni burada.',
    );

Audiobook _book() => Audiobook(
      bookId: 'aesop',
      titleEn: "Aesop's Fables",
      titleAz: 'Ezop Təmsilləri',
      author: 'Aesop',
      source: 'Project Gutenberg #11339 — ictimai domen',
      level: 'beginner',
      chapters: [
        _ch('the-fox-and-the-grapes', 'The Fox and the Grapes', 24),
        _ch('the-cat-and-the-mice', 'The Cat and the Mice', 55),
      ],
    );

/// Saxta plyer — native kanal olmadan ekranları test etmək üçün.
class FakePlayer implements AudioPlayer {
  final List<String> played = [];
  int pauses = 0;
  int resumes = 0;
  Duration? seekedTo;
  AudioPlaybackState next = const AudioPlaybackState(
    prepared: true,
    playing: true,
    position: Duration(seconds: 5),
    duration: Duration(seconds: 24),
  );

  @override
  Future<void> play(String source) async => played.add(source);
  @override
  Future<void> pause() async => pauses++;
  @override
  Future<void> resume() async => resumes++;
  @override
  Future<void> seek(Duration p) async => seekedTo = p;
  @override
  Future<void> stop() async {}
  @override
  Future<AudioPlaybackState> state() async => next;
}

void main() {
  group('AudiobooksScreen', () {
    testWidgets('yüklənərkən göstərici, sonra kitab siyahısı', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: AudiobooksScreen(
          loader: () async => [_book()],
          onOpenBook: (_) {},
        ),
      ));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('Ezop Təmsilləri'), findsOneWidget);
      expect(find.textContaining('2 hekayə'), findsOneWidget);
    });

    testWidgets('mənbə (attribution) göstərilir', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: AudiobooksScreen(loader: () async => [_book()], onOpenBook: (_) {}),
      ));
      await tester.pumpAndSettle();
      expect(find.textContaining('Gutenberg'), findsOneWidget);
    });

    testWidgets('xəta olsa səbəb + yenidən cəhd düyməsi', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: AudiobooksScreen(
          loader: () async => throw StateError('x'),
          onOpenBook: (_) {},
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.textContaining('yüklənmədi'), findsOneWidget);
      expect(find.text('Yenidən cəhd et'), findsOneWidget);
    });

    testWidgets('accent verilibsə AppBar və kitab kartı rəngi dəyişir',
        (tester) async {
      final accent = accentFor('audiobooks');
      await tester.pumpWidget(MaterialApp(
        home: AudiobooksScreen(
          loader: () async => [_book()],
          onOpenBook: (_) {},
          accent: accent,
        ),
      ));
      await tester.pumpAndSettle();

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.backgroundColor, accent.tint);

      final iconContainer = tester.widget<Container>(
        find
            .ancestor(
                of: find.byIcon(Icons.headphones),
                matching: find.byType(Container))
            .first,
      );
      final decoration = iconContainer.decoration as BoxDecoration;
      expect(decoration.color, accent.tint);
    });

    testWidgets('kitaba toxunanda callback çağırılır', (tester) async {
      Audiobook? opened;
      await tester.pumpWidget(MaterialApp(
        home: AudiobooksScreen(
          loader: () async => [_book()],
          onOpenBook: (b) => opened = b,
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ezop Təmsilləri'));
      expect(opened?.bookId, 'aesop');
    });
  });

  group('AudiobookChaptersScreen', () {
    testWidgets('fəsilləri uzunluğu ilə göstərir', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: AudiobookChaptersScreen(book: _book(), onOpenChapter: (_) {}),
      ));
      expect(find.text('The Fox and the Grapes'), findsOneWidget);
      expect(find.text('0:24'), findsOneWidget);
      expect(find.text('0:55'), findsOneWidget);
    });

    testWidgets('fəslə toxunanda indeks ötürülür', (tester) async {
      int? idx;
      await tester.pumpWidget(MaterialApp(
        home: AudiobookChaptersScreen(book: _book(), onOpenChapter: (i) => idx = i),
      ));
      await tester.tap(find.text('The Cat and the Mice'));
      expect(idx, 1);
    });
  });

  group('AudiobookPlayerScreen', () {
    Widget wrap(FakePlayer player, {int index = 0, AccentColor? accent}) =>
        MaterialApp(
          home: AudiobookPlayerScreen(
            book: _book(),
            initialIndex: index,
            player: player,
            sourceFor: (b, c) => 'https://x/${b.bookId}/${c.chapterId}.mp3',
            lookupWord: (word, sentence) async => WordLookupResult(
              word: word,
              translationAz: '$word-tərcümə',
              ipa: '/x/',
            ),
            accent: accent,
          ),
        );

    testWidgets('açılanda düzgün mənbəni çalır', (tester) async {
      final p = FakePlayer();
      await tester.pumpWidget(wrap(p));
      await tester.pump();
      expect(p.played.single,
          'https://x/aesop/the-fox-and-the-grapes.mp3');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('mətn və başlıq göstərilir', (tester) async {
      final p = FakePlayer();
      await tester.pumpWidget(wrap(p));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('The Fox and the Grapes'), findsOneWidget);
      expect(find.byKey(const Key('chapter-text')), findsOneWidget);
      expect(find.byType(RichText), findsWidgets);
      expect(find.text('1 / 2'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('çalarkən pauza düyməsi görünür və pause çağırır',
        (tester) async {
      final p = FakePlayer();
      await tester.pumpWidget(wrap(p));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byIcon(Icons.pause), findsOneWidget);
      await tester.tap(find.byIcon(Icons.pause));
      await tester.pump();
      expect(p.pauses, 1);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('10 saniyə irəli seek çağırır', (tester) async {
      final p = FakePlayer();
      await tester.pumpWidget(wrap(p));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.byIcon(Icons.forward_10));
      await tester.pump();
      expect(p.seekedTo, const Duration(seconds: 15)); // 5 + 10
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('geri seek 0-dan aşağı düşmür', (tester) async {
      final p = FakePlayer()
        ..next = const AudioPlaybackState(
          prepared: true, playing: true,
          position: Duration(seconds: 3), duration: Duration(seconds: 24),
        );
      await tester.pumpWidget(wrap(p));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.byIcon(Icons.replay_10));
      await tester.pump();
      expect(p.seekedTo, Duration.zero);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('native xəta ekranda göstərilir', (tester) async {
      final p = FakePlayer()
        ..next = const AudioPlaybackState(
            prepared: true, error: 'MediaPlayer xətası (1/-4)');
      await tester.pumpWidget(wrap(p));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.textContaining('Səs xətası'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('ilk fəsildə Əvvəlki sönük, sonuncuda Növbəti sönük',
        (tester) async {
      final p = FakePlayer();
      await tester.pumpWidget(wrap(p));
      await tester.pump(const Duration(milliseconds: 500));
      final prev = tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.skip_previous));
      expect(prev.onPressed, isNull);
      final next = tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.skip_next));
      expect(next.onPressed, isNotNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('fəsil bitəndə növbətiyə keçir', (tester) async {
      final p = FakePlayer()
        ..next = const AudioPlaybackState(
          prepared: true, completed: true,
          position: Duration(seconds: 24), duration: Duration(seconds: 24),
        );
      await tester.pumpWidget(wrap(p));
      await tester.pump(const Duration(milliseconds: 500));
      expect(p.played.length, greaterThanOrEqualTo(2));
      expect(p.played.last, contains('the-cat-and-the-mice'));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('sözə toxunanda mənası aşağı vərəqdə göstərilir',
        (tester) async {
      final p = FakePlayer();
      await tester.pumpWidget(MaterialApp(
        home: AudiobookPlayerScreen(
          book: _book(),
          initialIndex: 0,
          player: p,
          sourceFor: (b, c) => 'https://x/${b.bookId}/${c.chapterId}.mp3',
          lookupWord: (word, sentence) async => WordLookupResult(
            word: word,
            translationAz: 'tülkü',
            ipa: '/fɒks/',
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 500));

      _tapWordSpan(tester, 'Fox');
      await tester.pumpAndSettle();

      expect(find.text('tülkü'), findsOneWidget);
      expect(find.text('/fɒks/'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('sözə toxunanda kontekst (cümlə) ötürülür', (tester) async {
      final p = FakePlayer();
      String? capturedWord;
      String? capturedSentence;
      await tester.pumpWidget(MaterialApp(
        home: AudiobookPlayerScreen(
          book: _book(),
          initialIndex: 0,
          player: p,
          sourceFor: (b, c) => 'https://x/${b.bookId}/${c.chapterId}.mp3',
          lookupWord: (word, sentence) async {
            capturedWord = word;
            capturedSentence = sentence;
            return WordLookupResult(word: word, translationAz: 'x', ipa: '/x/');
          },
        ),
      ));
      await tester.pump(const Duration(milliseconds: 500));

      _tapWordSpan(tester, 'Fox');
      await tester.pumpAndSettle();

      expect(capturedWord, 'Fox');
      expect(capturedSentence, contains('Fox'));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('accent verilibsə AppBar və çal düyməsi rəngi dəyişir',
        (tester) async {
      final p = FakePlayer();
      final accent = accentFor('audiobooks');
      await tester.pumpWidget(wrap(p, accent: accent));
      await tester.pump(const Duration(milliseconds: 500));

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.backgroundColor, accent.tint);

      final playButton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.pause),
      );
      expect(playButton.style?.backgroundColor?.resolve(<WidgetState>{}),
          accent.accent);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('axtarış uğursuz olsa xəta + yenidən cəhd göstərilir',
        (tester) async {
      final p = FakePlayer();
      await tester.pumpWidget(MaterialApp(
        home: AudiobookPlayerScreen(
          book: _book(),
          initialIndex: 0,
          player: p,
          sourceFor: (b, c) => 'https://x/${b.bookId}/${c.chapterId}.mp3',
          lookupWord: (word, sentence) async => throw StateError('502'),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 500));

      _tapWordSpan(tester, 'Fox');
      await tester.pumpAndSettle();

      expect(find.textContaining('Tapılmadı'), findsOneWidget);
      expect(find.text('Yenidən cəhd et'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
