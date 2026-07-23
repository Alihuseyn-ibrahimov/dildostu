import 'dart:convert';

import 'package:dildostu/src/data/routine_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('postSample gövdəni düzgün göndərir', () async {
    Map<String, dynamic>? body;
    String? path;
    final mock = MockClient((req) async {
      body = jsonDecode(req.body) as Map<String, dynamic>;
      path = req.url.path;
      return http.Response('{"ok": true}', 200);
    });
    final client = RoutineClient(baseUrl: 'http://x', httpClient: mock);
    await client.postSample(
      deviceId: 'dev1', lat: 40.37, lng: 49.83, placeType: 'cafe', packId: 'cafe',
    );
    expect(path, '/routine/sample');
    expect(body!['device_id'], 'dev1');
    expect(body!['place_type'], 'cafe');
    expect(body!['lat'], 40.37);
  });

  test('postSample xətası səssiz udulur (fon işi)', () async {
    final mock = MockClient((req) async => http.Response('err', 500));
    final client = RoutineClient(baseUrl: 'http://x', httpClient: mock);
    // Atmamalı — rutin toplama istifadəçini bloklamamalı.
    await client.postSample(
      deviceId: 'dev1', lat: 1, lng: 1, placeType: 'cafe',
    );
  });

  test('fetchSummary məkanları parse edir', () async {
    final mock = MockClient((req) async => http.Response.bytes(
        utf8.encode(jsonEncode({
          'places': [
            {'place_type': 'cafe', 'count': 3, 'last_seen': '2026-07-23T09:00:00+00:00', 'pack_id': 'cafe'},
            {'place_type': 'market', 'count': 1, 'last_seen': '2026-07-22T18:00:00+00:00', 'pack_id': 'market'},
          ],
        })),
        200));
    final client = RoutineClient(baseUrl: 'http://x', httpClient: mock);
    final places = await client.fetchSummary('dev1');
    expect(places.length, 2);
    expect(places.first.placeType, 'cafe');
    expect(places.first.count, 3);
  });

  test('fetchSummary xətada boş siyahı qaytarır', () async {
    final mock = MockClient((req) async => http.Response('err', 500));
    final client = RoutineClient(baseUrl: 'http://x', httpClient: mock);
    expect(await client.fetchSummary('dev1'), isEmpty);
  });
}
