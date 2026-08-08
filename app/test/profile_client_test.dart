import 'dart:convert';

import 'package:dildostu/src/data/profile_client.dart';
import 'package:dildostu/src/models/user_profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _profileJson = {
  'wake_hour': 8, 'sleep_hour': 23, 'purpose': 'travel',
  'level': 'beginner', 'interests': ['yemək'],
};

void main() {
  group('fetch', () {
    test('serverdə profil varsa qaytarır', () async {
      final mock = MockClient((req) async {
        expect(req.url.path, '/profile');
        expect(req.headers['Authorization'], 'Bearer tok123');
        return http.Response.bytes(
            utf8.encode(jsonEncode({'profile': _profileJson})), 200);
      });
      final client = ProfileClient(baseUrl: 'https://x', httpClient: mock);
      final profile = await client.fetch('tok123');
      expect(profile, isNotNull);
      expect(profile!.level, ProficiencyLevel.beginner);
    });

    test('serverdə profil yoxdursa null', () async {
      final mock = MockClient(
          (req) async => http.Response(jsonEncode({'profile': null}), 200));
      final client = ProfileClient(baseUrl: 'https://x', httpClient: mock);
      expect(await client.fetch('tok123'), isNull);
    });

    test('401 → null (çağıran tərəf çıxış edir)', () async {
      final mock = MockClient((req) async => http.Response('{}', 401));
      final client = ProfileClient(baseUrl: 'https://x', httpClient: mock);
      expect(await client.fetch('köhnə'), isNull);
    });

    test('şəbəkə xətası → null (səssiz)', () async {
      final mock = MockClient((req) async => throw Exception('offline'));
      final client = ProfileClient(baseUrl: 'https://x', httpClient: mock);
      expect(await client.fetch('tok123'), isNull);
    });

    test('fetchOutcome şəbəkə xətasında reachedServer false', () async {
      final mock = MockClient((req) async => throw Exception('offline'));
      final client = ProfileClient(baseUrl: 'https://x', httpClient: mock);
      final outcome = await client.fetchOutcome('tok123');
      expect(outcome.reachedServer, isFalse);
    });

    test('fetchOutcome boş profildə reachedServer true', () async {
      final mock = MockClient(
          (req) async => http.Response(jsonEncode({'profile': null}), 200));
      final client = ProfileClient(baseUrl: 'https://x', httpClient: mock);
      final outcome = await client.fetchOutcome('tok123');
      expect(outcome.reachedServer, isTrue);
      expect(outcome.profile, isNull);
    });
  });

  group('save', () {
    test('PUT /profile düzgün gövdə göndərir', () async {
      Map<String, dynamic>? body;
      final mock = MockClient((req) async {
        expect(req.method, 'PUT');
        expect(req.headers['Authorization'], 'Bearer tok123');
        body = jsonDecode(req.body) as Map<String, dynamic>;
        return http.Response.bytes(
            utf8.encode(jsonEncode({'profile': _profileJson})), 200);
      });
      final client = ProfileClient(baseUrl: 'https://x', httpClient: mock);
      final profile = UserProfile.fromJson(_profileJson);
      final ok = await client.save('tok123', profile);
      expect(ok, isTrue);
      expect(body!['profile']['level'], 'beginner');
    });

    test('xəta halında false qaytarır (crash yox)', () async {
      final mock = MockClient((req) async => http.Response('err', 500));
      final client = ProfileClient(baseUrl: 'https://x', httpClient: mock);
      final profile = UserProfile.fromJson(_profileJson);
      expect(await client.save('tok123', profile), isFalse);
    });
  });
}
