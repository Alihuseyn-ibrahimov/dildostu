import 'dart:convert';

import 'package:dildostu/src/data/live_content_client.dart';
import 'package:dildostu/src/data/pack_repository.dart';
import 'package:dildostu/src/models/user_profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _profile = UserProfile(
  wakeHour: 8,
  sleepHour: 23,
  purpose: LearningPurpose.travel,
  level: ProficiencyLevel.beginner,
  interests: [],
);

const _cafePackJson = '''
{
  "pack_id": "cafe",
  "target_lang": "en",
  "ui_lang": "az",
  "title_az": "Kafedə",
  "words": [
    {"word": "coffee", "translation_az": "qəhvə", "ipa": "/k/",
     "example": "A coffee.", "example_az": "Bir qəhvə.", "level": 1}
  ]
}
''';

PackRepository _repo() => PackRepository.fromJsonStrings([_cafePackJson]);

String _serverMessage() => jsonEncode({
      'pack_id': 'cafe',
      'word': 'latte',
      'translation_az': 'latte',
      'ipa': '/ˈlɑːteɪ/',
      'example': 'Can I have a latte?',
      'example_az': 'Bir latte ola bilər?',
      'ai_line': 'İndi kafedəsən!',
      'level': 1,
    });

void main() {
  group('online (server uğurlu)', () {
    test('serverdən canlı mesaj qaytarır', () async {
      final mock = MockClient(
          (req) async => http.Response.bytes(utf8.encode(_serverMessage()), 200));
      final client = LiveContentClient(
        baseUrl: 'http://x',
        httpClient: mock,
        fallbackRepo: _repo(),
      );
      final msg = await client.generate(packId: 'cafe', hour: 9, profile: _profile);
      expect(msg.word, 'latte');
      expect(msg.aiLine, 'İndi kafedəsən!');
      expect(msg.isLive, isTrue);
    });

    test('sorğu düzgün endpoint və gövdə göndərir', () async {
      String? capturedPath;
      Map<String, dynamic>? capturedBody;
      final mock = MockClient((req) async {
        capturedPath = req.url.path;
        capturedBody = jsonDecode(req.body) as Map<String, dynamic>;
        return http.Response.bytes(utf8.encode(_serverMessage()), 200);
      });
      final client = LiveContentClient(
        baseUrl: 'http://x', httpClient: mock, fallbackRepo: _repo(),
      );
      await client.generate(packId: 'cafe', hour: 9, profile: _profile, mode: 'simpler');
      expect(capturedPath, '/generate');
      expect(capturedBody!['mode'], 'simpler');
      expect(capturedBody!['context']['pack_id'], 'cafe');
      expect(capturedBody!['profile']['level'], 'beginner');
    });
  });

  group('offline / xəta (statik fallback)', () {
    test('server 502 → statik paketdən söz', () async {
      final mock = MockClient((req) async => http.Response('err', 502));
      final client = LiveContentClient(
        baseUrl: 'http://x', httpClient: mock, fallbackRepo: _repo(),
      );
      final msg = await client.generate(packId: 'cafe', hour: 9, profile: _profile);
      expect(msg.word, 'coffee'); // statik paketdən
      expect(msg.isLive, isFalse);
    });

    test('şəbəkə istisnası → statik fallback', () async {
      final mock = MockClient((req) async => throw Exception('network'));
      final client = LiveContentClient(
        baseUrl: 'http://x', httpClient: mock, fallbackRepo: _repo(),
      );
      final msg = await client.generate(packId: 'cafe', hour: 9, profile: _profile);
      expect(msg.word, 'coffee');
      expect(msg.isLive, isFalse);
    });

    test('naməlum paket və server xətası → boş deyil, xəta atmır', () async {
      final mock = MockClient((req) async => http.Response('err', 502));
      final client = LiveContentClient(
        baseUrl: 'http://x', httpClient: mock, fallbackRepo: _repo(),
      );
      // 'unknown' paketi yoxdur; fallback ilk mövcud paketə düşür
      final msg = await client.generate(packId: 'unknown', hour: 9, profile: _profile);
      expect(msg.word, isNotEmpty);
      expect(msg.isLive, isFalse);
    });
  });

  group('packWords (söz siyahısı)', () {
    String wordsResponse() => jsonEncode({
          'words': [
            {
              'pack_id': 'cafe',
              'word': 'latte',
              'translation_az': 'latte',
              'ipa': '/l/',
              'example': 'A latte.',
              'example_az': 'Bir latte.',
              'ai_line': 'Kafedəsən!',
              'level': 1,
            },
            {
              'pack_id': 'cafe',
              'word': 'receipt',
              'translation_az': 'qəbz',
              'ipa': '/r/',
              'example': 'The receipt.',
              'example_az': 'Qəbz.',
              'ai_line': 'Kafedəsən!',
              'level': 1,
            },
          ],
        });

    test('serverdən siyahı qaytarır', () async {
      final mock = MockClient(
          (req) async => http.Response.bytes(utf8.encode(wordsResponse()), 200));
      final client = LiveContentClient(
        baseUrl: 'http://x', httpClient: mock, fallbackRepo: _repo(),
      );
      final words = await client.packWords(packId: 'cafe', profile: _profile);
      expect(words, hasLength(2));
      expect(words.first.word, 'latte');
      expect(words.first.isLive, isTrue);
    });

    test('düzgün endpoint və gövdə göndərir', () async {
      String? path;
      Map<String, dynamic>? body;
      final mock = MockClient((req) async {
        path = req.url.path;
        body = jsonDecode(req.body) as Map<String, dynamic>;
        return http.Response.bytes(utf8.encode(wordsResponse()), 200);
      });
      final client = LiveContentClient(
        baseUrl: 'http://x', httpClient: mock, fallbackRepo: _repo(),
      );
      await client.packWords(packId: 'cafe', profile: _profile, count: 6);
      expect(path, '/pack-words');
      expect(body!['pack_id'], 'cafe');
      expect(body!['count'], 6);
      expect(body!['profile']['level'], 'beginner');
    });

    // Groq gündəlik limiti dolanda server 502 verir — ekran boş qalmamalıdır.
    test('server 502 → statik paketin sözləri', () async {
      final mock = MockClient((req) async => http.Response('err', 502));
      final client = LiveContentClient(
        baseUrl: 'http://x', httpClient: mock, fallbackRepo: _repo(),
      );
      final words = await client.packWords(packId: 'cafe', profile: _profile);
      expect(words, hasLength(1));
      expect(words.first.word, 'coffee');
      expect(words.first.isLive, isFalse);
    });

    test('şəbəkə istisnası → statik fallback', () async {
      final mock = MockClient((req) async => throw Exception('network'));
      final client = LiveContentClient(
        baseUrl: 'http://x', httpClient: mock, fallbackRepo: _repo(),
      );
      final words = await client.packWords(packId: 'cafe', profile: _profile);
      expect(words.first.word, 'coffee');
    });

    test('boş server cavabı → statik fallback', () async {
      final mock = MockClient((req) async =>
          http.Response.bytes(utf8.encode(jsonEncode({'words': []})), 200));
      final client = LiveContentClient(
        baseUrl: 'http://x', httpClient: mock, fallbackRepo: _repo(),
      );
      final words = await client.packWords(packId: 'cafe', profile: _profile);
      expect(words.first.word, 'coffee');
      expect(words.first.isLive, isFalse);
    });

    test('naməlum paket → boş siyahı (xəta atmır)', () async {
      final mock = MockClient((req) async => http.Response('err', 502));
      final client = LiveContentClient(
        baseUrl: 'http://x', httpClient: mock, fallbackRepo: _repo(),
      );
      expect(await client.packWords(packId: 'yoxdur', profile: _profile), isEmpty);
    });
  });

  group('essentialWords (Əsas lüğət)', () {
    String response({int total = 168, int nextOffset = 12}) => jsonEncode({
          'words': [
            {
              'pack_id': 'essential',
              'word': 'abandon',
              'translation_az': 'tərk etmək',
              'ipa': '/ə/',
              'example': 'They abandon it.',
              'example_az': 'Onlar tərk edir.',
              'ai_line': 'Bu sözü öyrən!',
              'level': 1,
            },
          ],
          'total': total,
          'next_offset': nextOffset,
        });

    test('serverdən dəst + səhifələmə məlumatı qaytarır', () async {
      final mock = MockClient(
          (req) async => http.Response.bytes(utf8.encode(response()), 200));
      final client = LiveContentClient(
        baseUrl: 'http://x', httpClient: mock, fallbackRepo: _repo(),
      );
      final result = await client.essentialWords(profile: _profile);
      expect(result.words, hasLength(1));
      expect(result.words.first.word, 'abandon');
      expect(result.total, 168);
      expect(result.nextOffset, 12);
    });

    test('düzgün endpoint və gövdə göndərir', () async {
      String? path;
      Map<String, dynamic>? body;
      final mock = MockClient((req) async {
        path = req.url.path;
        body = jsonDecode(req.body) as Map<String, dynamic>;
        return http.Response.bytes(utf8.encode(response()), 200);
      });
      final client = LiveContentClient(
        baseUrl: 'http://x', httpClient: mock, fallbackRepo: _repo(),
      );
      await client.essentialWords(profile: _profile, offset: 24, count: 12);
      expect(path, '/essential-words');
      expect(body!['offset'], 24);
      expect(body!['count'], 12);
      expect(body!['profile']['level'], 'beginner');
    });

    test('server xətası → StateError atır (statik fallback yoxdur)', () async {
      final mock = MockClient((req) async => http.Response('err', 502));
      final client = LiveContentClient(
        baseUrl: 'http://x', httpClient: mock, fallbackRepo: _repo(),
      );
      expect(
        () => client.essentialWords(profile: _profile),
        throwsA(isA<StateError>()),
      );
    });
  });
}
