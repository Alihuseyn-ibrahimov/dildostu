import 'package:dildostu/src/data/word_lookup_client.dart';
import 'package:dildostu/src/models/song.dart';
import 'package:dildostu/src/ui/accent_colors.dart';
import 'package:dildostu/src/ui/music_screen.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// `buildTappableWordSpans` sözləri ayrıca `TextSpan`-lara böldüyü üçün
/// `find.text('Twinkle')` onları tapmır — recognizer-i birbaşa çağırırıq
/// (bax `audiobook_screens_test.dart`-dakı eyni texnika, `_tapWordSpan`).
void _tapWordSpan(WidgetTester tester, String word) {
  final richTexts = tester.widgetList<RichText>(find.byType(RichText));
  for (final richText in richTexts) {
    var found = false;
    void walk(InlineSpan span) {
      if (span is TextSpan) {
        if (span.text == word && span.recognizer is TapGestureRecognizer) {
          (span.recognizer as TapGestureRecognizer).onTap!();
          found = true;
          return;
        }
        span.children?.forEach(walk);
      }
    }
    walk(richText.text);
    if (found) return;
  }
}

Song _song() => const Song(
      songId: 'jane-taylor-twinkle-twinkle-little-star',
      title: 'Twinkle Twinkle Little Star',
      artist: 'Jane Taylor',
      youtubeId: 'yCjJyiqpAuU',
      level: 'beginner',
      lines: [
        SongLine(
          lineId: 'l1',
          text: 'Twinkle, twinkle, little star',
          translationAz: 'Bərq vur, bərq vur, kiçik ulduz',
        ),
        SongLine(
          lineId: 'l2',
          text: 'How I wonder what you are',
          translationAz: 'Mərak edirəm sən nəsən',
        ),
      ],
    );

void main() {
  group('MusicScreen', () {
    testWidgets('yüklənərkən göstərici, sonra mahnı siyahısı', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: MusicScreen(
          loader: () async => [_song()],
          onOpenSong: (_) {},
        ),
      ));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('Twinkle Twinkle Little Star'), findsOneWidget);
      expect(find.textContaining('Jane Taylor'), findsOneWidget);
    });

    testWidgets('səviyyə nişanı göstərilir', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: MusicScreen(loader: () async => [_song()], onOpenSong: (_) {}),
      ));
      await tester.pumpAndSettle();
      expect(find.textContaining('Asan'), findsOneWidget);
    });

    testWidgets('xəta olsa səbəb + yenidən cəhd düyməsi', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: MusicScreen(
          loader: () async => throw StateError('x'),
          onOpenSong: (_) {},
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.textContaining('yüklənmədi'), findsOneWidget);
      expect(find.text('Yenidən cəhd et'), findsOneWidget);
    });

    testWidgets('boş kataloqda mesaj göstərilir', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: MusicScreen(loader: () async => [], onOpenSong: (_) {}),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Hələ mahnı yoxdur.'), findsOneWidget);
    });

    testWidgets('accent verilibsə AppBar və kart rəngi dəyişir', (tester) async {
      final accent = accentFor('music');
      await tester.pumpWidget(MaterialApp(
        home: MusicScreen(
          loader: () async => [_song()],
          onOpenSong: (_) {},
          accent: accent,
        ),
      ));
      await tester.pumpAndSettle();

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.backgroundColor, accent.tint);

      final iconContainer = tester.widget<Container>(
        find
            .ancestor(
                of: find.byIcon(Icons.music_note),
                matching: find.byType(Container))
            .first,
      );
      final decoration = iconContainer.decoration as BoxDecoration;
      expect(decoration.color, accent.tint);
    });

    testWidgets('mahnıya toxunanda callback çağırılır', (tester) async {
      Song? opened;
      await tester.pumpWidget(MaterialApp(
        home: MusicScreen(
          loader: () async => [_song()],
          onOpenSong: (s) => opened = s,
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Twinkle Twinkle Little Star'));
      expect(opened?.songId, 'jane-taylor-twinkle-twinkle-little-star');
    });
  });

  // `SongPlayerScreen`-in özü `YoutubePlayerController` yaradır (webview
  // platform mock tələb edir, bax music_screen.dart-dakı qeyd) — ona görə
  // faktiki yeni məntiq (lyrics + sözə toxunma) ayrılmış `SongLyricsView`-
  // da test olunur, videosuz.
  group('SongLyricsView', () {
    Widget wrap({
      required Future<WordLookupResult> Function(String, String) lookupWord,
    }) =>
        MaterialApp(
          home: Scaffold(
            body: SongLyricsView(lines: _song().lines, lookupWord: lookupWord),
          ),
        );

    testWidgets('hər sətrin mətni və tərcüməsi göstərilir', (tester) async {
      await tester.pumpWidget(wrap(
        lookupWord: (w, c) async => WordLookupResult(word: w, translationAz: 'x', ipa: '/x/'),
      ));
      final richTexts = tester.widgetList<RichText>(find.byType(RichText));
      final plain = richTexts.map((r) => r.text.toPlainText()).join(' ');
      expect(plain, contains('Twinkle, twinkle, little star'));
      expect(find.text('Bərq vur, bərq vur, kiçik ulduz'), findsOneWidget);
      expect(find.text('Mərak edirəm sən nəsən'), findsOneWidget);
    });

    testWidgets('sözə toxunanda mənası aşağı vərəqdə göstərilir', (tester) async {
      await tester.pumpWidget(wrap(
        lookupWord: (w, c) async =>
            WordLookupResult(word: w, translationAz: 'ulduz', ipa: '/stɑːr/'),
      ));

      _tapWordSpan(tester, 'star');
      await tester.pumpAndSettle();

      expect(find.text('ulduz'), findsOneWidget);
      expect(find.text('/stɑːr/'), findsOneWidget);
    });

    testWidgets('sözə toxunanda kontekst (sətir) ötürülür', (tester) async {
      String? capturedWord;
      String? capturedLine;
      await tester.pumpWidget(wrap(lookupWord: (word, line) async {
        capturedWord = word;
        capturedLine = line;
        return WordLookupResult(word: word, translationAz: 'x', ipa: '/x/');
      }));

      _tapWordSpan(tester, 'star');
      await tester.pumpAndSettle();

      expect(capturedWord, 'star');
      expect(capturedLine, 'Twinkle, twinkle, little star');
    });

    testWidgets('axtarış uğursuz olsa xəta + yenidən cəhd göstərilir', (tester) async {
      await tester.pumpWidget(wrap(lookupWord: (w, c) async => throw StateError('502')));

      _tapWordSpan(tester, 'star');
      await tester.pumpAndSettle();

      expect(find.textContaining('Tapılmadı'), findsOneWidget);
      expect(find.text('Yenidən cəhd et'), findsOneWidget);
    });
  });
}
