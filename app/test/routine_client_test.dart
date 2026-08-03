import 'dart:convert';

import 'package:dildostu/src/data/routine_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('postSample gövdəni və Authorization başlığını düzgün göndərir', () async {
    Map<String, dynamic>? body;
    String? path;
    String? auth;
    final mock = MockClient((req) async {
      body = jsonDecode(req.body) as Map<String, dynamic>;
      path = req.url.path;
      auth = req.headers['Authorization'];
      return http.Response('{"ok": true}', 200);
    });
    final client = RoutineClient(baseUrl: 'http://x', token: 'tok1', httpClient: mock);
    await client.postSample(
      deviceId: 'dev1', lat: 40.37, lng: 49.83, placeType: 'cafe', packId: 'cafe',
    );
    expect(path, '/routine/sample');
    expect(auth, 'Bearer tok1');
    expect(body!['device_id'], 'dev1');
    expect(body!['place_type'], 'cafe');
    expect(body!['lat'], 40.37);
  });

  test('postSample xətası səssiz udulur (fon işi)', () async {
    final mock = MockClient((req) async => http.Response('err', 500));
    final client = RoutineClient(baseUrl: 'http://x', token: 'tok1', httpClient: mock);
    // Atmamalı — rutin toplama istifadəçini bloklamamalı.
    await client.postSample(
      deviceId: 'dev1', lat: 1, lng: 1, placeType: 'cafe',
    );
  });

  test('postSample 401 → onUnauthorized çağırılır', () async {
    var called = false;
    final mock = MockClient((req) async => http.Response('{}', 401));
    final client = RoutineClient(
      baseUrl: 'http://x',
      token: 'köhnə',
      httpClient: mock,
      onUnauthorized: () => called = true,
    );
    await client.postSample(deviceId: 'd', lat: 1, lng: 1, placeType: 'cafe');
    expect(called, isTrue);
  });

  test('fetchSummary məkanları parse edir', () async {
    final mock = MockClient((req) async {
      expect(req.url.path, '/routine/summary');
      return http.Response.bytes(
          utf8.encode(jsonEncode({
            'places': [
              {'place_type': 'cafe', 'count': 3, 'last_seen': '2026-07-23T09:00:00+00:00', 'pack_id': 'cafe'},
              {'place_type': 'market', 'count': 1, 'last_seen': '2026-07-22T18:00:00+00:00', 'pack_id': 'market'},
            ],
          })),
          200);
    });
    final client = RoutineClient(baseUrl: 'http://x', token: 'tok1', httpClient: mock);
    final places = await client.fetchSummary();
    expect(places.length, 2);
    expect(places.first.placeType, 'cafe');
    expect(places.first.count, 3);
  });

  test('fetchSummary xətada boş siyahı qaytarır', () async {
    final mock = MockClient((req) async => http.Response('err', 500));
    final client = RoutineClient(baseUrl: 'http://x', token: 'tok1', httpClient: mock);
    expect(await client.fetchSummary(), isEmpty);
  });

  test('fetchSummary 401 → onUnauthorized çağırılır', () async {
    var called = false;
    final mock = MockClient((req) async => http.Response('{}', 401));
    final client = RoutineClient(
      baseUrl: 'http://x',
      token: 'köhnə',
      httpClient: mock,
      onUnauthorized: () => called = true,
    );
    await client.fetchSummary();
    expect(called, isTrue);
  });

  test('fetchGeofences zonaları parse edir', () async {
    final mock = MockClient((req) async {
      expect(req.url.path, '/routine/geofences');
      expect(req.headers['Authorization'], 'Bearer tok1');
      return http.Response(
        jsonEncode({
          'geofences': [
            {
              'center_lat': 40.37,
              'center_lng': 49.83,
              'radius': 120.0,
              'pack_id': 'cafe',
              'label': 'cafe',
              'hour_window': 'morning',
              'count': 5,
            }
          ]
        }),
        200,
      );
    });
    final client = RoutineClient(baseUrl: 'https://x', token: 'tok1', httpClient: mock);
    final zones = await client.fetchGeofences();
    expect(zones, hasLength(1));
    expect(zones.first.packId, 'cafe');
    expect(zones.first.radius, 120.0);
  });

  test('fetchGeofences 404 → boş siyahı', () async {
    final mock = MockClient((req) async => http.Response('{}', 404));
    final client = RoutineClient(baseUrl: 'https://x', token: 'tok1', httpClient: mock);
    expect(await client.fetchGeofences(), isEmpty);
  });

  test('fetchGeofences şəbəkə xətası → boş siyahı (səssiz)', () async {
    final mock = MockClient((req) async => throw Exception('offline'));
    final client = RoutineClient(baseUrl: 'https://x', token: 'tok1', httpClient: mock);
    expect(await client.fetchGeofences(), isEmpty);
  });

  group('claimDevice', () {
    test('düzgün endpoint və gövdə göndərir', () async {
      String? path;
      Map<String, dynamic>? body;
      final mock = MockClient((req) async {
        path = req.url.path;
        body = jsonDecode(req.body) as Map<String, dynamic>;
        return http.Response(jsonEncode({'claimed': 3}), 200);
      });
      final client = RoutineClient(baseUrl: 'https://x', token: 'tok1', httpClient: mock);
      final claimed = await client.claimDevice('devX');
      expect(path, '/routine/claim');
      expect(body!['device_id'], 'devX');
      expect(claimed, 3);
    });

    test('xəta halında 0 qaytarır (səssiz)', () async {
      final mock = MockClient((req) async => http.Response('err', 500));
      final client = RoutineClient(baseUrl: 'https://x', token: 'tok1', httpClient: mock);
      expect(await client.claimDevice('devX'), 0);
    });
  });
}
