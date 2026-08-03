import 'dart:convert';

import 'package:dildostu/src/data/auth_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String _authResponse({String email = 'ali@example.com', int id = 1}) =>
    jsonEncode({
      'token': 'tok123',
      'user': {'id': id, 'email': email, 'created_at': '2026-08-03T00:00:00Z'},
    });

void main() {
  group('register', () {
    test('uğurlu qeydiyyat token və email qaytarır', () async {
      final mock = MockClient((req) async {
        expect(req.url.path, '/auth/register');
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        expect(body['email'], 'ali@example.com');
        expect(body['password'], 'Parol1234');
        return http.Response(_authResponse(), 201);
      });
      final client = AuthClient(baseUrl: 'https://x', httpClient: mock);
      final result = await client.register('ali@example.com', 'Parol1234');
      expect(result.token, 'tok123');
      expect(result.email, 'ali@example.com');
    });

    test('409 → aydın xəta mesajı', () async {
      final mock = MockClient((req) async => http.Response('{}', 409));
      final client = AuthClient(baseUrl: 'https://x', httpClient: mock);
      await expectLater(
        client.register('ali@example.com', 'Parol1234'),
        throwsA(isA<AuthException>().having(
            (e) => e.message, 'message', contains('artıq qeydiyyatdadır'))),
      );
    });

    test('422 → validasiya mesajı', () async {
      final mock = MockClient((req) async => http.Response('{}', 422));
      final client = AuthClient(baseUrl: 'https://x', httpClient: mock);
      expect(client.register('pis-email', '123'), throwsA(isA<AuthException>()));
    });

    test('şəbəkə xətası → AuthException (crash yox)', () async {
      final mock = MockClient((req) async => throw Exception('offline'));
      final client = AuthClient(baseUrl: 'https://x', httpClient: mock);
      expect(client.register('a@b.com', 'Parol1234'), throwsA(isA<AuthException>()));
    });
  });

  group('login', () {
    test('uğurlu giriş token qaytarır', () async {
      final mock = MockClient((req) async {
        expect(req.url.path, '/auth/login');
        return http.Response(_authResponse(), 200);
      });
      final client = AuthClient(baseUrl: 'https://x', httpClient: mock);
      final result = await client.login('ali@example.com', 'Parol1234');
      expect(result.token, 'tok123');
    });

    test('401 → aydın xəta mesajı', () async {
      final mock = MockClient((req) async => http.Response('{}', 401));
      final client = AuthClient(baseUrl: 'https://x', httpClient: mock);
      await expectLater(
        client.login('ali@example.com', 'Sehv'),
        throwsA(isA<AuthException>().having(
            (e) => e.message, 'message', contains('səhvdir'))),
      );
    });
  });

  group('deleteAccount', () {
    test('204 → sakitcə tamamlanır', () async {
      final mock = MockClient((req) async {
        expect(req.headers['Authorization'], 'Bearer tok123');
        expect(req.method, 'DELETE');
        return http.Response('', 204);
      });
      final client = AuthClient(baseUrl: 'https://x', httpClient: mock);
      await client.deleteAccount('tok123');
    });

    test('401 → AuthException', () async {
      final mock = MockClient((req) async => http.Response('{}', 401));
      final client = AuthClient(baseUrl: 'https://x', httpClient: mock);
      expect(client.deleteAccount('köhnə-token'), throwsA(isA<AuthException>()));
    });
  });
}
