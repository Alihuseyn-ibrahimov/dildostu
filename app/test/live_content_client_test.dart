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
}
