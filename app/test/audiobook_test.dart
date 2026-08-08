import 'dart:convert';

import 'package:dildostu/src/data/audiobook_client.dart';
import 'package:dildostu/src/models/audiobook.dart';
import 'package:dildostu/src/services/audio_player_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String _libraryJson() => jsonEncode({
      'version': 1,
      'books': [
        {
          'book_id': 'aesop',
          'title_en': "Aesop's Fables",
          'title_az': 'Ezop Təmsilləri',
          'author': 'Aesop',
          'source': 'Project Gutenberg #11339 — ictimai domen',
          'level': 'beginner',
          'chapters': [
            {
              'chapter_id': 'the-fox-and-the-grapes',
              'title_en': 'The Fox and the Grapes',
              'duration_sec': 24.0,
              'size_bytes': 192932,
              'text': 'A hungry Fox saw grapes.',
            },
            {
              'chapter_id': 'the-cat-and-the-mice',
              'title_en': 'The Cat and the Mice',
              'duration_sec': 55.3,
              'size_bytes': 443289,
              'text': 'There was once a house overrun with Mice.',
            },
          ],
        }
      ],
    });

void main() {
  group('Audiobook modelləri', () {
    test('manifestdən kitab və fəsilləri oxuyur', () {
      final json =
          jsonDecode(_libraryJson()) as Map<String, dynamic>;
      final book =
          Audiobook.fromServerJson(json['books'][0] as Map<String, dynamic>);
      expect(book.bookId, 'aesop');
      expect(book.titleAz, 'Ezop Təmsilləri');
      expect(book.chapters, hasLength(2));
      expect(book.chapters.first.titleEn, 'The Fox and the Grapes');
    });

    test('saniyəni Duration-a çevirir', () {
      final json = jsonDecode(_libraryJson()) as Map<String, dynamic>;
      final book =
          Audiobook.fromServerJson(json['books'][0] as Map<String, dynamic>);
      expect(book.chapters[1].duration, const Duration(milliseconds: 55300));
    });

    test('oxunaqlı uzunluq etiketi', () {
      const ch = AudiobookChapter(
        chapterId: 'x', titleEn: 'X', sizeBytes: 1,
        duration: Duration(seconds: 187), text: '',
      );
      expect(ch.durationLabel, '3:07');
    });

    test('ümumi uzunluq fəsillərin cəmidir', () {
      final json = jsonDecode(_libraryJson()) as Map<String, dynamic>;
      final book =
          Audiobook.fromServerJson(json['books'][0] as Map<String, dynamic>);
      expect(book.totalDuration, const Duration(milliseconds: 79300));
    });

    test('mətn sinxron göstərmək üçün saxlanılır', () {
      final json = jsonDecode(_libraryJson()) as Map<String, dynamic>;
      final book =
          Audiobook.fromServerJson(json['books'][0] as Map<String, dynamic>);
      expect(book.chapters.first.text, 'A hungry Fox saw grapes.');
    });

    test('mənbə (ictimai domen) saxlanılır', () {
      final json = jsonDecode(_libraryJson()) as Map<String, dynamic>;
      final book =
          Audiobook.fromServerJson(json['books'][0] as Map<String, dynamic>);
      expect(book.source, contains('Gutenberg'));
    });

    test('lang sahəsi yoxdursa (köhnə manifest) İngilisə düşür', () {
      final json = jsonDecode(_libraryJson()) as Map<String, dynamic>;
      final book =
          Audiobook.fromServerJson(json['books'][0] as Map<String, dynamic>);
      expect(book.lang, 'en');
    });

    test('lang sahəsi verilibsə oxunur', () {
      final json = jsonDecode(_libraryJson())['books'][0]
          as Map<String, dynamic>;
      final book = Audiobook.fromServerJson({...json, 'lang': 'ru'});
      expect(book.lang, 'ru');
    });
  });

  group('AudiobookClient', () {
    test('kitabxananı serverdən alır', () async {
      final mock = MockClient(
          (req) async => http.Response.bytes(utf8.encode(_libraryJson()), 200));
      final client = AudiobookClient(baseUrl: 'http://x', httpClient: mock);
      final books = await client.fetchLibrary();
      expect(books, hasLength(1));
      expect(books.first.chapters, hasLength(2));
    });

    test('düzgün endpoint-ə gedir', () async {
      String? path;
      final mock = MockClient((req) async {
        path = req.url.path;
        return http.Response.bytes(utf8.encode(_libraryJson()), 200);
      });
      await AudiobookClient(baseUrl: 'http://x', httpClient: mock)
          .fetchLibrary();
      expect(path, '/audiobooks');
    });

    test('server xətasında istisna atır (səssiz boş siyahı YOX)', () {
      final mock = MockClient((req) async => http.Response('err', 500));
      final client = AudiobookClient(baseUrl: 'http://x', httpClient: mock);
      expect(client.fetchLibrary, throwsA(isA<StateError>()));
    });

    test('fəsil URL-i düzgün qurulur', () {
      final client = AudiobookClient(baseUrl: 'https://s.az');
      expect(
        client.chapterUrl('aesop', 'the-fox-and-the-grapes'),
        'https://s.az/audiobooks/aesop/the-fox-and-the-grapes.mp3',
      );
    });

    test('fetchLibraryRaw xam JSON mətnini qaytarır (offline keş üçün)',
        () async {
      final mock = MockClient(
          (req) async => http.Response.bytes(utf8.encode(_libraryJson()), 200));
      final raw = await AudiobookClient(baseUrl: 'http://x', httpClient: mock)
          .fetchLibraryRaw();
      expect(raw, _libraryJson());
    });

    test('parseLibrary keşlənmiş xam mətni eyni şəkildə parse edir', () {
      final books = AudiobookClient.parseLibrary(_libraryJson());
      expect(books, hasLength(1));
      expect(books.first.chapters, hasLength(2));
    });
  });

  group('AudioPlaybackState', () {
    test('native map-dən oxunur', () {
      final s = AudioPlaybackState.fromMap({
        'prepared': true,
        'playing': true,
        'completed': false,
        'positionMs': 5000,
        'durationMs': 20000,
        'error': null,
      });
      expect(s.prepared, isTrue);
      expect(s.playing, isTrue);
      expect(s.position, const Duration(seconds: 5));
      expect(s.progress, 0.25);
    });

    test('uzunluq 0 olanda gedişat 0 (sıfıra bölmə yoxdur)', () {
      const s = AudioPlaybackState(position: Duration(seconds: 5));
      expect(s.progress, 0.0);
    });

    test('gedişat 0-1 aralığında sıxılır', () {
      final s = AudioPlaybackState.fromMap(
          {'positionMs': 99999, 'durationMs': 1000, 'prepared': true});
      expect(s.progress, 1.0);
    });

    test('xəta sahəsi ötürülür (UI göstərməlidir)', () {
      final s = AudioPlaybackState.fromMap({'error': 'MediaPlayer xətası (1/-4)'});
      expect(s.error, contains('MediaPlayer'));
    });

    test('boş map sınmır', () {
      final s = AudioPlaybackState.fromMap({});
      expect(s.prepared, isFalse);
      expect(s.position, Duration.zero);
    });
  });
}
