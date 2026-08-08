import 'dart:convert';

import 'package:dildostu/src/data/place_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('PlaceClient.resolve', () {
    test('paket qaytarır', () async {
      final mock = MockClient((req) async {
        expect(req.url.path, '/place/resolve');
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        expect(body['lat'], 40.37);
        expect(body['lng'], 49.83);
        return http.Response(
          jsonEncode({
            'pack_id': 'market',
            'name': '28 Mall',
            'category': 'Shopping Mall',
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final client = PlaceClient(baseUrl: 'https://x', token: 'tok1', httpClient: mock);
      final result = await client.resolve(40.37, 49.83);
      expect(result, isNotNull);
      expect(result!.packId, 'market');
      expect(result.name, '28 Mall');
    });

    test('404 → null', () async {
      final mock = MockClient((req) async => http.Response('{}', 404));
      final client = PlaceClient(baseUrl: 'https://x', token: 'tok1', httpClient: mock);
      expect(await client.resolve(0, 0), isNull);
    });

    test('tamamilə boş cavab → null', () async {
      final mock = MockClient(
          (req) async => http.Response(jsonEncode({'pack_id': ''}), 200));
      final client = PlaceClient(baseUrl: 'https://x', token: 'tok1', httpClient: mock);
      expect(await client.resolve(0, 0), isNull);
    });

    test('şəbəkə xətası → null (səssiz)', () async {
      final mock = MockClient((req) async => throw Exception('offline'));
      final client = PlaceClient(baseUrl: 'https://x', token: 'tok1', httpClient: mock);
      expect(await client.resolve(0, 0), isNull);
    });

    test('Authorization başlığı göndərir', () async {
      final mock = MockClient((req) async {
        expect(req.headers['Authorization'], 'Bearer tok1');
        return http.Response(jsonEncode({'pack_id': ''}), 200);
      });
      final client = PlaceClient(baseUrl: 'https://x', token: 'tok1', httpClient: mock);
      await client.resolve(0, 0);
    });

    test('401 → onUnauthorized çağırılır', () async {
      var called = false;
      final mock = MockClient((req) async => http.Response('{}', 401));
      final client = PlaceClient(
        baseUrl: 'https://x',
        token: 'köhnə',
        httpClient: mock,
        onUnauthorized: () => called = true,
      );
      await client.resolve(0, 0);
      expect(called, isTrue);
    });
  });

  group('paketsiz yer və məsafə (2026-08-07)', () {
    PlaceClient clientFor(Map<String, dynamic> body) => PlaceClient(
          baseUrl: 'https://x',
          token: 'tok1',
          httpClient: MockClient((req) => Future.value(http.Response(
                jsonEncode(body),
                200,
                headers: {'content-type': 'application/json; charset=utf-8'},
              ))),
        );

    test('məsafə parse edilir', () async {
      final result = await clientFor({
        'pack_id': 'cafe',
        'name': 'Kofe Evi',
        'category': 'Café',
        'distance_m': 27,
      }).resolve(0, 0);
      expect(result!.distanceM, 27);
      expect(result.hasPack, isTrue);
    });

    test('pack_id null olsa da yer qaytarılır (əvvəllər itirdi)', () async {
      final result = await clientFor({
        'pack_id': null,
        'name': 'Dənizkənarı Park',
        'category': 'Park',
        'distance_m': 15,
      }).resolve(0, 0);

      expect(result, isNotNull);
      expect(result!.hasPack, isFalse);
      expect(result.label, 'Dənizkənarı Park');
      expect(result.distanceM, 15);
    });

    test('ad yoxdursa label kateqoriyaya düşür', () async {
      final result = await clientFor({
        'pack_id': 'cafe',
        'name': '',
        'category': 'Coffee Shop',
      }).resolve(0, 0);
      expect(result!.label, 'Coffee Shop');
    });

    test('distance_m yoxdursa null (sınmır)', () async {
      final result =
          await clientFor({'pack_id': 'cafe', 'name': 'Kafe'}).resolve(0, 0);
      expect(result!.distanceM, isNull);
    });
  });
}
