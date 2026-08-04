import 'dart:convert';

import 'package:dildostu/src/data/word_lookup_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('WordLookupClient', () {
    test('uğurlu cavabı parse edir', () async {
      final mock = MockClient((req) async => http.Response.bytes(
          utf8.encode(jsonEncode(
              {'word': 'bank', 'translation_az': 'sahil', 'ipa': '/bæŋk/'})),
          200));
      final client = WordLookupClient(baseUrl: 'http://x', httpClient: mock);
      final result = await client.lookup('bank', context: 'river bank');
      expect(result.word, 'bank');
      expect(result.translationAz, 'sahil');
      expect(result.ipa, '/bæŋk/');
    });

    test('düzgün endpoint və gövdə göndərir', () async {
      String? path;
      Map<String, dynamic>? body;
      final mock = MockClient((req) async {
        path = req.url.path;
        body = jsonDecode(req.body) as Map<String, dynamic>;
        return http.Response.bytes(
            utf8.encode(jsonEncode(
                {'word': 'bank', 'translation_az': 'sahil', 'ipa': '/x/'})),
            200);
      });
      final client = WordLookupClient(baseUrl: 'http://x', httpClient: mock);
      await client.lookup('bank', context: 'river bank');
      expect(path, '/word-lookup');
      expect(body!['word'], 'bank');
      expect(body!['context'], 'river bank');
    });

    test('context ötürülməzsə boş sətir göndərir', () async {
      Map<String, dynamic>? body;
      final mock = MockClient((req) async {
        body = jsonDecode(req.body) as Map<String, dynamic>;
        return http.Response.bytes(
            utf8.encode(jsonEncode(
                {'word': 'bank', 'translation_az': 'sahil', 'ipa': '/x/'})),
            200);
      });
      final client = WordLookupClient(baseUrl: 'http://x', httpClient: mock);
      await client.lookup('bank');
      expect(body!['context'], '');
    });

    test('server xətasında istisna atır (səssiz uğursuzluq yox)', () {
      final mock = MockClient((req) async => http.Response('err', 502));
      final client = WordLookupClient(baseUrl: 'http://x', httpClient: mock);
      expect(() => client.lookup('bank'), throwsA(isA<StateError>()));
    });

    test('şəbəkə istisnası çağıran tərəfə ötürülür', () {
      final mock = MockClient((req) async => throw Exception('network'));
      final client = WordLookupClient(baseUrl: 'http://x', httpClient: mock);
      expect(() => client.lookup('bank'), throwsException);
    });
  });
}
