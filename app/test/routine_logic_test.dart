import 'dart:convert';

import 'package:dildostu/src/data/routine_client.dart';
import 'package:dildostu/src/engine/routine_logic.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('isWithinActiveHours', () {
    test('adi gündüz pəncərəsi (8–23)', () {
      expect(isWithinActiveHours(8, 8, 23), isTrue);
      expect(isWithinActiveHours(22, 8, 23), isTrue);
      expect(isWithinActiveHours(23, 8, 23), isFalse); // yuxarı sərhəd daxil deyil
      expect(isWithinActiveHours(7, 8, 23), isFalse);
      expect(isWithinActiveHours(3, 8, 23), isFalse);
    });

    test('gecəyə keçən pəncərə (22–6)', () {
      expect(isWithinActiveHours(23, 22, 6), isTrue);
      expect(isWithinActiveHours(3, 22, 6), isTrue);
      expect(isWithinActiveHours(12, 22, 6), isFalse);
      expect(isWithinActiveHours(6, 22, 6), isFalse);
    });

    test('wake==sleep → həmişə aktiv', () {
      expect(isWithinActiveHours(0, 9, 9), isTrue);
      expect(isWithinActiveHours(15, 9, 9), isTrue);
    });
  });

  group('takeRoutineSample', () {
    test('məkan varsa serverə göndərir', () async {
      Map<String, dynamic>? body;
      final mock = MockClient((req) async {
        body = jsonDecode(req.body) as Map<String, dynamic>;
        return http.Response('{"ok":true}', 200);
      });
      final client = RoutineClient(baseUrl: 'http://x', httpClient: mock);
      await takeRoutineSample(
        resolve: () async => (lat: 40.37, lng: 49.83, packId: 'cafe'),
        client: client,
        deviceId: 'dev1',
      );
      expect(body!['device_id'], 'dev1');
      expect(body!['place_type'], 'cafe');
      expect(body!['lat'], 40.37);
    });

    test('məkan yoxdursa heç nə göndərmir', () async {
      var called = false;
      final mock = MockClient((req) async {
        called = true;
        return http.Response('{"ok":true}', 200);
      });
      final client = RoutineClient(baseUrl: 'http://x', httpClient: mock);
      await takeRoutineSample(
        resolve: () async => null,
        client: client,
        deviceId: 'dev1',
      );
      expect(called, isFalse);
    });
  });
}
