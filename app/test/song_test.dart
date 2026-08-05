import 'dart:convert';

import 'package:dildostu/src/data/music_client.dart';
import 'package:dildostu/src/models/song.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String _libraryJson() => jsonEncode({
      'version': 1,
      'songs': [
        {
          'song_id': 'jane-taylor-twinkle-twinkle-little-star',
          'title': 'Twinkle Twinkle Little Star',
          'artist': 'Jane Taylor',
          'youtube_id': 'yCjJyiqpAuU',
          'level': 'beginner',
          'lines': [
            {
              'line_id': 'l1',
              'text': 'Twinkle, twinkle, little star',
              'translation_az': 'Bərq vur, bərq vur, kiçik ulduz',
            },
            {
              'line_id': 'l2',
              'text': 'How I wonder what you are',
              'translation_az': 'Mərak edirəm sən nəsən',
            },
          ],
        }
      ],
    });

void main() {
  group('Song modelləri', () {
    test('manifestdən mahnı və sətirləri oxuyur', () {
      final json = jsonDecode(_libraryJson()) as Map<String, dynamic>;
      final song =
          Song.fromServerJson(json['songs'][0] as Map<String, dynamic>);
      expect(song.songId, 'jane-taylor-twinkle-twinkle-little-star');
      expect(song.title, 'Twinkle Twinkle Little Star');
      expect(song.artist, 'Jane Taylor');
      expect(song.youtubeId, 'yCjJyiqpAuU');
      expect(song.lines, hasLength(2));
    });

    test('sətrin AZ tərcüməsi oxunur', () {
      final json = jsonDecode(_libraryJson()) as Map<String, dynamic>;
      final song =
          Song.fromServerJson(json['songs'][0] as Map<String, dynamic>);
      expect(song.lines.first.translationAz, 'Bərq vur, bərq vur, kiçik ulduz');
    });

    test('lang sahəsi yoxdursa İngilisə düşür', () {
      final json = jsonDecode(_libraryJson()) as Map<String, dynamic>;
      final song =
          Song.fromServerJson(json['songs'][0] as Map<String, dynamic>);
      expect(song.lang, 'en');
    });

    test('lang sahəsi verilibsə oxunur', () {
      final json =
          jsonDecode(_libraryJson())['songs'][0] as Map<String, dynamic>;
      final song = Song.fromServerJson({...json, 'lang': 'es'});
      expect(song.lang, 'es');
    });

    test('level defolt beginner-dir', () {
      final json =
          jsonDecode(_libraryJson())['songs'][0] as Map<String, dynamic>;
      final withoutLevel = {...json}..remove('level');
      final song = Song.fromServerJson(withoutLevel);
      expect(song.level, 'beginner');
    });
  });

  group('MusicClient', () {
    test('kataloqu serverdən alır', () async {
      final mock = MockClient(
          (req) async => http.Response.bytes(utf8.encode(_libraryJson()), 200));
      final client = MusicClient(baseUrl: 'http://x', httpClient: mock);
      final songs = await client.fetchLibrary();
      expect(songs, hasLength(1));
      expect(songs.first.lines, hasLength(2));
    });

    test('düzgün endpoint-ə gedir', () async {
      String? path;
      final mock = MockClient((req) async {
        path = req.url.path;
        return http.Response.bytes(utf8.encode(_libraryJson()), 200);
      });
      await MusicClient(baseUrl: 'http://x', httpClient: mock).fetchLibrary();
      expect(path, '/music');
    });

    test('server xətasında istisna atır (səssiz boş siyahı YOX)', () {
      final mock = MockClient((req) async => http.Response('err', 500));
      final client = MusicClient(baseUrl: 'http://x', httpClient: mock);
      expect(client.fetchLibrary, throwsA(isA<StateError>()));
    });
  });
}
